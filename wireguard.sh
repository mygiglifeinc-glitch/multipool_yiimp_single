#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"
source "$STORAGE_ROOT/yiimp/.wireguard.conf"

clear
echo -e " Installing WireGuard...$COL_RESET"
# WireGuard is part of the kernel on all supported Ubuntu releases, only the
# userspace tools are needed.
hide_output sudo apt-get update
apt_install wireguard wireguard-tools ufw

if ! sudo test -f /etc/wireguard/wg0.conf; then
	sudo install -d -m 700 /etc/wireguard
	wg_private_key=$(wg genkey)
	wg_conf=$(mktemp)
	chmod 600 "$wg_conf"
	cat > "$wg_conf" <<EOF
[Interface]
PrivateKey = ${wg_private_key}
ListenPort = 6121
SaveConfig = true
Address = ${DBInternalIP}/24
EOF
	sudo install -m 600 -o root -g root "$wg_conf" /etc/wireguard/wg0.conf
	rm -f "$wg_conf"
	printf '%s\n' "$wg_private_key" | wg pubkey | sudo tee /etc/wireguard/publickey > /dev/null
	unset wg_private_key wg_conf
fi

# Install WireGuard on main server.
hide_output sudo systemctl enable --now wg-quick@wg0
ufw_allow 6121/udp
clear
dbpublic=${PUBLIC_IP}
mypublic="$(sudo cat /etc/wireguard/publickey)"

printf '  Public Ip: %s\nPublic Key: %s\n' "${dbpublic}" "${mypublic}" \
	| sudo tee "$STORAGE_ROOT/yiimp/.wireguard_public.conf" > /dev/null

echo -e "$GREEN WireGuard setup completed...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
