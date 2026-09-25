#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
PHP_VERSION="${PHP_VERSION:-${MULTIPOOL_DEFAULT_PHP_VERSION:-8.3}}"
cd "$HOME/multipool/yiimp_single" || exit 1

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

# NGINX configuration. The Ubuntu nginx package is used (installed in system.sh).
echo -e " Configuring NGINX...$COL_RESET"
apt_install nginx

# Make additional conf directories, move and generate needed configurations.
sudo mkdir -p /etc/nginx/cryptopool.builders
if [ ! -f /etc/nginx/nginx.conf.old ]; then
	sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
fi
sudo install -m 644 nginx_confs/nginx.conf /etc/nginx/nginx.conf
sudo install -m 644 nginx_confs/general.conf /etc/nginx/cryptopool.builders/general.conf
sudo install -m 644 nginx_confs/security.conf /etc/nginx/cryptopool.builders/security.conf
sudo install -m 644 nginx_confs/letsencrypt.conf /etc/nginx/cryptopool.builders/letsencrypt.conf
sed "s|@PHP_VERSION@|${PHP_VERSION}|g" nginx_confs/php_fastcgi.conf \
	| sudo tee /etc/nginx/cryptopool.builders/php_fastcgi.conf > /dev/null

# Removing default nginx site configs.
sudo rm -f /etc/nginx/conf.d/default.conf
sudo rm -f /etc/nginx/sites-enabled/default*
sudo rm -f /etc/nginx/sites-available/default*

# Don't expose the PHP version in the X-Powered-By header.
if [ -f "/etc/php/${PHP_VERSION}/fpm/php.ini" ]; then
	sudo sed -i 's/^;\?expose_php *=.*/expose_php = Off/' "/etc/php/${PHP_VERSION}/fpm/php.ini"
fi

hide_output sudo nginx -t
echo -e "$GREEN NGINX configuration complete...$COL_RESET"
restart_service nginx
restart_service "php${PHP_VERSION}-fpm"
cd "$HOME/multipool/yiimp_single" || exit 1
