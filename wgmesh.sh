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
isnum() {
	[ -z "$1" ] || ! [[ $1 =~ ^[0-9]+$ ]] && return 1
	return 0
}
isip() {
	[ -z "$1" ] || [[ ! $1 =~ ^[0-9/.]+$ ]] && return 1
	local a1 a2 a3 a4 v
	a4="$1"
	a1=${a4//.}
	[ $((${#a4} - ${#a1})) -ne 3 ] && return 1
	for y in {1..4}; do
		declare a$y="${a4%%.*}"
		v="a$y"
		[ -z "${!v}" ] || [ ${!v} -gt 255 ] && return 1
		a4="${a4#*.}"
	done
	return 0
}
iscidr() {
	[ -z "$1" ] || [[ ! $1 =~ ^[0-9/./\/]+$ ]] || ! isip "${1%/*}" && return 1
	local m1
	m1="${1#*/}"
	[ -z "$m1" ] || ! isnum "$m1" || [ $m1 -lt 8 ] || [ $m1 -gt 32 ] && return 1
	return 0
}
cidrtomask() {
	[ -z "$1" ] || [[ ! $1 =~ ^[0-9]+$ ]] || [ $1 -lt 8 ] || [ $1 -gt 32 ] && errout "CIDR bit length not provided to cidrtomask function (expected 8-32, got '$1')!"
	local i mask full part
	full=$(($1/8))
	part=$(($1%8))
	for ((i=0;i<4;i+=1)); do
		if [ $i -lt $full ]; then
			mask+=255
		elif [ $i -eq $full ]; then
			mask+=$((256 - 2**(8-$part)))
		else
			mask+=0
		fi
		test $i -lt 3 && mask+=.
	done
	printf "$mask"
	return 0
}
networkmin() {
	 [ -z $1 ] || ! iscidr "$1" && errout 'CIDR address not provided to networkmin function!'
	local a1 a2 a3 a4 m1 m2 m3 m4
	IFS=. read -r a1 a2 a3 a4<<<"${1%/*}"
	IFS=. read -r m1 m2 m3 m4<<<"$(cidrtomask ${1#*/})"
	a1=$((a1 & m1))
	a2=$((a2 & m2))
	a3=$((a3 & m3))
	a4=$((a4 & m4))
	printf "$a1.$a2.$a3.$a4"
	return 0
}
networkmax() {
	[ -z $1 ] || ! iscidr "$1" && errout 'CIDR address not provided to networkmax function!'
	local a1 a2 a3 a4 m1 m2 m3 m4
	IFS=. read -r a1 a2 a3 a4<<<"${1%/*}"
	IFS=. read -r m1 m2 m3 m4<<<"$(cidrtomask ${1#*/})"
	a1=$((( 255 ^ m1 ) | a1 ))
	a2=$((( 255 ^ m2 ) | a2 ))
	a3=$((( 255 ^ m3 ) | a3 ))
	a4=$((( 255 ^ m4 ) | a4 ))
	printf "$a1.$a2.$a3.$a4"
	return 0
}
inntwrk() {
	[ -z "$1" ] || ! isip "$1" && return 1
	[ -z "$2" ] || ! iscidr "$2" && return 1
	[ "$(networkmin $1/${2#*/})" != "$(networkmin $2)" ] && return 1
	return 0
}
getpriorhost() {
	[ -z $1 ] || ! iscidr "$1" && errout "CIDR address not provided to getpriorhost function!"
	local a1 a2 a3 a4 a5 m1 m2 m3 m4 i1 i2 i3 i4 address
	IFS=. read -r a1 a2 a3 a4<<<"${1%/*}"
	a5="${1#*/}"
	IFS=. read -r m1 m2 m3 m4<<<"$(cidrtomask $a5)"
	i1=$((255 ^ m1))
	i2=$((255 ^ m2))
	i3=$((255 ^ m3))
	i4=$((255 ^ m4))
	address=$((((((((a1 << 8) | a2) << 8) | a3) << 8) | a4) - 1))
	a4=$((((255 & address) & i4) | (a4 & m4)))
	address=$((address >> 8))
	a3=$((((255 & address) & i3) | (a3 & m3)))
	address=$((address >> 8))
	a2=$((((255 & address) & i2) | (a2 & m2)))
	a1=$((((address >> 8) & i1) | (a1 & m1)))
	address="$a1.$a2.$a3.$a4"
	[ "$address" = '0.0.0.0' ] || [ "$address" = '255.255.255.255' ] || [ "$address" = "$(networkmin $address/$a5)" ] || [ "$address" = "$(networkmax $address/$a5)" ] && address="$(getpriorhost $address/$a5)"
	printf "$address"
	return 0
}
getnexthost() {
	[ -z $1 ] || ! iscidr "$1" && errout "CIDR address not provided to getnexthost function!"
	local a1 a2 a3 a4 a5 m1 m2 m3 m4 i1 i2 i3 i4 address
	IFS=. read -r a1 a2 a3 a4<<<"${1%/*}"
	a5="${1#*/}"
	IFS=. read -r m1 m2 m3 m4<<<"$(cidrtomask $a5)"
	i1=$((255 ^ m1))
	i2=$((255 ^ m2))
	i3=$((255 ^ m3))
	i4=$((255 ^ m4))
	address=$((((((((a1 << 8) | a2) << 8) | a3) << 8) | a4) + 1))
	a4=$((((255 & address) & i4) | (a4 & m4)))
	address=$((address >> 8))
	a3=$((((255 & address) & i3) | (a3 & m3)))
	address=$((address >> 8))
	a2=$((((255 & address) & i2) | (a2 & m2)))
	a1=$((((address >> 8) & i1) | (a1 & m1)))
	address="$a1.$a2.$a3.$a4"
	[ "$address" = '0.0.0.0' ] || [ "$address" = '255.255.255.255' ] || [ "$address" = "$(networkmin $address/$a5)" ] || [ "$address" = "$(networkmax $address/$a5)" ] && address="$(getnexthost $address/$a5)"
	printf "$address"
	return 0
}
intname="$1"
while [ -z "$intname" ]; do
	err 'Provide arg 1. Wireguard interface name: '
	read intname
	if ! [ -f "/etc/wireguard/wgmesh_${intname}/wgmesh_${intname}_1.conf" ]; then
		printf "Create new interface 'wgmesh_${1}_1' (Y/n)?: "
		read ans
		[ "$ans" = "n" ] || [ "$ans" = "N" ] || [ "$ans" = "no" ] || [ "$ans" = "NO" ] || [ "$ans" = "nO" ] || [ "$ans" = "No" ] && continue 1
	fi
done
wgmeshexists=false
if [ -d "/etc/wireguard/wgmesh_${intname}/" ]; then
	for file in $(find "/etc/wireguard/wgmesh_${intname}/" -type f -wholename "/etc/wireguard/wgmesh_${intname}/wgmesh_${intname}_*.conf"); do
		wgmeshexists=true
		peer="${file##*_}"
		peer="${peer%.*}"
		wgmeshfile[$peer]="$file"
		wgmesh[$peer]="$(grep -v -e '^[[:space:]]*$' \"${wgmeshfile[$peer]}\")"
		wgmeshpri[$peer]="$(grep -m1 'PrivateKey = ' <<<\"${wgmesh[$peer]}\")"
		wgmeshpri[$peer]="${wgmeshpri[$peer]#PrivateKey = }"
		wgmeshpub[$peer]="$(wg pubkey<<<${wgmeshpri[$peer]})"
		wgmeship[$peer]="$(grep -m1 'Address = ' <<<\"${wgmesh[$peer]}\")"
		wgmeship[$peer]="${wgmeship[$peer]#Address = }"
		[ -z "$wgmeshmask" ] && $wgmeshmask=$(networkmin ${wgmeship[$peer]})
		wgmeship[$peer]="${wgmeship[$peer]%/*}"
		wgmeshendip[$peer]="$(grep -m1 '#Endpoint = ' <<<\"${wgmesh[$peer]}\")"
		if [ -z "${wgmeshendip[$peer]}" ]; then
			wgmeshendport[$peer]="${wgmeshendip[$peer]#*:}"
			wgmeshendip[$peer]="${wgmeshendip[$peer]#\#Endpoint = }"
			wgmeshendip[$peer]=${wgmeshendip[$peer]%:*}
		else
			unset wgmeshendip[$peer] wgmeshendport[$peer]
		fi
		while read -d^ -r meshpeer; do
			peerpeer="$(grep -m1 '#Client = ' <<<\"$meshpeer\")"
			peerpeer="${meshpeer##*_}"
			if [ -z "${wgmeshpub[$peerpeer]}" ]; then
				wgmeshpub[$peerpeer]="$(grep -m1 'PublicKey = ' <<<\"$meshpeer\")"
				wgmeshpub[$peerpeer]="${wgmeshpub[$peerpeer]#PublicKey = }"
			fi
			if [ -z "${wgmeshpre[$peer,$peerpeer]}" ]; then
				wgmeshpre[$peer,$peerpeer]="$(grep -m1 'PresharedKey = ' <<<\"$meshpeer\")"
				wgmeshpre[$peer,$peerpeer]="${wgmeshpre[$peer,$peerpeer]#PresharedKey = }"
				wgmeshpre[$peerpeer,$peer]="${wgmeshpre[$peer,$peerpeer]}"
			fi
			if [ -z "${wgmeship[$peerpeer]}" ]; then
				wgmeship[$peerpeer]="$(grep -m1 'AllowedIPs = ' <<<\"$meshpeer\")"
				wgmeship[$peerpeer]="${wgmeship[$peerpeer]%/*}"
			fi
			if [ -z "${wgmeshendip[$peerpeer]}" ]; then
				wgmeshendip[$peerpeer]="$(grep -m1 'Endpoint = ' <<<\"$meshpeer\")"
				wgmeshendip[$peerpeer]="${wgmeshendip[$peerpeer]#Endpoint = }"
				wgmeshendport[$peerpeer]="${wgmeshendip[$peerpeer]#*:}"
				wgmeshendip[$peerpeer]=${wgmeshendip[$peerpeer]%:*}
			fi
		done < <(grep --group-separator=^ -A5 "#Client = ${intname}_" <<<\"${wgmesh[$peer]}\")
	done
fi
while [ -z "$wgmeshmask" ]; do
	if isnum $2 && iscidr $3; then
		peer="$3"
	else
		printf -- 'Provide valid RFC1918 IPv4 network or first host in CIDR format (?.?.?.?/?): '
		read peer
		iscidr $peer || unset wgmeshmask && continue 1
	fi
	wgmeshmask="${peer#*/}"
	[ $wgmeshmask -gt 30 ] && unset wgmeshmask && continue 1
	[ -z "${wgmeship[0]}" ] && wgmeship[0]="${peer%/*}"
	inntwrk ${wgmeship[0]} '10.0.0.0/8' || inntwrk ${wgmeship[0]} '172.16.0.0/12' || inntwrk ${wgmeship[0]} '192.168.0.0/16' || unset wgmeshmask && continue 1
	wgmeshnet="$(networkmin $peer)"
	[ "$wgmeshnet" = "${wgmeship[0]}" ] || [ "$(networkmax $peer)" = "${wgmeship[0]}" ] && wgmeship[0]="$(getnexthost $peer)"
done
wgmeshpeermax=$((2 - (2** (32 - wgmeshmask))))
if $wgmeshexists; then
		peer=("${!wgmeshfile[@]}")
		wgmeshlast=${peer[-1]}
		wgmeshfirst=${peer[1]}
fi
if [ "$(find /etc/wireguard/ -type f -wholename "/etc/wireguard/wgmesh_${intname}_*.conf"|wc -l)" -eq 1 ]; then
	currentpeer=$(find /etc/wireguard/ -type f -wholename "/etc/wireguard/wgmesh_${intname}_*.conf")
	currentpeer="${currentpeer##*_}"
	currentpeer="${currentpeer%.*}"
fi
func="$2"
isnum $func && [ $func -gt $wgmeshpeermax ] && unset func
while [ "$func" != 'rem' ] && [ "$func" != 'rep' ] && [ "$func" != 'end' ] && ! isnum $func; do
	err "Provide arg 2. Must be mesh peer total (max=$wgmeshpeermax, min=2), 'end' to replace a peer endpoint, 'rep' to replace a peer keyset, or 'rem' to remove a peer: "
	read func
	if isnum $func; then
		[ $func -lt 2 ] || [ $func -gt $wgmeshpeermax ] && unset func
	fi
done
peernum="$3"
if ! isnum $func; then
	[ "$func" = 'end' ] && rebuildmesh="$5" || rebuildmesh="$4"
	while ! isnum $peernum || ! [ -f "/etc/wireguard/wgmesh_${intname}/wgmesh_${intname}_${peernum}.conf" ]; do
		#provide existing peer numbers
		err "Provide arg 3, while arg 2 is 'end'/'rep'/'rem' this must be valid existing peer number from above to to remove: "
		read peernum
	done
fi
if isnum $func; then
	rebuildmesh="$3"
	printf -- "Generating all empty peers up to requested peer ($func)!\n"
	if [ -n "$wgmeshfirst" ] && [ $wgmeshfirst -ne 0 ]; then
		#if total IP info not available, regenerate from first known peer
		unset wgmeshtmp
		while ((peer=(wgmeshfirst-1); peer>=0; --peer)); do
			if [ -z "${wgmeship[$peer]}" ]; then
				if [ -z "$wgmeshtmp" ] && [ -z "${wgmeship[$peer+1]}" ]; then
					if [ "${#wgmeship[@]}" -ne 0 ]; then
						#if disjointed IP info, rebuild lower peer numbers from first known
						for peerpeer in "${!wgmeship[@]}"; do
							wgmeshtmp=$peerpeer && break 1
						done
						while ((peerpeer=(wgmeshtmp-1); peerpeer>peer; --peerpeer)); do
							wgmeship[$peerpeer]=$(getpriorhost ${wgmeship[$peerpeer+1]}'/'$wgmeshmask])
						done
					else
						break 1
					fi
				else
					wgmeship[$peer]=$(getpriorhost ${wgmeship[$peer+1]}'/'$wgmeshmask])
				fi
			fi
		done
	fi
	for ((peer=0; peer!=func; ++peer)); do
		[ -z "${wgmeshpri[$peer]}" ] && [ -z "${wgmeshpub[$peer]}" ] && wgmeshpri[$peer]="$(wg genkey)"
		[ -z "${wgmeshpub[$peer]}" ] && wgmeshpub[$peer]="$(wg pubkey<<<${wgmeshpri[$peer]})"
		[ -z "${wgmeship[$peer]}" ] && wgmeship[$peer]=$(getnexthost ${wgmeship[peer-1]})
		if [ -z "${wgmeshendip[$peer]}" ]; then
			err "Provide peer number $peer endpoint (blank for dynamic [hub and spoke relay peer 0]): "
			read wgmeshendip[$peer]
			wgmeshendport[$peer]="${wgmeshendip[$peer]#*:}"
			wgmeshendip[$peer]=${wgmeshendip[$peer]%:*}
		fi
		for ((peerpeer=peer+1; peerpeer!=func; ++peerpeer)); do
			if [ -z "${wgmeshpre[$peer,$peerpeer]}" ]; then
				wgmeshpre[$peer,$peerpeer]="$(wg genpsk)"
				wgmeshpre[$peerpeer,$peer]="${wgmeshpre[$peer,$peerpeer]}"
			fi
		done
	done
else
	if [ "$func" = 'end' ]; then
		printf -- "Provide peer number $peernum endpoint (blank for dynamic [hub and spoke relay peer 0]): "
		read wgmeshendip[$peernum]
		wgmeshendport[$peernum]="${wgmeshendip[$peernum]#*:}"
		wgmeshendip[$peernum]=${wgmeshendip[$peernum]%:*}
	elif [ "$func" = 'rep' ]; then
		wgmeshpri[$peernum]="$(wg genkey)"
		wgmeshpub[$peernum]="$(wg pubkey<<<${wgmeshpri[$peernum]})"
	elif [ "$func" = 'rem' ]; then
		if [ -n "$currentpeer" ] && [ $currentpeer -eq $peernum ]; then
			err 'Requested removal of self! Are you sure? [y/N]: '
			read wgmeshtmp
			[ "$wgmeshtmp" != 'y' ] && errout 'Exiting!'
		fi
		unset wgmesh[$peernum] wgmeshfile[$peernum] wgmeshpri[$peernum] wgmeshpub[$peernum] wgmeshendip[$peernum] wgmeshendport[$peernum]
	fi
	printf -- "Action '$func' taken on peer number $peernum...\n"
fi
[ "$rebuildmesh" = 'rebuild' ] && rebuildmesh=true
[ "$rebuildmesh" = 'norebuild' ] && rebuildmesh=false
rebuildmeshcount=0
for peer in "${!wgmeshpub[@]}"; do
	if [ -z "${wgmeshpri[$peer]}" ]; then
		if [ -z "$rebuildmesh" ]; then
			err 'Regenerate peers with unknown private keys? This will disconnect all of this type! [N/y]: '
			read rebuildmesh
			[ "$rebuildmesh" != 'y' ] && [ "$rebuildmesh" != 'Y' ] && rebuildmesh=false || rebuildmesh=true
		fi
		if [ -z "${wgmeshpri[$peer]}" ]; then
			$rebuildmesh && wgmeshpri[$peer]="$(wg genkey)" && wgmeshpub[$peer]="$(wg pubkey<<<${wgmeshpri[$peer]})"
			rebuildmeshpeers="$rebuildmeshpeers $peer"
			rebuildmeshcount=$((rebuildmeshcount+1))
		fi
	fi
done
if [ $rebuildmeshcount -ne 0 ]; then
	peer="$rebuildmeshcount peers have no private key! Peer numbers:$rebuildmeshpeers"
	$rebuildmesh && printf -- "$peer\n" || err "$peer"
fi
printf -- "Writing new peer files...\n"
for peer in "${!wgmeshpri[@]}"; do
	[ -z "${wgmeshfile[$peer]}" ] && wgmeshfile[$peer]="/etc/wireguard/wgmesh_${intname}/wgmesh_${intname}_$peer.conf"
	wgmesh[$peer]="[Interface]\nPrivateKey = ${wgmeshpri[$peer]}\nListenPort = ${wgmeshendport[$peer]}\nAddress = ${wgmeshpri[$peer]}\n#Endpoint = ${wgmeshendip[$peer]}:${wgmeshendport[$peer]}\n\n"
	for peerpeer in "${!wgmeshpub[@]}"; do
		[ $peer -eq $peerpeer ] && continue 1
		[ $peer -ne 0 ] && [ -z "${wgmeshendip[$peerpeer]}" ] && continue 1
		[ $peerpeer -eq 0 ] && wgmeshtmp="$wgmeshnet/$wgmeshmask" || wgmeshtmp="${wgmeship[$peer]}/32"
		wgmesh[$peer]="${wgmesh[$peer]}#Client = $intname_$peerpeer\n[Peer]\nPublicKey = ${wgmeshpub[$peerpeer]}\nPresharedKey = ${wgmeshpre[$peer,$peerpeer]}\nAllowedIPs = $wgmeshtmp\n"
		wgmeshtmp="\n"
		if [ -n "${wgmeshendip[$peerpeer]}" ]; then
			[ -z "${wgmeshendport[$peerpeer]}" ] && wgmeshendport[$peerpeer]=51820
			wgmeshtmp="Endpoint = ${wgmeshendip[$peerpeer]}:${wgmeshendport[$peerpeer]}\n$wgmeshtmp"
		fi
		wgmesh[$peer]="${wgmesh[$peer]}$wgmeshtmp"
	done
done
[ -n "$currentpeer" ] && cp ${wgmeshfile[$currentpeer]} "/etc/wireguard/wgmesh_${intname}_$peer.conf"
if ip a show "$sint"|grep -q 'does not exist'; then
	err "Interface $sint is not up! Cannot load changes!"
else
	wg syncconf "$sint" <(wg-quick strip "$scon")
fi
unset IFS
exit 0
