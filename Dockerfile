# Use Sapphive's official Tor image as base
FROM sapphive/tor:latest

USER root
# Install Nginx, Supervisor, and tools (Debian)
RUN apt update && \
    apt install -y --no-install-recommends \
    nginx \
    supervisor \
    bash \
    curl \
    gettext \
    openssl && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Setup directories
RUN mkdir -p /var/lib/tor/hidden_service && \
    mkdir -p /run/nginx && \
    mkdir -p /etc/nginx/templates && \
    chown -R debian-tor:debian-tor /var/lib/tor && \
    chmod 700 /var/lib/tor/hidden_service

# Generate self-signed SSL certificate for "HTTPS" requirement
# Note: Tor v3 is already encrypted, but this provides the protocol layering users expect
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/server.key \
    -out /etc/nginx/server.crt \
    -subj "/C=UN/ST=Privacy/L=Tor/O=Sapphive/CN=onion-pipe"

# Copy configuration templates and scripts
COPY nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

# Create simplified CLI shortcuts
RUN printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh login "$@"' > /usr/local/bin/login && \
    printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh register "$@"' > /usr/local/bin/register && \
    printf '#!/bin/bash\n/usr/local/bin/entrypoint.sh init "$@"' > /usr/local/bin/init && \
    chmod +x /usr/local/bin/login /usr/local/bin/register /usr/local/bin/init

# Setup Supervisor configuration
RUN echo "[supervisord]" > /etc/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisord.conf && \
    echo "user=root" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:nginx]" >> /etc/supervisord.conf && \
    echo "command=nginx -g \"daemon off;\"" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:tor]" >> /etc/supervisord.conf && \
    echo "command=tor -f /etc/tor/torrc" >> /etc/supervisord.conf && \
    echo "user=debian-tor" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf

# Default ENV variables
ENV FORWARD_DEST="http://host.docker.internal:8080"
ENV LISTEN_PORT=80

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
