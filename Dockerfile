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
RUN chmod +x /usr/local/bin/entrypoint.sh

# Setup Supervisor configuration
RUN echo $'[supervisord]\nnodaemon=true\nuser=root\n\n[program:nginx]\ncommand=nginx -g "daemon off;"\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\n\n[program:tor]\ncommand=tor -f /etc/tor/torrc\nuser=debian-tor\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0' > /etc/supervisord.conf

# Default ENV variables
ENV FORWARD_DEST="http://host.docker.internal:8080"
ENV LISTEN_PORT=80

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
