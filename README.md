# GenerateWireguard
Make VPNs easy! Easy Wireguard server setup and configuration management script for typical home use case. Makes backup, restore, and migration of a Wireguard VPN server easy.

## Pre-requisites:
Both of these probably came with your distro, check with `which wg` and `which sed`.
- [wireguard](https://github.com/WireGuard/)
- [sed](https://github.com/mirror/sed/) (Most variants of `sed` will do. Make ABSOLUTELY sure you edit this script file's variables pre-run if you do not have `sed`)


## How-To:
***I will not be going over how to configure your network or system to reach the Wireguard VPN server outside saying that the server's endpoint port must be accessible to devices attempting to connect, you may have to enable forwarding, and you may have to add routes!***

Download a copy of the script. Run the script. Read the output. Adjust the variables in the begining of the script with your favorite editor if it suites you (listed below). Run the script with a valid hostname/username input and it will "move" (copy itself with updated information) to `/etc/wireguard/INTERFACE/generatewg_INTERFACE` and then output the contents of a file you can give to a Wireguard client to connect. To start the VPN interface run `/etc/wireguard/INTERFACE/generatewg_INTERFACE INTERFACE`. Each copy of the script is meant to handle it's own interface. If you want to backup or move your VPN server merely copy the specific `/etc/wireguard/INTERFACE` directory to a storage location, move it back to the original location on the new system, and run the script with valid input to restore.
```
Edit variables in begining of script before running!

Usage:
/path/to/script/generatewg_ <REQUIRED> <OPTION> <LIVE>

REQUIRED:
		- A hostname or username of the Wireguard interface this script controls.
		  Provides details (config file) for hostname or username. Creates a peer if new.
		  If Wireguard interface name provided script will stand up or restart the interface with no routes.

OPTION:
	new	- Generate a new private and public key for specified hostname or username and display.
	OR
	remove	- Remove peer with specified hostname or username.

LIVE:
	live	- If provided will update the Wireguard interface with new or removed peer information.
		  Config files are otherwise generated for next interface start.
```
The variables that need to be adjusted.
```
#what VPN clients connect to
#if left blank this will attempt to determine WAN IP and changes all client config files
ENDPOINT_HOSTNAME_OR_WANIP=''
#if left blank uses default port of 51820
ENDPOINT_PORT=''

#name of the local Wireguard interface this script controls, and associated interface network details
#if left blank lowest numbered default selected (wg0 - wg100)
WG_INTERFACE_NAME=''
#handles only single subnet, typical 254 address LAN setup, otherwise can't really halp u :)
#DO NOT LEAVE BLANK
WG_NETWORK='10.10.10.0/24'
WG_ADDRESS_RANGE_BEG='2'
WG_ADDRESS_RANGE_END='253'
```
You can see a general layout after creating a few peers.
```
/etc/wireguard
|-- wg0
|   |-- generatewg_wg0
|   |-- test
|   |   |-- address
|   |   |-- privatekey
|   |   |-- publickey
|   |   `-- test.conf
|   |-- test2
|   |   |-- address
|   |   |-- privatekey
|   |   |-- publickey
|   |   `-- test2.conf
|   |-- test3
|   |   |-- address
|   |   |-- privatekey
|   |   |-- publickey
|   |   `-- test3.conf
|   `-- test4
|       |-- address
|       |-- privatekey
|       |-- publickey
|       `-- test4.conf
`-- wg0.conf
```

## Why do this?
A VPN can seem a daunting task. Even with how simple Wireguard is there are a lot of questions to ask regarding setup. After not properly documenting a home lab setup I decided to write a script that would manage all the setup and configuration files for a Wireguard VPN that I wanted to keep around. My premise during writing this was to create an easily deployable, and easily backed up system to ease in any future migrations I go through. Thanks to the flexibility and simplicity offered by Wireguard this was not a terribly challenging feat.

## To-Do:
1. Add script function to list all hostnames/usernames/peers
2. Add some basic implimentation of ip forwarding and possibly associated routes if wg-quick doesn't already do what I'm hoping
