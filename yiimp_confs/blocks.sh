#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

# Create blocks.sh
sudo tee "$STORAGE_ROOT/yiimp/site/crons/blocks.sh" > /dev/null <<EOF
#!/usr/bin/env bash

PHP_CLI="php -d max_execution_time=60"

DIR="${STORAGE_ROOT}/yiimp/site/web/"
cd "\${DIR}" || exit 1

date
echo "started in \${DIR}"

while true; do
	\${PHP_CLI} runconsole.php cronjob/runBlocks
	sleep 20
done
exec bash
EOF
sudo chmod +x "$STORAGE_ROOT/yiimp/site/crons/blocks.sh"

cd "$HOME/multipool/yiimp_single" || exit 1
