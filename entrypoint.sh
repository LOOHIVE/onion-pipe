#!/bin/bash

# --- INIT MODE ---
if [ "$1" == "init" ]; then
    echo "🔑 Configuring Onion-Pipe Security Layer..."
    mkdir -p /registration
    
    # Generate X25519 Keypair using OpenSSL (Overwrites existing for rotation)
    openssl genpkey -algorithm X25519 -out /registration/priv.key 2>/dev/null
    
    # Extract the RAW 32-byte public key and encode it to Base64
    PUB_BASE64=$(openssl pkey -in /registration/priv.key -pubout -outform DER | tail -c 32 | base64 | tr -d '\n')
    echo "$PUB_BASE64" > /registration/pub.key
    
    echo "✅ Success: Keypair generated in /registration/"
    echo "   Note: Previous keys in this folder have been replaced (Rotated)."
    echo "   Public Key: $PUB_BASE64"
    exit 0
fi

# --- LOGIN MODE ---
if [ "$1" == "login" ]; then
    RELAY_URL=${RELAY_URL:-"https://onion-pipe.loohive.com"}
    echo ""
    echo "🌐 Onion-Pipe CLI Login"
    echo "------------------------"
    echo "1. Open your browser and visit:"
    echo "   $RELAY_URL/cli-auth"
    echo ""
    echo "2. Log in with your GitHub account."
    echo "3. Enter the 6-digit code displayed on the screen below."
    echo ""
    echo -n "🔑 Enter Code: "
    read -r AUTH_CODE

    if [ -z "$AUTH_CODE" ]; then
        echo "❌ Error: Code cannot be empty."
        exit 1
    fi

    echo "🔄 Authenticating with relay..."
    RESPONSE=$(curl -s -X POST "$RELAY_URL/auth/cli/exchange" \
        -H "Content-Type: application/json" \
        -d "{\"code\": \"$AUTH_CODE\"}")
    
    API_TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"api_key":"\([^"]*\)".*/\1/p')

    if [ -z "$API_TOKEN" ]; then
        ERROR_MSG=$(echo "$RESPONSE" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
        echo "❌ Login Failed: ${ERROR_MSG:-"Invalid code or connection error"}"
        exit 1
    fi

    echo "✅ Success! You are now authenticated."
    echo ""
    echo "� FINAL SETUP COMMANDS"
    echo "------------------------------------------------------"
    echo "Option A: Single-Line Command (Universal)"
    echo "docker run -d --name onion-pipe -v ./registration:/registration -v ./onion_id:/var/lib/tor/hidden_service -e API_TOKEN=\"$API_TOKEN\" -e SERVICES_MAP=\"/=http://host.docker.internal:8080\" loohive/onion-pipe"
    echo ""
    echo "Option B: Docker Compose (Recommended)"
    echo "services:"
    echo "  onion-pipe:"
    echo "    image: loohive/onion-pipe"
    echo "    container_name: onion-pipe"
    echo "    restart: unless-stopped"
    echo "    volumes:"
    echo "      - ./registration:/registration"
    echo "      - ./onion_id:/var/lib/tor/hidden_service"
    echo "    environment:"
    echo "      API_TOKEN: \"$API_TOKEN\""
    echo "      SERVICES_MAP: \"/=http://host.docker.internal:8080\""
    echo "------------------------------------------------------"
    echo "💡 Note: Use SERVICES_MAP to route different paths to different backend services."
    echo ""
    exit 0
fi

if [ "$1" == "register" ]; then
    echo "🔗 Manual Registration Triggered..."
    if [ -f "/var/lib/tor/hidden_service/hostname" ]; then
        ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname)
        SERVICE_ID=${ONION_ADDR%%.onion}
        RELAY_URL=${RELAY_URL:-"https://onion-pipe.loohive.com"}
        
        PUB_KEY_PATH="/registration/pub.key"

        if [ -f "$PUB_KEY_PATH" ] && [ ! -z "$API_TOKEN" ]; then
            PUB_KEY=$(cat "$PUB_KEY_PATH")
            RESPONSE=$(curl -s -X POST "$RELAY_URL/register" \
                -H "Content-Type: application/json" \
                -d "{\"onion_service_id\": \"$SERVICE_ID\", \"token\": \"$API_TOKEN\", \"public_key\": \"$PUB_KEY\"}")
            
            TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

            if [ ! -z "$TOKEN" ]; then
                echo "✅ MANUAL REGISTRATION SUCCESSFUL!"
                echo "   Public Endpoint: $RELAY_URL/h/$TOKEN"
                echo "   Check your dashboard to manage this hook."
                exit 0
            else
                echo "❌ REGISTRATION FAILED: $RESPONSE"
                exit 1
            fi
        else
            echo "❌ ERROR: Missing API_TOKEN or Public Key in /registration/ folder."
            exit 1
        fi
    else
        echo "❌ ERROR: Tor hostname not found. Is the container running?"
        exit 1
    fi
fi

# Ensure Tor data directory has correct permissions for tor user
chown -R tor:tor /var/lib/tor
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

# Start Tor in background as tor user
echo "🧅 Establishing LOOHIVE Onion-Pipe circuit..."
su -s /bin/bash tor -c "tor -f /etc/tor/torrc --RunAsDaemon 1"

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

ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname | tr -d '\n\r')
SERVICE_ID=${ONION_ADDR%%.onion}

if [ -z "$SERVICE_ID" ]; then
    echo "❌ ERROR: Tor hostname is empty. Registration aborted."
    exit 1
fi

# Setup permissions for the decrypter user
chown -R node:node /registration 2>/dev/null || true

# --- AUTOMATIC REGISTRATION ---
RELAY_URL=${RELAY_URL:-"https://onion-pipe.loohive.com"}

if [ ! -z "$API_TOKEN" ]; then
    echo "🔗 Registering with Relay ($RELAY_URL)..."
    
    # Mandatory Public Key for E2EE (Now in registration volume)
    PUB_KEY_PATH="/registration/pub.key"

    if [ -f "$PUB_KEY_PATH" ]; then
        PUB_KEY=$(cat "$PUB_KEY_PATH")
        
        RESPONSE=$(curl -s -X POST "$RELAY_URL/register" \
            -H "Content-Type: application/json" \
            -d "{\"onion_service_id\": \"$SERVICE_ID\", \"token\": \"$API_TOKEN\", \"public_key\": \"$PUB_KEY\"}")
        
        TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

        if [ ! -z "$TOKEN" ]; then
            echo "✅ SUCCESSFULLY REGISTERED with Relay!"
            echo "   Public Endpoint: $RELAY_URL/h/$TOKEN"
            echo "   Manage your tunnel at: $RELAY_URL/dashboard"
            REGISTERED_TOKEN=$TOKEN
        else
            echo "❌ REGISTRATION REJECTED. Ensure your API_TOKEN is valid."
            echo "   Response: $RESPONSE"
        fi
    else
        echo "❌ FAILED: Public key (/registration/pub.key) not found."
        echo "   Registration requires a public key for End-to-End Encryption."
        echo "   Please run 'init' command first to generate keys in your volume."
    fi
else
    echo "ℹ️  No API_TOKEN provided. Skipping automatic registration."
fi
# Setup directories and permissions
mkdir -p /registration
chown -R node:node /registration 2>/dev/null || true

# -----------------------------

echo "***************************************************"
echo "  🚀 LOOHIVE ONION-PIPE IS ACTIVE"
if [ ! -z "$REGISTERED_TOKEN" ]; then
echo "  🔗 PUBLIC WEBHOOK: $RELAY_URL/h/$REGISTERED_TOKEN"
fi
echo "  📍 PUBLIC ONION: http://$ONION_ADDR"
echo "  🔒 SECURE ONION: https://$ONION_ADDR"
if [ ! -z "$SERVICES_MAP" ]; then
echo "  ➡️  MULTIPLEXER: $SERVICES_MAP"
else
echo "  ➡️  FORWARDING TO: $FORWARD_DEST"
fi
echo "***************************************************"

# Ensure no orphan Tor processes exist before starting
pkill -9 tor || true

# Start Nginx in background
nginx -g "daemon off;" &
NGINX_PID=$!

# Start Tor (as user tor)
su-exec tor tor -f /etc/tor/torrc &
TOR_PID=$!

# Start Decrypter (as user node)
export TUNNEL_ID=$REGISTERED_TOKEN
su-exec node node /app/decrypter.js &
DECRYPTER_PID=$!

# Handle graceful shutdown
cleanup() {
    echo "Stopping services..."
    kill -TERM "$NGINX_PID" "$DECRYPTER_PID" "$TOR_PID" 2>/dev/null
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "✅ All services started. Monitoring..."

# Simple process monitor
while true; do
    if ! kill -0 "$NGINX_PID" >/dev/null 2>&1; then
        echo "❌ Nginx exited."
        kill -TERM "$DECRYPTER_PID" "$TOR_PID" 2>/dev/null
        exit 1
    fi
    if ! kill -0 "$DECRYPTER_PID" >/dev/null 2>&1; then
        echo "❌ Decrypter exited."
        kill -TERM "$NGINX_PID" "$TOR_PID" 2>/dev/null
        exit 1
    fi
    if ! kill -0 "$TOR_PID" >/dev/null 2>&1; then
        echo "❌ Tor exited."
        kill -TERM "$NGINX_PID" "$DECRYPTER_PID" 2>/dev/null
        exit 1
    fi
    sleep 5
done
