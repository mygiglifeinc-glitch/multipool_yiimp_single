#!/usr/bin/env bash

#####################################################
# Source various web sources:
# https://www.linuxbabe.com/ubuntu/enable-google-tcp-bbr-ubuntu
# https://www.cyberciti.biz/faq/linux-tcp-tuning/
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf

echo -e " Boosting server performance for YiiMP...$COL_RESET"
# Boost Network Performance by Enabling TCP BBR (available in the kernels of
# all supported Ubuntu releases) and tune the network stack.
sudo tee /etc/sysctl.d/60-multipool.conf > /dev/null <<'EOF'
# Created by the MultiPool YiiMP installer.
# TCP BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Tune Network Stack
net.core.wmem_max = 12582912
net.core.rmem_max = 12582912
net.ipv4.tcp_rmem = 10240 87380 12582912
net.ipv4.tcp_wmem = 10240 87380 12582912
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
EOF
sudo modprobe tcp_bbr 2>/dev/null || true
sudo sysctl --system > /dev/null 2>&1 || true
echo -e "$GREEN Tuning complete...$COL_RESET"

echo -e " Hardening server security...$COL_RESET"

# Automatic security updates.
apt_install unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# fail2ban: protect SSH on the port(s) sshd actually listens on.
apt_install fail2ban
SSH_PORTS=$(sudo sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }' | paste -sd, -)
sudo tee /etc/fail2ban/jail.d/multipool-sshd.local > /dev/null <<EOF
# Created by the MultiPool YiiMP installer.
[sshd]
enabled = true
port = ${SSH_PORTS:-ssh}
EOF
sudo systemctl enable fail2ban > /dev/null 2>&1 || true
restart_service fail2ban

# SSH: no root logins (the installer runs as a sudo user). Password logins are
# only disabled if the installing user has an SSH key, so nobody is locked out.
SSHD_DROPIN=/etc/ssh/sshd_config.d/01-multipool-hardening.conf
if [ -d /etc/ssh/sshd_config.d ] && [ "$(id -u)" -ne 0 ]; then
	SSHD_SETTINGS="# Created by the MultiPool YiiMP installer.
PermitRootLogin no"
	if [ -s "$HOME/.ssh/authorized_keys" ] && grep -qE '^(ssh-|ecdsa-|sk-)' "$HOME/.ssh/authorized_keys"; then
		SSHD_SETTINGS+="
PasswordAuthentication no
KbdInteractiveAuthentication no"
	else
		echo -e "$YELLOW No SSH key found for $(id -un), password logins stay enabled.$COL_RESET"
	fi
	echo "$SSHD_SETTINGS" | sudo tee "$SSHD_DROPIN" > /dev/null
	if sudo sshd -t; then
		sudo systemctl try-reload-or-restart ssh || true
	else
		echo -e "$RED sshd configuration test failed, removing $SSHD_DROPIN.$COL_RESET"
		sudo rm -f "$SSHD_DROPIN"
	fi
fi
echo -e "$GREEN Hardening complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
