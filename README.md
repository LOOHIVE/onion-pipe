# 🧅 Sapphive Onion-Pipe

**Onion-Pipe** is an anonymous tunnel that pipes darknet traffic to your local services. It is designed to be the ultimate developer tool for testing and receiving webhooks securely.

## ⚡ Quick Start

### 1. Run the container
```bash
docker run -d \
  -e FORWARD_DEST="http://host.docker.internal:3000" \
  --name onion-pipe \
  sapphive/onion-pipe:latest
```

### 2. Get your URL
Check the logs to see your unique `.onion` address:
```bash
docker logs onion-pipe
```

### 3. Configure Webhook
Copy the `.onion` address and paste it into GitHub, Stripe, or your service of choice.

---

## 🛠️ Configuration

| Variable | Default | Description |
| :--- | :--- | :--- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Where the traffic should be sent. |
| `LISTEN_PORT` | `80` | The internal port Nginx listens on within the container. |

## 📦 Persistence
To keep the same `.onion` address after restarting the container, mount a volume to `/var/lib/tor/hidden_service`:

```bash
docker run -d \
  -v $(pwd)/keys:/var/lib/tor/hidden_service \
  -e FORWARD_DEST="http://192.168.1.10:80" \
  sapphive/onion-pipe:latest
```

## ⚖️ Legal Disclaimer
Tor is a trademark of The Tor Project, Inc. This project is a community-driven implementation managed by SAPPHIVE and is not an official product of The Tor Project. All logos and trademarks belong to their respective owners.
