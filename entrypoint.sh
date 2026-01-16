#!/bin/bash

# Ensure Tor data directory has correct permissions for debian-tor
chown -R debian-tor:debian-tor /var/lib/tor
chmod 700 /var/lib/tor
chmod 700 /var/lib/tor/hidden_service

# Generate Tor Configuration based on LISTEN_PORT
cat > /etc/tor/torrc <<EOF
DataDirectory /var/lib/tor
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:${LISTEN_PORT}
HiddenServicePort 443 127.0.0.1:443
Log notice stdout
EOF

# Process Nginx template
envsubst '${FORWARD_DEST} ${LISTEN_PORT}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# Start Tor in background as debian-tor
echo "🧅 Establishing Sapphive Onion-Pipe circuit..."
su -s /bin/bash debian-tor -c "tor -f /etc/tor/torrc --RunAsDaemon 1"

# Wait for hostname
MAX_RETRIES=30
COUNT=0
echo "⏳ Generating your unique Webhook entry point..."
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    sleep 2
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Error: Tor failed to initialize. Check your network connection."
        exit 1
    fi
done

ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname)

echo "***************************************************"
echo "  🚀 SAPPHIVE ONION-PIPE IS ACTIVE"
echo "  📍 PUBLIC ONION: http://$ONION_ADDR"
echo "  🔒 SECURE ONION: https://$ONION_ADDR"
echo "  ➡️  FORWARDING TO: $FORWARD_DEST"
echo "***************************************************"

# Cleanup for Supervisor
pkill tor
sleep 1

exec /usr/bin/supervisord -c /etc/supervisord.conf
