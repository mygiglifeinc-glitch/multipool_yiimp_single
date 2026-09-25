#!/usr/bin/env bash

#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use...
#####################################################

clear
source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"
PHP_VERSION="${PHP_VERSION:-${MULTIPOOL_DEFAULT_PHP_VERSION:-8.3}}"

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

# Returns success if apt has an installation candidate for the package.
function apt_has_candidate {
	apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]'
}

if [[ "$UsingDomain" == "yes" ]]; then
	sudo hostnamectl set-hostname "${DomainName}"
	# Make sure the new host name resolves locally (sudo complains otherwise).
	if ! grep -qE "[[:space:]]${DomainName//./\\.}([[:space:]]|$)" /etc/hosts; then
		echo "127.0.1.1 ${DomainName}" | sudo tee -a /etc/hosts > /dev/null
	fi
fi

# Set timezone
echo -e " Setting TimeZone to UTC...$COL_RESET"
hide_output sudo timedatectl set-timezone Etc/UTC
echo -e "$GREEN Done...$COL_RESET"

# Add repository
echo -e " Adding the required repsoitories...$COL_RESET"
if [ ! -x /usr/bin/add-apt-repository ]; then
	echo "Installing add-apt-repository..."
	hide_output sudo apt-get -y update
	apt_install software-properties-common
fi
echo -e "$GREEN Done...$COL_RESET"

# PHP
echo -e " Installing Ondrej PHP PPA...$COL_RESET"
if grep -rqs "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/; then
	echo "Ondrej PHP PPA already installed."
elif curl -fsSI --max-time 30 "https://ppa.launchpadcontent.net/ondrej/php/ubuntu/dists/${UBUNTU_CODENAME}/Release" > /dev/null; then
	hide_output sudo add-apt-repository -y ppa:ondrej/php
else
	echo -e "$YELLOW The Ondrej PHP PPA does not support Ubuntu ${UBUNTU_CODENAME} yet, using the Ubuntu PHP packages.$COL_RESET"
fi
echo -e "$GREEN Done...$COL_RESET"

# Upgrade System Files
echo -e " Updating system packages...$COL_RESET"
hide_output sudo apt-get update
echo -e "$GREEN Done...$COL_RESET"
echo -e " Upgrading system packages...$COL_RESET"
apt_get_quiet upgrade
echo -e "$GREEN Done...$COL_RESET"
echo -e " Running Dist-Upgrade...$COL_RESET"
apt_get_quiet dist-upgrade
echo -e "$GREEN Done...$COL_RESET"
echo -e " Running Autoremove...$COL_RESET"
apt_get_quiet autoremove

echo -e "$GREEN Done...$COL_RESET"
echo -e " Installing Base system packages...$COL_RESET"
apt_install python3 python3-dev python3-pip \
	wget curl git sudo coreutils bc unzip acl \
	unattended-upgrades cron fail2ban screen rsyslog

# Time synchronisation: keep whatever NTP client the release ships with
# (systemd-timesyncd, or chrony on newer releases).
if ! systemctl is-active --quiet chrony && ! systemctl is-active --quiet systemd-timesyncd; then
	apt_install systemd-timesyncd
fi
sudo timedatectl set-ntp true || true
echo -e "$GREEN Done...$COL_RESET"

echo -e " Initializing UFW Firewall...$COL_RESET"
if [ -z "${DISABLE_FIREWALL:-}" ]; then
	# Install `ufw` which provides a simple firewall configuration.
	apt_install ufw

	sudo ufw default deny incoming > /dev/null
	sudo ufw default allow outgoing > /dev/null

	# Allow incoming connections to SSH. ssh might be running on an alternate
	# port. Use sshd -T to dump sshd's settings and find the port(s) it is
	# supposedly running on.
	SSH_PORTS=$(sudo sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
	for SSH_PORT in ${SSH_PORTS:-22}; do
		if [ "$SSH_PORT" != "22" ]; then
			echo "Opening alternate SSH port $SSH_PORT."
		fi
		ufw_allow "${SSH_PORT}/tcp"
	done
	ufw_allow http
	ufw_allow https

	sudo ufw --force enable > /dev/null
fi
echo -e "$GREEN Done...$COL_RESET"
echo -e " Installing YiiMP Required system packages...$COL_RESET"
if [ -f /usr/sbin/apache2 ]; then
	echo Removing apache...
	hide_output sudo apt-get -y purge apache2 apache2-bin apache2-data apache2-utils
	hide_output sudo apt-get -y --purge autoremove
fi

hide_output sudo apt-get update

# If the Ondrej PPA is not available for this release fall back to the PHP
# version Ubuntu ships.
if ! apt_has_candidate "php${PHP_VERSION}-fpm"; then
	DISTRO_PHP_VERSION=$(apt-cache depends php-fpm 2>/dev/null | grep -oE 'php[0-9]+\.[0-9]+-fpm' | head -n 1 | grep -oE '[0-9]+\.[0-9]+')
	if [ -z "$DISTRO_PHP_VERSION" ]; then
		echo -e "$RED PHP ${PHP_VERSION} is not available for Ubuntu ${UBUNTU_CODENAME}.$COL_RESET"
		exit 1
	fi
	echo -e "$YELLOW PHP ${PHP_VERSION} is not available, installing PHP ${DISTRO_PHP_VERSION} instead.$COL_RESET"
	PHP_VERSION=$DISTRO_PHP_VERSION
	export PHP_VERSION
	write_conf_file "$STORAGE_ROOT/yiimp/.yiimp.conf" "${YIIMP_CONF_VARS[@]}"
fi

# PHP extensions. php-memcache/php-imagick are versioned in the Ondrej PPA so
# they don't pull in a second PHP version.
PHP_PACKAGES=()
for ext in fpm common cli gd mysql curl intl pspell sqlite3 tidy xsl xml zip mbstring memcache imagick; do
	PHP_PACKAGES+=("php${PHP_VERSION}-${ext}")
done
# opcache is built in from PHP 8.5 and imap was moved out of core in PHP 8.4,
# install them only where a package exists.
for ext in opcache imap; do
	if apt_has_candidate "php${PHP_VERSION}-${ext}"; then
		PHP_PACKAGES+=("php${PHP_VERSION}-${ext}")
	fi
done
apt_install "${PHP_PACKAGES[@]}" php-pear imagemagick memcached

# Build dependencies for YiiMP's stratum/blocknotify. The stratum links against
# libcurl using `pkg-config --static`, so the -dev packages of all of
# libcurl's private dependencies are needed too. libmysqlclient-dev (rather
# than libmariadb-dev) is used because its `mysql_config --libs` also links
# libcrypto, which the stratum needs.
apt_install build-essential libtool autotools-dev automake cmake pkg-config bsdmainutils \
	libgmp-dev libmysqlclient-dev libcurl4-gnutls-dev libssl-dev libsodium-dev libevent-dev \
	libkrb5-dev libldap-dev libidn2-dev libgnutls28-dev nettle-dev librtmp-dev libpsl-dev libnghttp2-dev \
	libssh-dev libssh2-1-dev libzstd-dev libbrotli-dev zlib1g-dev \
	pwgen gnupg ca-certificates lsb-release nginx certbot python3-certbot-nginx

# ### Suppress Upgrade Prompts
# We don't want users to be prompted to upgrade to a new release that we have
# not tested yet.
if [ -f /etc/update-manager/release-upgrades ]; then
	sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
	sudo rm -f /var/lib/ubuntu-release-upgrader/release-upgrade-available
fi

echo -e "$GREEN Done...$COL_RESET"

echo -e " Downloading CryptoPool.builders YiiMP Repo...$COL_RESET"
if [ -n "${YiiMPBranch}" ] && { ! [[ "$YiiMPBranch" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$YiiMPBranch" == -* ]]; }; then
	echo -e "$RED '${YiiMPBranch}' is not a valid git branch name.$COL_RESET"
	exit 1
fi
sudo rm -rf "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
if [ -n "${YiiMPBranch}" ]; then
	hide_output sudo git clone -q --depth 1 -b "${YiiMPBranch}" -- "${YiiMPRepo}" "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
else
	hide_output sudo git clone -q --depth 1 -- "${YiiMPRepo}" "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
fi
echo -e "$GREEN System files installed...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
