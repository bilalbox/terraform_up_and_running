#!/bin/bash
export HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
export PRIVATE_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo Host: $HOSTNAME, IP Address: $PRIVATE_IPV4 > index.html
nohup busybox httpd -f -p "${server_port}" &
