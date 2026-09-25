#!/usr/bin/env bash

#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

echo -e " Building web file structure and copying files...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp" || exit 1
sudo sed -i "s/AdminRights/${AdminPanel}/" "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/web/yaamp/modules/site/SiteController.php"
sudo cp -r "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/web" "$STORAGE_ROOT/yiimp/site/"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/" || exit 1
sudo cp -r "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/bin/." /bin/
sudo mkdir -p "/var/www/${DomainName}/html"
sudo mkdir -p /etc/yiimp
sudo mkdir -p "$STORAGE_ROOT/yiimp/site/backup/"
sudo sed -i "s|ROOTDIR=/data/yiimp|ROOTDIR=${STORAGE_ROOT}/yiimp/site|g" /bin/yiimp

cd "$HOME/multipool/yiimp_single" || exit 1
source nginx_site.sh

echo -e " Creating YiiMP configuration files...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
source yiimp_confs/keys.sh
source yiimp_confs/yiimpserverconfig.sh
source yiimp_confs/main.sh
source yiimp_confs/loop2.sh
source yiimp_confs/blocks.sh
echo -e "$GREEN Done...$COL_RESET"

echo -e " Setting correct folder permissions...$COL_RESET"
whoami=$(id -un)
sudo usermod -aG www-data "$whoami"
sudo usermod -aG "${STORAGE_USER:-crypto-data}" "$whoami"
sudo usermod -aG "${STORAGE_USER:-crypto-data}" www-data

sudo find "$STORAGE_ROOT/yiimp/site/" -type d -exec chmod 775 {} +
sudo find "$STORAGE_ROOT/yiimp/site/" -type f -exec chmod 664 {} +

sudo chgrp -R www-data "$STORAGE_ROOT"
sudo chmod -R g+w "$STORAGE_ROOT"

# The web server (www-data) and the installing user's cron screens both write
# to the log folder: new files there stay writable for both.
sudo setfacl -R -m "u:${whoami}:rwX,g:www-data:rwX" "$STORAGE_ROOT/yiimp/site/log"
sudo setfacl -R -d -m "u:${whoami}:rwX,g:www-data:rwX" "$STORAGE_ROOT/yiimp/site/log"

# Files with passwords must not be readable by everyone.
sudo chmod 640 "$STORAGE_ROOT/yiimp/site/configuration/serverconfig.php"
sudo chmod 600 "$STORAGE_ROOT/yiimp/.yiimp.conf" "$STORAGE_ROOT/yiimp/.my.cnf" "$STORAGE_ROOT/ssl/ssl_private_key.pem"
sudo chmod -R g-w "$STORAGE_ROOT/ssl"
echo -e "$GREEN Done...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1

#Updating YiiMP files for cryptopool.builders build
echo -e " Adding the cryptopool.builders flare to YiiMP...$COL_RESET"

sudo sed -i "s/YII MINING POOLS/${DomainName} Mining Pool/g" "$STORAGE_ROOT/yiimp/site/web/yaamp/modules/site/index.php"
sudo sed -i "s/domain/${DomainName}/g" "$STORAGE_ROOT/yiimp/site/web/yaamp/modules/site/index.php"
sudo sed -i 's/Notes/AddNodes/g' "$STORAGE_ROOT/yiimp/site/web/yaamp/models/db_coinsModel.php"
for php_file in web/index.php web/runconsole.php web/run.php web/yaamp/yiic.php web/yaamp/modules/thread/CronjobController.php; do
	sudo sed -i "s|serverconfig.php|${STORAGE_ROOT}/yiimp/site/configuration/serverconfig.php|g" "$STORAGE_ROOT/yiimp/site/$php_file"
done
sudo sed -i "s|/root/backup|${STORAGE_ROOT}/yiimp/site/backup|g" "$STORAGE_ROOT/yiimp/site/web/yaamp/core/backend/system.php"
# shellcheck disable=SC2016 # $webserver is PHP code, not a shell variable
sudo sed -i 's/service $webserver start/sudo service $webserver start/g' "$STORAGE_ROOT/yiimp/site/web/yaamp/modules/thread/CronjobController.php"
sudo sed -i 's/service nginx stop/sudo service nginx stop/g' "$STORAGE_ROOT/yiimp/site/web/yaamp/modules/thread/CronjobController.php"

if [[ "$wireguard" == "true" ]]; then
	#Set Insternal IP to .0/26
	internalrpcip="${DBInternalIP%.*}.0/26"
	sudo sed -i '/# onlynet=ipv4/i\        echo "rpcallowip='"${internalrpcip}"'\\n";' "$STORAGE_ROOT/yiimp/site/web/yaamp/modules/site/coin_form.php"
fi

echo -e "$GREEN Web build complete...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
