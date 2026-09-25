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

# Escape a value for use in the replacement part of a sed s|...|...| command.
function sed_escape {
	printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'
}

echo -e " Building blocknotify and stratum...$COL_RESET"

cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/blocknotify" || exit 1
blckntifypass=$(generate_password 32)
sudo sed -i "s|tu8tu5|$(sed_escape "$blckntifypass")|" blocknotify.cpp
hide_output sudo make
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/stratum/iniparser" || exit 1
hide_output sudo make
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/stratum" || exit 1
# Build fix for current compilers (GCC 11+ reject arrays of the 64 byte aligned
# blake2 state typedefs): put the alignment on the struct instead.
sudo sed -i -E 's/^ALIGN\( *64 *\) typedef struct/typedef struct ALIGN(64)/' sha3/blake2s.h sha3/blake2b.h
if [[ "$AutoExchange" == "yes" ]]; then
	sudo sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/stratum/Makefile"
fi
hide_output sudo make

echo -e " Building stratum folder structure and copying files...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/stratum" || exit 1
sudo mkdir -p "$STORAGE_ROOT/yiimp/site/stratum/config"
sudo cp -a config.sample/. "$STORAGE_ROOT/yiimp/site/stratum/config"
sudo cp stratum "$STORAGE_ROOT/yiimp/site/stratum"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp" || exit 1
sudo cp "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/blocknotify/blocknotify" "$STORAGE_ROOT/yiimp/site/stratum"
sudo cp "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/blocknotify/blocknotify" /usr/bin

sudo rm -f "$STORAGE_ROOT/yiimp/site/stratum/config/run.sh"
sudo tee "$STORAGE_ROOT/yiimp/site/stratum/config/run.sh" > /dev/null <<EOF
#!/usr/bin/env bash
ulimit -n 10240
ulimit -u 10240
cd "${STORAGE_ROOT}/yiimp/site/stratum" || exit 1
while true; do
	./stratum "config/\$1"
	sleep 2
done
exec bash
EOF
sudo chmod 755 "$STORAGE_ROOT/yiimp/site/stratum/config/run.sh"

sudo rm -f "$STORAGE_ROOT/yiimp/site/stratum/run.sh"
sudo tee "$STORAGE_ROOT/yiimp/site/stratum/run.sh" > /dev/null <<EOF
#!/usr/bin/env bash
cd "${STORAGE_ROOT}/yiimp/site/stratum/config/" && exec ./run.sh "\$@"
EOF
sudo chmod 755 "$STORAGE_ROOT/yiimp/site/stratum/run.sh"

echo -e " Updating stratum config files with database connection info...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/site/stratum/config" || exit 1

if [[ "$wireguard" == "true" ]]; then
	StratumDBHost=${DBInternalIP}
else
	StratumDBHost=localhost
fi
sudo sed -i \
	-e "s|password = tu8tu5|password = $(sed_escape "$blckntifypass")|g" \
	-e "s|server = yaamp.com|server = $(sed_escape "$StratumURL")|g" \
	-e "s|host = yaampdb|host = $(sed_escape "$StratumDBHost")|g" \
	-e "s|database = yaamp|database = $(sed_escape "$YiiMPDBName")|g" \
	-e "s|username = root|username = $(sed_escape "$StratumDBUser")|g" \
	-e "s|password = patofpaq|password = $(sed_escape "$StratumUserDBPassword")|g" \
	./*.conf
unset blckntifypass

# The config files contain the stratum database password: only the installing
# user (who runs the stratum screens) may read them.
sudo chown -R "$(id -un):$(id -gn)" "$STORAGE_ROOT/yiimp/site/stratum/config"
sudo chmod 640 "$STORAGE_ROOT"/yiimp/site/stratum/config/*.conf

#set permissions
sudo setfacl -m "u:$(id -un):rwx" "$STORAGE_ROOT/yiimp/site/stratum/"
sudo setfacl -m "u:$(id -un):rwx" "$STORAGE_ROOT/yiimp/site/stratum/config"

echo -e "$GREEN Stratum build complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
