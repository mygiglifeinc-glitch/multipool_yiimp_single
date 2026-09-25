#!/usr/bin/env bash

#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi
echo -e " Creating initial SSL certificate...$COL_RESET"

# Install openssl.

apt_install openssl

# Create a directory to store TLS-related things like "SSL" certificates.

sudo install -d -m 755 "$STORAGE_ROOT/ssl"

if ! sudo test -f "$STORAGE_ROOT/ssl/ssl_private_key.pem"; then
	# Set the umask so the key file is never world-readable.
	(
		umask 077
		hide_output sudo openssl genrsa -out "$STORAGE_ROOT/ssl/ssl_private_key.pem" 2048
	)
	sudo chmod 600 "$STORAGE_ROOT/ssl/ssl_private_key.pem"
fi

# Generate a self-signed SSL certificate because things like nginx, dovecot,
# etc. won't even start without some certificate in place, and we need nginx
# so we can offer the user a control panel to install a better certificate.
if [ ! -f "$STORAGE_ROOT/ssl/ssl_certificate.pem" ]; then
	# Browsers only look at the subjectAltName, so add one for the host name
	# (or IP address when no domain name is used).
	if [[ "$PRIMARY_HOSTNAME" =~ ^[0-9.]+$ || "$PRIMARY_HOSTNAME" == *:* ]]; then
		CERT_SAN="IP:${PRIMARY_HOSTNAME}"
	else
		CERT_SAN="DNS:${PRIMARY_HOSTNAME}"
	fi

	# Generate the self-signed certificate.
	CERT="$STORAGE_ROOT/ssl/$PRIMARY_HOSTNAME-selfsigned-$(date +%Y%m%d).pem"
	hide_output sudo openssl req -new -x509 -sha256 -days 365 \
		-key "$STORAGE_ROOT/ssl/ssl_private_key.pem" -out "$CERT" \
		-subj "/CN=$PRIMARY_HOSTNAME" -addext "subjectAltName=${CERT_SAN}"

	# Symlink the certificate into the system certificate path, so system services
	# can find it.
	sudo ln -sfn "$CERT" "$STORAGE_ROOT/ssl/ssl_certificate.pem"
fi

# Generate some Diffie-Hellman cipher bits.
# openssl's default bit length for this is 1024 bits, but we'll create
# 2048 bits of bits per the latest recommendations.
if [ ! -f /etc/nginx/dhparam.pem ]; then
	sudo mkdir -p /etc/nginx
	hide_output sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
fi

echo -e "$GREEN Initial Self Signed SSL Generation complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
