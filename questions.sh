#!/usr/bin/env bash

#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"
if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

# Allowed formats for the answers. Everything the user enters ends up in
# nginx, PHP, SQL and shell configuration files, so only accept values that
# are safe in all of them.
RE_HOSTNAME='^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'
RE_EMAIL='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$'
RE_PATH_NAME='^[A-Za-z0-9_-]+$'
RE_IP_LIST='^[0-9A-Fa-f:.,/]+$'
RE_PASSWORD='^[A-Za-z0-9._+=@-]{8,64}$'

# ask_value "title" "prompt" "default" VARIABLE REGEX
# Asks for VARIABLE unless it is already set, and keeps asking until the
# answer matches REGEX. Exits the installer if the user cancels.
function ask_value {
	local title=$1 prompt=$2 default_value=$3 var_name=$4 regex=$5
	local exit_code_var="${var_name}_EXITCODE"
	while true; do
		if [ -z "${!var_name:-}" ]; then
			input_box "$title" "$prompt" "$default_value" "$var_name"
			if [ "${!exit_code_var}" -ne 0 ] || [ -z "${!var_name}" ]; then
				# user hit ESC/cancel
				clear
				exit
			fi
		fi
		if [[ "${!var_name}" =~ $regex ]]; then
			return 0
		fi
		message_box "Invalid Input" "The value entered for \"${title}\" is not valid, please try again."
		printf -v "$var_name" '%s' ""
	done
}

# ask_yes_no "title" "question" VARIABLE
function ask_yes_no {
	local title=$1 question=$2 var_name=$3 response
	dialog --title "$title" --yesno "$question" 7 60
	response=$?
	case $response in
		0) printf -v "$var_name" '%s' yes ;;
		1) printf -v "$var_name" '%s' no ;;
		*)
			clear
			echo "User canceled installation"
			exit 0
			;;
	esac
}

if [[ "$wireguard" == "true" ]]; then
	message_box "Ultimate Crypto-Server Setup Installer" \
		"You have choosen to install YiiMP Single Server with WireGuard!
\n\nThis option will install all componets of YiiMP on a single server along with WireGuard so you can easily add additional servers in the future.
\n\nPlease make sure any domain name or sub domain names are pointed to this servers IP prior to running this installer.
\n\nAfter answering the following questions, setup will be automated.
\n\nNOTE: If installing on a system with less then 8 GB of RAM you may experience system issues!"
else
	message_box "Ultimate Crypto-Server Setup Installer" \
		"You have choosen to install YiiMP Single Server!
\n\nThis option will install all componets of YiiMP on a single server.
\n\nPlease make sure any domain name or sub domain names are pointed to this servers IP prior to running this installer.
\n\nAfter answering the following questions, setup will be automated.
\n\nNOTE: If installing on a system with less then 8 GB of RAM you may experience system issues!"
fi

while true; do

	# Begin user inputted responses for auto install
	ask_yes_no "Using Domain Name" "Are you using a domain name? Example: example.com?
Make sure the DNS is updated!" UsingDomain

	if [[ "$UsingDomain" == "yes" ]]; then

		ask_yes_no "Using Sub-Domain" "Are you using a sub-domain for the main website domain? Example pool.example.com?
Make sure the DNS is updated!" UsingSubDomain

		ask_value "Domain Name" \
			"Enter your domain name. If using a subdomain enter the full domain as in pool.example.com
\n\nDo not add www. to the domain name.
\n\nMake sure the domain is pointed to this server before continuing!
\n\nDomain Name:" \
			"example.com" \
			DomainName "$RE_HOSTNAME"

		ask_value "Stratum URL" \
			"Enter your stratum URL. It is recommended to use another subdomain such as stratum.${DomainName}
\n\nDo not add www. to the domain name.
\n\nStratum URL:" \
			"stratum.${DomainName}" \
			StratumURL "$RE_HOSTNAME"

		ask_yes_no "Install SSL" "Would you like the system to install SSL automatically?" InstallSSL
	else

		# If user is not using a domain and is just using the server IP these fileds can be automatically detected.

		# Sets server IP automatically
		DomainName=$(get_publicip_from_web_service 4 || get_default_privateip 4)
		StratumURL=$DomainName
		UsingSubDomain=no
		InstallSSL=no
	fi

	# Back to user input questions regardless of domain name or IP use
	ask_value "System Email" \
		"Enter an email address for the system to send alerts and other important messages.
\n\nSystem Email:" \
		"root@localhost" \
		SupportEmail "$RE_EMAIL"

	ask_value "Admin Panel Location" \
		"Enter your desired location name for admin access..
\n\nOnce set you will access the YiiMP admin at ${DomainName}/site/AdminPortal
\n\nDesired Admin Panel Location:" \
		"AdminPortal" \
		AdminPanel "$RE_PATH_NAME"

	ask_yes_no "Use AutoExchange" "Would you like the stratum to be built with autoexchange enabled?" AutoExchange

	ask_yes_no "Use Dedicated Coin Ports" "Would you like YiiMP to be built with dedicated coin ports?" CoinPort

	if [ -n "${SSH_CLIENT:-}" ]; then
		DEFAULT_PublicIP=${SSH_CLIENT%% *}
	else
		DEFAULT_PublicIP=192.168.0.1
	fi
	ask_value "Your Public IP" \
		"Enter your public IP from the remote system you will access your admin panel from.
\n\nWe have guessed your public IP from the IP used to access this system.
\n\nGo to whatsmyip.org if you are unsure this is your public IP.
\n\nYour Public IP:" \
		"${DEFAULT_PublicIP}" \
		PublicIP "$RE_IP_LIST"

	# These are all autgenerated but give user the oppertunity to set
	ask_value "Database Root Password" \
		"Enter your desired database root password.
\n\nYou may use the system generated password shown.
\n\nAllowed characters: A-Z a-z 0-9 . _ + = @ - (8 to 64 characters)
\n\nDesired Database Password:" \
		"$(generate_password 32)" \
		DBRootPassword "$RE_PASSWORD"

	ask_value "Database Panel Password" \
		"Enter your desired database panel password.
\n\nYou may use the system generated password shown.
\n\nAllowed characters: A-Z a-z 0-9 . _ + = @ - (8 to 64 characters)
\n\nDesired Database Password:" \
		"$(generate_password 32)" \
		PanelUserDBPassword "$RE_PASSWORD"

	ask_value "Database Stratum Password" \
		"Enter your desired database stratum password.
\n\nYou may use the system generated password shown.
\n\nAllowed characters: A-Z a-z 0-9 . _ + = @ - (8 to 64 characters)
\n\nDesired Database Password:" \
		"$(generate_password 32)" \
		StratumUserDBPassword "$RE_PASSWORD"

	clear

	dialog --title "Verify Your Responses" \
		--yesno "Please verify your answers to continue setup:

Using Domain : ${UsingDomain}
Using Sub-Domain : ${UsingSubDomain}
Domain Name      : ${DomainName}
Stratum URL      : ${StratumURL}
Install SSL      : ${InstallSSL}
System Email     : ${SupportEmail}
Admin Location   : ${AdminPanel}
Dedicated Coin Ports : ${CoinPort}
AutoExchange : ${AutoExchange}
Your Public IP   : ${PublicIP}" 16 60

	# Get exit status
	# 0 means user hit [yes] button.
	# 1 means user hit [no] button.
	# 255 means user hit [Esc] key.
	response=$?
	case $response in
		0)
			break
			;;
		1)
			# Ask all of the questions again.
			clear
			unset UsingDomain UsingSubDomain DomainName StratumURL InstallSSL SupportEmail AdminPanel \
				AutoExchange CoinPort PublicIP DBRootPassword PanelUserDBPassword StratumUserDBPassword
			;;
		*)
			clear
			echo "User canceled installation"
			exit 0
			;;
	esac
done

# To increase security we are now randonly generating the yiimpfrontend DB name, panel, and stratum user names. So each installation is more secure.
# We do it here to save the variables in the global .yiimp.conf file
YiiMPDBName=yiimp$(generate_password 13)
YiiMPPanelName=Panel$(generate_password 13)
StratumDBUser=Stratum$(generate_password 13)
PRIMARY_HOSTNAME=$DomainName

# Unless you do some serious modifications this installer will not work with any other repo of yiimp!
# YIIMP_REPO / YIIMP_BRANCH can be set in the environment to install from a fork.
YiiMPRepo="${YIIMP_REPO:-${MULTIPOOL_GITHUB:-https://github.com/mygiglifeinc-glitch}/yiimp.git}"
if [ -n "${YIIMP_BRANCH:-}" ]; then
	YiiMPBranch=$YIIMP_BRANCH
elif [[ "$CoinPort" == "yes" ]]; then
	YiiMPBranch=multi-port
else
	YiiMPBranch=""
fi

# Save the global options in $STORAGE_ROOT/yiimp/.yiimp.conf so that standalone
# tools know where to look for data. The file contains passwords, so it is only
# readable by the installing user (whose screens and cron jobs source it).
YIIMP_CONF_VARS=(STORAGE_USER STORAGE_ROOT PRIMARY_HOSTNAME
	UsingDomain UsingSubDomain DomainName StratumURL InstallSSL SupportEmail
	AdminPanel PublicIP CoinPort AutoExchange
	YiiMPDBName DBRootPassword YiiMPPanelName PanelUserDBPassword StratumDBUser StratumUserDBPassword
	YiiMPRepo YiiMPBranch PHP_VERSION)
if [[ "$wireguard" == "true" ]]; then
	YIIMP_CONF_VARS+=(DBInternalIP)
fi
write_conf_file "$STORAGE_ROOT/yiimp/.yiimp.conf" "${YIIMP_CONF_VARS[@]}"

cd "$HOME/multipool/yiimp_single" || exit 1
