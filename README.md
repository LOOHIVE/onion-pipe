# 🧅 Sapphive Onion-Pipe Client

**Onion-Pipe** is an anonymous tunnel client that pipes darknet traffic to your local services. It is designed to be the ultimate developer tool for testing and receiving webhooks securely in a zero-trust environment.

## ⚡ Quick Start

### 1. Account Setup
Before running the client, sign in at [onion-pipe.sapphive.com](https://onion-pipe.sapphive.com) to link your GitHub account and receive your **API Key**.

### 2. Run the Service
```bash
docker run -d \
  -e FORWARD_DEST="http://host.docker.internal:3000" \
  -v $(pwd)/keys:/var/lib/tor/hidden_service \
  --name onion-pipe \
  sapphive/onion-pipe:latest
```

### 3. Get your Endpoint
Check the logs to see your unique `.onion` address:
```bash
docker logs onion-pipe
```

### 4. Register mapping
Register this `.onion` address to your account via the dashboard or CLI:
```bash
npm run cli register <your-hidden-service-id>
```

---

## 🛠️ Configuration

| Variable | Default | Description |
| :--- | :--- | :--- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Local target where traffic is forwarded. |
| `LISTEN_PORT` | `80` | Internal port the client listens on. |

## 📦 Persistence
To keep the same `.onion` address across restarts, **always** mount a volume to `/var/lib/tor/hidden_service`. If this folder is lost, a new address will be generated.

## ⚖️ Legal Disclaimer
This is open-source software provided by SAPPHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.

