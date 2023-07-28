This new mesh Wireguard peer generation [script](https://github.com/danvandermeir/GenerateWireguard/blob/main/wgmesh.sh) will be enveloped into the larger more rubust script when completed. It is a major step forward. It can also be used in the same fashion as the immediately below script for typical hub and spoke style VPN connections. It tries to preserve hub bandwidth and reduce latency with direct VPN connections to each peer. Typical usage as hosting any server software applies for "meshing" peers. Each peer needs a known working DNS name or IP, and a port forward if the peer is not running on the internet "directly" such as a 1:1 NAT. Rebuilding "broken" mesh networks should be handled with care, the script does it's best but manual editing might be best if the network being repaired is required to update said peers of changes. Such as if information is lost on peer 0 (always considered the hub) and all the other peers are periodically checking in with peer 0 over SSH for updates to the peer lists.
```
Use options:
New interface or add peers: <INTNAME> <#OFPEERS> <CIDR>
Remove peer: <INTNAME> rem <PEER#> (opt)rebuild/norebuild
Replace keys: <INTNAME> rep <PEER#> (opt)rebuild/norebuild
Replace endpoint:  <INTNAME> end <PEER#> <ENDPOINT> (opt)rebuild/norebuild
```
You will be asked for unprovided or seemingly incorrect required information. Files are dropped into a subfolder under /etc/wireguard/


For the time being you can use [this script](https://github.com/danvandermeir/GenerateWireguard/blob/main/wggen.sh) to impliment and manage clients of a Wireguard VPN server via CLI while I finish the far more robust version of the script. I took a dive into 2FA with Wireguard, and I'll be adding that in.
```
Usage: ./wggen.sh <command> [OPTIONS]

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
                        <change client name> - Modify <client> name to <change client name>.
```
