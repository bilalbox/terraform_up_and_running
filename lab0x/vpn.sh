iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p tcp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -t nat -A POSTROUTING -s "${local_subnet}" -d "${remote_subnet}" -j SNAT --to "${remote_ipv4_pub}"

cat <<EOF > /etc/ipsec.conf
conn svc_vpc_2_sub_vpc
type=tunnel
authby=secret
left="${local_ipv4_priv}"
leftid="${local_ipv4_pub}"
leftnexthop=%defaultroute
leftsubnet="${local_subnet}"
right="${remote_ipv4_pub}"
rightnexthop=%defaultroute
rightsubnet="${remote_subnet}"
phase2=esp
phase2alg=aes128-sha1
ike=aes128-sha1
ikelifetime=28800s
salifetime=3600s
pfs=yes
auto=start
rekey=yes
keyingtries=%forever
dpddelay=10
dpdtimeout=60
dpdaction=restart_by_peer
EOF

cat <<EOF > /etc/ipsec.secrets
"${local_ipv4_pub}"  "${remote_ipv4_pub}":  PSK  "${vpn_psk}"
EOF

/etc/init.d/ipsec restart
