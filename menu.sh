#!/usr/bin/env bash

#####################################################
# Source code https://github.com/end222/pacmenu
# Updated by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh

while true; do
	RESULT=$(dialog --stdout --default-item 1 --title "Ultimate Crypto-Server Setup Installer v2.0.0" --menu "Choose one" -1 60 6 \
		' ' "- For small private pools -" \
		1 "YiiMP - Single Server" \
		' ' "- If you plan on adding more servers later -" \
		2 "YiiMP - Single Server with WireGuard" \
		3 Exit)
	RESULT_EXITCODE=$?

	# Cancel / ESC
	if [ "$RESULT_EXITCODE" -ne 0 ]; then
		clear
		exit 0
	fi

	case "$RESULT" in
		1)
			clear
			wireguard=false
			write_conf_file "$HOME/multipool/yiimp_single/.wireguard.install.cnf" wireguard
			break
			;;
		2)
			clear
			wireguard=true
			write_conf_file "$HOME/multipool/yiimp_single/.wireguard.install.cnf" wireguard
			server_type=db
			DBInternalIP=10.0.0.2
			write_conf_file "$STORAGE_ROOT/yiimp/.wireguard.conf" server_type DBInternalIP
			break
			;;
		3)
			clear
			exit 0
			;;
		*)
			# One of the separator lines was selected, show the menu again.
			;;
	esac
done
