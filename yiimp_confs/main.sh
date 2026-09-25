#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

# Create main.sh
sudo tee "$STORAGE_ROOT/yiimp/site/crons/main.sh" > /dev/null <<EOF
#!/usr/bin/env bash

PHP_CLI="php -d max_execution_time=120"

DIR="${STORAGE_ROOT}/yiimp/site/web/"
cd "\${DIR}" || exit 1

date
echo "started in \${DIR}"

while true; do
	\${PHP_CLI} runconsole.php cronjob/run
	sleep 90
done
exec bash
EOF
sudo chmod +x "$STORAGE_ROOT/yiimp/site/crons/main.sh"

cd "$HOME/multipool/yiimp_single" || exit 1
