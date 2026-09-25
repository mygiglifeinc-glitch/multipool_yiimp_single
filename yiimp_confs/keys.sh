#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

# Escape a value for use inside a single quoted PHP string.
function php_escape {
	local value=${1//\\/\\\\}
	printf '%s' "${value//\'/\\\'}"
}

#Create keys file
# It contains the database password: readable by root and the web server
# group (php-fpm and the installing user, who is a member of www-data).
KEYS_PHP=$(mktemp)
cat > "$KEYS_PHP" <<EOF
<?php
// Sample config file to put in /etc/yiimp/keys.php
define('YIIMP_MYSQLDUMP_USER', '$(php_escape "${YiiMPPanelName}")');
define('YIIMP_MYSQLDUMP_PASS', '$(php_escape "${PanelUserDBPassword}")');
define('YIIMP_MYSQLDUMP_PATH', '$(php_escape "${STORAGE_ROOT}/yiimp/site/backup")');
// Keys required to create/cancel orders and access your balances/deposit addresses
define('EXCH_BITTREX_SECRET', '');
define('EXCH_BITSTAMP_SECRET', '');
define('EXCH_BINANCE_SECRET', '');
define('EXCH_BLEUTRADE_SECRET', '');
define('EXCH_BTER_SECRET', '');
define('EXCH_CCEX_SECRET', '');
define('EXCH_CEXIO_SECRET', '');
define('EXCH_COINMARKETS_PASS', '');
define('EXCH_CRYPTOPIA_SECRET', '');
define('EXCH_EMPOEX_SECKEY', '');
define('EXCH_HITBTC_SECRET', '');
define('EXCH_KRAKEN_SECRET', '');
define('EXCH_KUCOIN_SECRET', '');
define('EXCH_LIVECOIN_SECRET', '');
define('EXCH_NOVA_SECRET', '');
define('EXCH_POLONIEX_SECRET', '');
define('EXCH_STOCKSEXCHANGE_SECRET', '');
define('EXCH_YOBIT_SECRET', '');
EOF
sudo mkdir -p /etc/yiimp
sudo install -m 640 -o root -g www-data "$KEYS_PHP" /etc/yiimp/keys.php
rm -f "$KEYS_PHP"
cd "$HOME/multipool/yiimp_single" || exit 1
