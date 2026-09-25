#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
cd "$HOME/multipool/yiimp_single" || exit 1

# Add a line to the user's crontab unless it is already there.
function add_crontab_line {
	local line=$1
	{ crontab -l 2>/dev/null | grep -vxF -- "$line"; echo "$line"; } | crontab -
}

echo -e " Installing cron screens to crontab...$COL_RESET"

# Remove lines added by older versions of this installer that did nothing.
{ crontab -l 2>/dev/null | grep -vxF -e "@reboot source /etc/functions.sh" -e "@reboot source /etc/multipool.conf"; } | crontab -

add_crontab_line "@reboot sleep 20 && ${STORAGE_ROOT}/yiimp/starts/screens.start.sh"
if [[ "$CoinPort" == "no" ]]; then
	add_crontab_line "@reboot sleep 20 && ${STORAGE_ROOT}/yiimp/starts/stratum.start.sh"
fi

sudo cp first_boot.sh "$STORAGE_ROOT/yiimp/"

echo -e "$GREEN Crontab system complete...$COL_RESET"
echo -e " Creating YiiMP Screens startup script...$COL_RESET"

sudo tee "$STORAGE_ROOT/yiimp/starts/screens.start.sh" > /dev/null <<'EOF'
#!/usr/bin/env bash
################################################################################
# Author: cryptopool.builders
#
#
# Program: yiimp screen startup script
#
# BTC Donation: 12Pt3vQhQpXvyzBd5qcoL17ouhNFyihyz5
#
################################################################################
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
# Ugly way to remove junk coins from initial YiiMP database on first boot
if [[ -e "$STORAGE_ROOT/yiimp/first_boot.sh" ]]; then
	source "$STORAGE_ROOT/yiimp/first_boot.sh"
fi
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons
screen -dmS main bash "$CRONS/main.sh"
screen -dmS loop2 bash "$CRONS/loop2.sh"
screen -dmS blocks bash "$CRONS/blocks.sh"
screen -dmS debug tail -F "$LOG_DIR/debug.log"
EOF
sudo chmod 755 "$STORAGE_ROOT/yiimp/starts/screens.start.sh"

echo -e " Creating Stratum screens start script...$COL_RESET"

sudo tee "$STORAGE_ROOT/yiimp/starts/stratum.start.sh" > /dev/null <<'EOF'
#!/usr/bin/env bash
################################################################################
# Author: cryptopool.builders
#
#
# Program: yiimp stratum startup script
#
# BTC Donation: 12Pt3vQhQpXvyzBd5qcoL17ouhNFyihyz5
#
################################################################################
source /etc/multipool.conf
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum

# screen name / stratum config (algo) name. Algos without a config file are skipped.
while read -r screen_name algo; do
	if [ -f "$STRATUM_DIR/config/${algo}.conf" ]; then
		screen -dmS "$screen_name" bash "$STRATUM_DIR/run.sh" "$algo"
	fi
done <<'ALGOS'
c11 c11
deep deep
x11 x11
2x11evo x11evo
x13 x13
x14 x14
x15 x15
x17 x17
xevan xevan
timetravel timetravel
bitcore bitcore
hmq1725 hmq1725
tribus tribus
sha sha
2sha256t sha256t
scrypt scrypt
2scryptn scryptn
luffa luffa
neo neo
nist5 nist5
penta penta
quark quark
qubit qubit
jha jha
dmd-gr dmd-gr
myr-gr myr-gr
lbry lbry
lyra2 lyra2
2lyra2v2 lyra2v2
zero lyra2z
blakecoin blakecoin
blake blake
2blake2s blake2s
vanilla vanilla
decred decred
keccak keccak
whirlpool whirlpool
skein skein
2skein2 skein2
yescrypt yescrypt
zr5 zr5
sib sib
m7m m7m
veltor veltor
velvet velvet
argon2 argon2
groestl groestl
skunk skunk
phi1612 phi1612
hsr hsr
yescryptr16 yescryptR16
x16r x16r
ALGOS
EOF
sudo chmod 755 "$STORAGE_ROOT/yiimp/starts/stratum.start.sh"

PRESCREENS_CONF=$(mktemp)
cat > "$PRESCREENS_CONF" <<'EOF'
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
EOF
sudo install -m 600 -o "$(id -un)" -g "$(id -gn)" "$PRESCREENS_CONF" "$STORAGE_ROOT/yiimp/.prescreens.start.conf"
rm -f "$PRESCREENS_CONF"

for bashrc_line in "source /etc/multipool.conf" "source $STORAGE_ROOT/yiimp/.prescreens.start.conf"; do
	if ! grep -qxF -- "$bashrc_line" ~/.bashrc 2>/dev/null; then
		echo "$bashrc_line" >> ~/.bashrc
	fi
done
echo -e "$GREEN YiiMP Screens added...$COL_RESET"

# Make sure the files with passwords are only readable by their owner.
sudo chmod 600 "$STORAGE_ROOT/yiimp/.yiimp.conf" "$STORAGE_ROOT/yiimp/.my.cnf"

sudo rm -rf "$STORAGE_ROOT/yiimp/yiimp_setup"
cd "$HOME/multipool/yiimp_single" || exit 1
