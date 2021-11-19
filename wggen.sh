#!/bin/bash
IFS=$'\n'
if [[ $EUID -ne 0 ]]; then
	printf 'Not root! Rerunning with sudo!\n'
	exec sudo /bin/bash "$0" "$@"
	exit 0
fi
err() {
	[ -n "$1" ] && printf -- "$1\n" 1>&2 && return 0
	return 1
}
errout() {
	err "$1"
	exit 1
}
apperr() {
	errout 'Requisite $1 app not available! Exiting!'
}
appexist() {
	command -v $1 > /dev/null && return 0
	return 1
}
nonempty() {
	unset ${1}
	while [ -z "${!1}" ]; do
		printf "\n$2: "
		read ${1}
	done
}
help() {
	printf "\n\nUsage: $0 <command> [OPTIONS]

	<command> - Valid [OPTIONS] will be requested if not provided.
		int - Create new VPN server/interface.
		new - Creates client, provides client config file, and updates VPN.
		rep - Replaces client name and/or keys, provides client config file, and updates VPN.
		rem - Removes client and updates VPN.

	[OPTIONS] - Optionals must be provided in this order including all priors where <command> matches.
		<command> = int|new|rep|rem
			<interface> - /etc/wireguard/<interface>.conf will be used or created
			<client> - Client name. ''=blank

		<command> = int|new|rep
			<file or display> - file=client config will output to /etc/wireguard/* file
					    display=client config file will be displayed

		<command> = int
			<type> - 1=pass all trafic
			         2=remote LAN and VPN network access
			         3=VPN network access only
			<endpoint FQDN/IP> - Where clients attempt to connect to.
			<endpoint port> - Server listen port where clients attempt to connect to.
			<endpoint use VPN IP> - n=VPN network overlaps LAN where server has IP, or access not desired
						y=server uses a LAN IP in VPN netework, VPN may overlap with LAN(s)
			<endpoint VPN IP> - Can overlap LAN(s), also used as network range end even if VPN IP not used.
			<first client IP> - VPN network IP, or ''=blank to ascend and wrap from endpoint VPN IP. Used as network range begin.

		<command> = rep
			<change client name> - Modify <client> name to <change client name>.\n\n\n"
}
! [[ "$1" =~ ^(new|rem|rep|int)$ ]] && help && exit 1
if [ "$1" = 'int' ]; then
	[ -n "${11}" ] && help && exit 1
elif [ -n "$6" ]; then
	help && exit 1
fi
appexist wg || apperr wg
appexist wg-quick || apperr wg-quick
if appexist qrencode; then
	qr='qrencode -t ANSIUTF8'
	qro=', or scan below code on client'
else
	qr='sleep 0'
	qro=' (install qrencode to display QR code)'
fi
if [ -n "$2" ]; then
	if [ -f /etc/wireguard/"$2".conf ]; then
		if [ "$1" = 'int' ]; then
			err "\nInterface $2 already exists! Can not create!"
		else
			sint="$2"
		fi
	elif [ "$1" = 'int' ]; then
		sint="$2"
	else
		err "\nInterface $2 does not exist!"
	fi
fi
while [ -z "$sint" ]; do
	if [ $(ls /etc/wireguard/*.conf|grep -c '.conf') -ne 0 ]; then
		printf '\nAvailable interfaces:\n'
		for x in $(ls /etc/wireguard/*.conf); do
			x="${x%%.conf}"
			printf "${x##*/}\n"
		done
	fi
	sint=''
	[ "$1" = 'int' ] && sint='\nEnter new' || sint='\nEnter existing'
	sint="$sint interface name (case sensitive)"
	nonempty sint "$sint"
	if [ "$1" = 'int' ]; then
		[ -f /etc/wireguard/"$sint".conf ] && err "\nInterface $sint exists! Can not create!" && unset sint
	elif ! [ -f /etc/wireguard/"$sint".conf ]; then
		err "\nInterface $sint does not exist!" && unset sint
	fi
done
scon="/etc/wireguard/$sint.conf"
if [ "$1" = 'int' ]; then
	clnt="$3"
elif [ -n "$3" ]; then
	if grep -qx "#Client = $3" "$scon"; then
		if [ "$1" = 'new' ]; then
			err "\nClient $3 already exists! Can not create!"
		else
			clnt="$3"
		fi
	elif [ "$1" = 'new' ]; then
		clnt="$3"
	else
		err "\nClient $3 doesn't exist! Can not modify!"
	fi
fi
while [ -z "$clnt" ] || [ $(grep -sqx "#Client = $clnt" "$scon"; echo $?) -ne $([[ "$1" =~ ^(rem|rep)$ ]]; echo $?) ]; do
	[ "$1" = 'int' ] && [ -n "$4" ] && break 1
	if grep -sq "#Client = " "$scon"; then
		printf '\nAvailable clients:\n'
		for x in $(grep '#Client = ' "$scon"); do
			printf "${x###Client = }\n"
		done
	elif [[ "$1" =~ ^(rem|rep)$ ]]; then
		errout 'No clients exist!'
	fi
	[[ "$1" =~ ^(new|int)$ ]] && clnt='\nEnter new' || clnt='\nEnter existing'
	clnt="$clnt client name (case sensitive)"
	[ "$1" = 'int' ] && printf "$clnt or blank to skip: " && read clnt && break 1 || nonempty clnt "$clnt"
done
if [ "$1" = 'int' ]; then
	[ -n "$5" ] && styp="$5" || printf '\nThis script assumes a /24 or 255.255.255.0 network.\n'
	while ! [[ "$styp" =~ ^(1|2|3)$ ]]; do
		nonempty styp 'Enter VPN type (1=pass all traffic, 2=remote LAN and VPN network access, 2=VPN network access only)'
	done
	[ -n "$6" ] && swip="$6" || nonempty swip 'Enter endpoint/server FQDN or IP'
	[ -n "$7" ] && sprt="$7" || nonempty sprt 'Enter endpoint/server listen port'
	send="Endpoint = $swip:$sprt"
	unset swip
	suip="$8"
	while ! [[ "$suip" =~ ^(y|n)$ ]]; do
		nonempty suip 'Should VPN server use a LAN IP (y/n)'
	done
	[ -n "$9" ] && sip="$9" || nonempty sip 'Enter server VPN IP (IP range end, first client is begin, range wraps at .255)'
	sip="$sip/24"
	spri="$(wg genkey)"
else
	styp="$(grep -i '#Type = ' "$scon")"
	styp="${styp###Type = }"
	[ -z "$styp" ] && errout 'No type found! Corrupt file!'
	sdns="$(grep -i '#DNS = ' "$scon")"
	sdns="${sdns###}"
	send="$(grep -i '#Endpoint = ' "$scon")"
	send="${send###}"
	[ -z "$send" ] && errout 'No endpoint found! Corrupt file!'
	sprt="${send#*:}"
	sip="$(grep -i 'Address = ' "$scon")"
	sip="${sip###}"
	sip="${sip##Address = }"
	spri="$(grep -i 'PrivateKey = ' "$scon")"
	spri="${spri##PrivateKey = }"
	[ -z "$spri" ] && errout 'Bad or missing private key! Corrupt file!'
fi
smsk="/${sip#*/}"
sip="${sip%/*}"
seip="${sip##*.}"
sip="${sip%.*}."
if [ $styp -ne 3 ]; then
	aint="$(ip r|grep -w default)"
	aint="${aint/*dev }"
	aint="${aint/ *}"
	aip="$(ip a show $aint|grep -w inet)"
	aip="${aip/*inet }"
	aip="${aip%% *}"
	amsk="/${aip#*/}"
fi
[ -z "$sip" ] || [ -z "$seip" ] || [ -z "$smsk" ] && errout 'Could not determine server LAN IP! Corrupt file!'
spub="$(wg pubkey<<<$spri)"
[ -z "$spub" ] && errout 'Bad or missing server public key! Corrupt file!'
if [ "$1" = 'int' ]; then
	if [ -n "$clnt" ]; then
		if [ -n "$9" ]; then
			cip="${10}"
		else
			printf '\nEnter client VPN IP (blank ascends and wraps from server LAN IP): '
			read cip
		fi
		cip="${cip##*.}"
		if [ -z "$cip" ] || [ "$sip$seip" = "$cip" ]; then
			if [ "$suip" = 'n' ]; then
				cip="$seip"
			else
				cip=$(($seip + 1))
				[ $cip -gt 254 ] && cip=1
			fi
		fi
	fi
elif [ "$1" = 'new' ]; then
	if [ -f "$scon" ]; then
		cip="$(grep -m1 'AllowedIPs = ' "$scon")"
		cip="${cip##AllowedIPs = }"
	else
		cip="$sip$seip$smsk"
	fi
	cip="${cip%/*}"
	cip="${cip##*.}"
	if [ -f "$scon" ]; then
		while grep -v '#Address = ' "$scon"|grep -q "$sip$cip"; do
			cip=$((cip + 1))
			[ $cip -eq 255 ] && cip=1
			[ "$seip" = "$cip" ] && errout 'Could not determine good ip!'
		done
	fi
elif [ "$1" = 'rep' ]; then
	cip=$(grep -x -A4 "#Client = $clnt" "$scon"|grep 'AllowedIPs = ')
	cip="${cip##AllowedIPs = }"
	cip="${cip%/*}"
	cip="${cip##*.}"
	if [ -n "$4" ]; then
		nclt="$5"
		grep -xsq "#Client = $nclt" "$scon" && err 'New client name exists!' && nclt="$clnt"
	fi
	while grep -qsx "#Client = $nclt" "$scon"; do
		printf '\nEnter new client name (case sensitive) or blank to regenerate keys only: '
		read nclt
	done
	[ -z "$nclt" ] && nclt="$clnt"
fi
if [ "$1" != 'rem' ] && [ -n "$clnt" ]; then
	cpri="$(wg genkey)"
	cpub="$(wg pubkey<<<$cpri)"
	cpsk="$(wg genpsk)"
	cip="$sip$cip"
	case $styp in
		1) caip='0.0.0.0/0';;
		2) caip="${aip%.*}"'.0'"$amsk";;
		3) caip="$sip"'0'"$smsk";;
	esac
	sccnf=("#Client = $clnt" '[Peer]' "PublicKey = $cpub" "PresharedKey = $cpsk" "AllowedIPs = $cip/32" ' ')
	ccnf="[Interface]
PrivateKey = $cpri
Address = $cip$smsk
$sdns

[Peer]
PublicKey = $spub
PresharedKey = $cpsk
AllowedIPs = $caip
$send
PersistentKeepalive = 25\n"
	ccon="/etc/wireguard/$sint/$sint-$clnt.conf"
	if [ -n "$nclt" ]; then
		sccnf[0]="#Client = $nclt"
		ccon="/etc/wireguard/$sint/$sint-$nclt.conf"
	fi
	[ -n "$4" ] && cfle="$4" || nonempty cfle 'How to present client configuration (file/display)'
	if [ "$cfle" = 'file' ]; then
		! [ -d "/etc/wireguard/$sint" ] && mkdir "/etc/wireguard/$sint"
		printf -- "${ccnf}" > "$ccon"
		printf "\n\nClient config file is $ccon"
	else
		printf "\n\n#Copy below to client Wireguard $sint.conf file$qro:\n"
		printf -- "${ccnf}"|tee /dev/tty|eval "$qr"
	fi
	printf '\n\n\n'
fi
if [ "$1" = 'int' ]; then
	sip="Address = $sip$seip$smsk"
	[ "$suip" = 'n' ] && sip="#$sip"
	scnf=("[Interface]" "PrivateKey = $spri" "ListenPort = $sprt" "$sip" "#$send" "#Type = $styp")
else
	 scnf=($(<"${scon}"))
fi
if [[ "$1" =~ ^(int|new)$ ]]; then
	[ ${#sccnf[@]} -gt 0 ] && scnf=("${scnf[@]}" "${sccnf[@]}")
	for x in "${!scnf[@]}"; do
		sncnf="$sncnf${scnf[$x]}\n"
	done
else
	y=false
	for x in "${!scnf[@]}"; do
		$y && [[ "${scnf[$x]}" == '#Client = '* ]] && y=false
		[ "${scnf[$x]}" = "#Client = $clnt" ] && y=true
		if $y; then
			if [ "$1" = 'rep' ]; then
				scnf[$x]="$sccnf"
				sccnf=("${sccnf[@]:1}")
			else
				continue 1
			fi
		fi
		sncnf="$sncnf${scnf[$x]}\n"
	done
fi
printf -- "${sncnf}" > "$scon"
if [ "$1" = 'int' ]; then
	echo "1" > /proc/sys/net/ipv4/ip_forward
	sysctl net.ipv4.ip_forward=1
	systemctl enable wg-quick@"$sint".service
	systemctl daemon-reload
	systemctl start wg-quick@"$sint"
sleep 0.1
else
	[ -z "$3" ] && read -n 1 -s -r -p '
Press any key to exit and load changes. VPN connections briefly disconnect.
ctrl+c to cancel change load (changes load at next change load):
'
	systemctl restart wg-quick@"$sint"
fi
unset IFS
