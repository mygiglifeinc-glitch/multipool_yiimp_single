#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh # load our functions
source /etc/multipool.conf

apt_install lsb-release figlet update-motd \
	landscape-common update-notifier-common
cd "$HOME/multipool/yiimp_single/ubuntu/etc/update-motd.d" || exit 1
sudo rm -rf /etc/update-motd.d/
sudo mkdir /etc/update-motd.d/
sudo install -m 755 00-header 10-sysinfo 90-footer /etc/update-motd.d/

cd "$HOME/multipool/yiimp_single/ubuntu" || exit 1
# copy additional files
sudo install -m 755 screens stratum addport /usr/bin/
sudo tee /usr/bin/motd > /dev/null <<'EOF'
#!/usr/bin/env bash
clear
run-parts /etc/update-motd.d/ | sudo tee /etc/motd
EOF
sudo chmod 755 /usr/bin/motd
cd "$HOME/multipool/yiimp_single" || exit 1
