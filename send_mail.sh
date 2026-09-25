#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

echo -e " Installing mail system $COL_RESET"

sudo debconf-set-selections <<< "postfix postfix/mailname string ${PRIMARY_HOSTNAME}"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type select Internet Site"
apt_install postfix mailutils

# Only send mail from this machine, never accept mail from the network.
# shellcheck disable=SC2016 # $myhostname etc. are postfix variables
hide_output sudo postconf -e \
	'inet_interfaces = loopback-only' \
	'myhostname = localhost' \
	'mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain'

restart_service postfix
whoami=$(id -un)

# Forward mail for root and the installing user to the support email.
for alias_user in root "$whoami"; do
	if grep -q "^${alias_user}:" /etc/aliases; then
		sudo sed -i "s|^${alias_user}:.*|${alias_user}:          ${SupportEmail}|" /etc/aliases
	else
		echo "${alias_user}:          ${SupportEmail}" | sudo tee -a /etc/aliases > /dev/null
	fi
done
hide_output sudo newaliases

sudo usermod -aG mail "$whoami"
echo -e "$GREEN Mail system complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
