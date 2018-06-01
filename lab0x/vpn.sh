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

conn vpc1
        type=tunnel
        compress=no
        keyexchange=ikev1
        ike=aes128-sha1-modp1024!
        auth=esp
        authby=psk
        left=54.241.138.199 
        leftid=54.241.138.199 
        leftsubnet=169.254.254.6/32,10.2.0.0/16
        rightsubnet=169.254.254.5/32,10.4.0.0/16
        right=87.238.85.44
        rightid=87.238.85.44
        esp=aes128-sha1-modp1024!
        auto=route