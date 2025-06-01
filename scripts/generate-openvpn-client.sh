#!/bin/bash

# === USAGE ===
# ./generate-openvpn-client.sh <client-name> <server-address> <port> <proto> <easyrsa-dir> <output-dir> <ta-key-path>

set -e

CLIENT_NAME="$1"
SERVER_ADDRESS="$2"
PORT="$3"
PROTO="$4"
EASYRSA_DIR="$5"
OUTPUT_DIR="$6"
TA_KEY_PATH="$7"

if [[ -z "$CLIENT_NAME" || -z "$SERVER_ADDRESS" || -z "$PORT" || -z "$PROTO" || -z "$EASYRSA_DIR" || -z "$OUTPUT_DIR" || -z "$TA_KEY_PATH" ]]; then
  echo "Usage: $0 <client-name> <server-address> <port> <proto> <easyrsa-dir> <output-dir> <ta-key-path>"
  exit 1
fi

KEY_DIR="$OUTPUT_DIR/keys"
CONF_DIR="$OUTPUT_DIR/files"
CONFIG="$CONF_DIR/${CLIENT_NAME}.ovpn"

mkdir -p "$KEY_DIR" "$CONF_DIR"

cd "$EASYRSA_DIR"
./easyrsa gen-req "$CLIENT_NAME" nopass
echo yes | ./easyrsa sign-req client "$CLIENT_NAME"

cp pki/ca.crt "$KEY_DIR/"
cp pki/issued/"$CLIENT_NAME".crt "$KEY_DIR/"
cp pki/private/"$CLIENT_NAME".key "$KEY_DIR/"
cp "$TA_KEY_PATH" "$KEY_DIR/ta.key"

cat > "$CONFIG" <<EOF
client
dev tun
proto $PROTO
remote $SERVER_ADDRESS $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-GCM
tls-auth ta.key 1
verb 3

<ca>
$(cat "$KEY_DIR/ca.crt")
</ca>

<cert>
$(cat "$KEY_DIR/$CLIENT_NAME.crt")
</cert>

<key>
$(cat "$KEY_DIR/$CLIENT_NAME.key")
</key>

<tls-auth>
$(cat "$KEY_DIR/ta.key")
</tls-auth>
EOF

echo "✅ Client config generated: $CONFIG"