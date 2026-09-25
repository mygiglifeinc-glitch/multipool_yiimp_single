#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

# Escape a value for use inside a single quoted SQL string.
function sql_escape {
	local value=${1//\\/\\\\}
	printf '%s' "${value//\'/\\\'}"
}

echo -e " Installing MariaDB...$COL_RESET"
apt_install mariadb-server mariadb-client
hide_output sudo systemctl enable --now mariadb
echo -e "$GREEN MariaDB build complete...$COL_RESET"

# The equivalent of mariadb-secure-installation: root may only log in locally
# (through the unix socket as the system root user, or with the password),
# no anonymous users and no test database.
echo -e " Securing MariaDB...$COL_RESET"
sudo mariadb <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('$(sql_escape "$DBRootPassword")');
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\\\_%';
FLUSH PRIVILEGES;
EOF
echo -e "$GREEN MariaDB secured...$COL_RESET"

echo -e " Creating DB users for YiiMP...$COL_RESET"

# The web panel and stratum connect over the WireGuard address when it is
# used, otherwise over the local socket.
if [[ "$wireguard" == "true" ]]; then
	DBUserHost=${DBInternalIP}
	DBClientHost=${DBInternalIP}
else
	DBUserHost=localhost
	DBClientHost=localhost
fi

# Each user only gets the privileges it needs on the YiiMP database.
sudo mariadb <<EOF
CREATE DATABASE IF NOT EXISTS \`${YiiMPDBName}\`;
CREATE USER IF NOT EXISTS '${YiiMPPanelName}'@'${DBUserHost}';
ALTER USER '${YiiMPPanelName}'@'${DBUserHost}' IDENTIFIED BY '$(sql_escape "$PanelUserDBPassword")';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, CREATE TEMPORARY TABLES, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT, EXECUTE ON \`${YiiMPDBName}\`.* TO '${YiiMPPanelName}'@'${DBUserHost}';
CREATE USER IF NOT EXISTS '${StratumDBUser}'@'${DBUserHost}';
ALTER USER '${StratumDBUser}'@'${DBUserHost}' IDENTIFIED BY '$(sql_escape "$StratumUserDBPassword")';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${YiiMPDBName}\`.* TO '${StratumDBUser}'@'${DBUserHost}';
FLUSH PRIVILEGES;
EOF

echo -e "$GREEN Database creation complete...$COL_RESET"

echo -e " Creating my.cnf...$COL_RESET"

MY_CNF=$(mktemp)
cat > "$MY_CNF" <<EOF
[clienthost1]
user=${YiiMPPanelName}
password=${PanelUserDBPassword}
database=${YiiMPDBName}
host=${DBClientHost}
[clienthost2]
user=${StratumDBUser}
password=${StratumUserDBPassword}
database=${YiiMPDBName}
host=${DBClientHost}
[mysql]
user=root
password=${DBRootPassword}
EOF
sudo install -m 600 -o "$(id -un)" -g "$(id -gn)" "$MY_CNF" "$STORAGE_ROOT/yiimp/.my.cnf"
rm -f "$MY_CNF"
echo -e "$GREEN Passwords can be found in $STORAGE_ROOT/yiimp/.my.cnf$COL_RESET"

echo -e " Importing YiiMP Default database values...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/sql" || exit 1
# import sql dump
zcat 2019-11-10-yiimp.sql.gz | sudo mariadb "${YiiMPDBName}"
sudo mariadb "${YiiMPDBName}" --force < 2018-09-22-workers.sql
echo -e "$GREEN Database import complete...$COL_RESET"

echo -e " Tweaking MariaDB for better performance...$COL_RESET"
MARIADB_TUNING=$(mktemp)
cat > "$MARIADB_TUNING" <<EOF
# Created by the MultiPool YiiMP installer.
[mysqld]
max_connections         = 800
thread_cache_size       = 512
tmp_table_size          = 128M
max_heap_table_size     = 128M
wait_timeout            = 60
max_allowed_packet      = 64M
EOF
if [[ "$wireguard" == "true" ]]; then
	# Only listen on the private WireGuard address.
	echo "bind-address            = ${DBInternalIP}" >> "$MARIADB_TUNING"

	# The WireGuard interface has to be up before MariaDB can bind to it.
	sudo mkdir -p /etc/systemd/system/mariadb.service.d
	printf '[Unit]\nWants=wg-quick@wg0.service\nAfter=wg-quick@wg0.service\n' \
		| sudo tee /etc/systemd/system/mariadb.service.d/multipool-wireguard.conf > /dev/null
	sudo systemctl daemon-reload
fi
sudo install -m 644 "$MARIADB_TUNING" /etc/mysql/mariadb.conf.d/60-multipool.cnf
rm -f "$MARIADB_TUNING"

echo -e "$GREEN Database tweak complete...$COL_RESET"
restart_service mariadb
echo -e "$GREEN Database build complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
