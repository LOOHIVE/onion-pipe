# Stage 1: Build/Install Node.js dependencies
FROM node:20-alpine AS builder
WORKDIR /app
RUN npm install libsodium-wrappers

# Stage 2: Final Production Image
FROM node:20-alpine

USER root

# Install Nginx, Tor, and tools
# Alpine uses 'apk' instead of 'apt-get'
RUN apk add --no-cache \
    nginx \
    bash \
    gettext \
    openssl \
    curl \
    su-exec \
    ca-certificates \
    tor && \
    mkdir -p /run/nginx && \
    mkdir -p /var/log/tor

# Setup Decrypter (Copy from builder)
WORKDIR /app
COPY --from=builder /app/node_modules /app/node_modules
COPY decrypter.js /app/decrypter.js

# Setup directories
RUN mkdir -p /var/lib/tor/hidden_service && \
    mkdir -p /etc/nginx/templates && \
    chown -R tor:tor /var/lib/tor && \
    chown -R node:node /app && \
    chmod 700 /var/lib/tor/hidden_service

# Generate self-signed SSL certificate for "HTTPS" requirement
# Note: Tor v3 is already encrypted, but this provides the protocol layering users expect
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/server.key \
    -out /etc/nginx/server.crt \
    -subj "/C=UN/ST=Privacy/L=Tor/O=LOOHIVE/CN=onion-pipe"

# Copy configuration templates and scripts
COPY nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

# Create simplified CLI shortcuts
RUN printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh login "$@"' > /usr/local/bin/login && \
    printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh register "$@"' > /usr/local/bin/register && \
    printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh init "$@"' > /usr/local/bin/init && \
    chmod +x /usr/local/bin/login /usr/local/bin/register /usr/local/bin/init

# Default ENV variables
ENV FORWARD_DEST="http://host.docker.internal:8080"
ENV LISTEN_PORT=80

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
