#!/bin/bash

# === USAGE ===
# ./install-openvpn-server.sh <vpn-port> <proto> <vpn-subnet> <vpn-mask> <server-name> <easyrsa-dir> <ccd-dir>

set -e

PORT="$1"
PROTO="$2"
VPN_SUBNET="$3"
VPN_MASK="$4"
SERVER_NAME="$5"
EASYRSA_DIR="$6"
CCD_DIR="$7"
SERVER_CONF="/etc/openvpn/server.conf"

if [[ -z "$PORT" || -z "$PROTO" || -z "$VPN_SUBNET" || -z "$VPN_MASK" || -z "$SERVER_NAME" || -z "$EASYRSA_DIR" || -z "$CCD_DIR" ]]; then
  echo "Usage: $0 <vpn-port> <proto> <vpn-subnet> <vpn-mask> <server-name> <easyrsa-dir> <ccd-dir>"
  exit 1
fi

echo "[+] Installing OpenVPN and Easy-RSA..."
sudo apt update
sudo apt install openvpn easy-rsa -y

echo "[+] Setting up Easy-RSA in $EASYRSA_DIR..."
make-cadir "$EASYRSA_DIR"
cd "$EASYRSA_DIR"
./easyrsa init-pki
echo -ne "\n" | ./easyrsa build-ca nopass
./easyrsa gen-req "$SERVER_NAME" nopass
echo yes | ./easyrsa sign-req server "$SERVER_NAME"
./easyrsa gen-dh
openvpn --genkey --secret ta.key

echo "[+] Copying certs to /etc/openvpn..."
sudo cp pki/ca.crt pki/issued/"$SERVER_NAME".crt pki/private/"$SERVER_NAME".key pki/dh.pem ta.key /etc/openvpn/

echo "[+] Writing server.conf..."
sudo tee "$SERVER_CONF" > /dev/null <<EOF
port $PORT
proto $PROTO
dev tun
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
dh dh.pem
auth SHA256
tls-auth ta.key 0
cipher AES-256-GCM
topology subnet
server $VPN_SUBNET $VPN_MASK
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir $CCD_DIR
keepalive 10 120
persist-key
persist-tun
user nobody
group nogroup
push "route $VPN_SUBNET $VPN_MASK"
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

echo "[+] Enabling IP forwarding..."
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

echo "[+] Configuring UFW firewall rules..."
PUB_IF=$(ip -o -4 route show to default | awk '{print $5}')
sudo ufw allow "$PORT"/"$PROTO"
sudo ufw allow OpenSSH

sudo tee /etc/ufw/before.rules > /dev/null <<EOF
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s $VPN_SUBNET/24 -o $PUB_IF -j MASQUERADE
COMMIT
EOF

sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw disable && sudo ufw enable

sudo mkdir -p "$CCD_DIR"
sudo systemctl enable openvpn@server
sudo systemctl restart openvpn@server

echo "✅ OpenVPN server running on $PROTO port $PORT"