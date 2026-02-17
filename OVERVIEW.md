# <img src="https://raw.githubusercontent.com/loohive/onion-pipe-relay/main/src/assets/logo/logo.png" height="32"> Onion-Pipe Client (by LOOHIVE)

![Docker Pulls](https://img.shields.io/docker/pulls/loohive/onion-pipe) ![License](https://img.shields.io/badge/license-MIT-green) ![Security](https://img.shields.io/badge/security-hardened-orange)

## 🚀 Overview
**Onion-Pipe** is an open-source anonymous webhook system maintained by the LOOHIVE Infrastructure Team. It allows you to receive webhooks on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

By using the Onion-Pipe community relay network, you get a persistent, encrypted gateway that is identity-verified via GitHub.

---

## ⚡ Rapid Setup

### 1. Authorize via CLI (Recommended)
Skip the manual tokens and authorize directly from your terminal:
```bash
docker run -it --rm loohive/onion-pipe login
```
Follow the prompts to log in via GitHub. It will provide the final command to start your tunnel.

### 2. Manual Setup (Alternative)
First, generate your E2EE keys:
```bash
docker run --rm -v ./registration:/registration loohive/onion-pipe init
```

#### Option A: Single Command Deployment
```bash
docker run -d --name onion-pipe \
  -v ./registration:/registration \
  -v ./onion_id:/var/lib/tor/hidden_service \
  -e API_TOKEN="YOUR_API_TOKEN" \
  -e SERVICES_MAP="/api=http://host.docker.internal:3000,/web=http://host.docker.internal:8080" \
  loohive/onion-pipe
```

### Option B: Docker Compose Deployment (Recommended)
Use the following `docker-compose.yml` for multiplexed routing:

```yaml
services:
  onion-pipe:
    image: loohive/onion-pipe:latest
    container_name: loohive-gateway
    environment:
      - API_TOKEN=your_token_here
      - RELAY_URL=https://onion-pipe.loohive.com
      # Map multiple path prefixes to different backend services
      - SERVICES_MAP=/api=http://app:3000,/web=http://ui:80
    volumes:
      - ./registration:/registration
      - ./onion_id:/var/lib/tor/hidden_service
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
```

Note: `SERVICES_MAP` allows one .onion address to serve multiple backends. For example, a request to `/h/token/api/login` will be automatically routed to your `app` container on port 3000 at the path `/api/login`.

---
## 💎 Features & Advantages

| Feature | Ngrok / Alternatives | **LOOHIVE Onion-Pipe** |
| :--- | :--- | :--- |
| **Authentication** | Shared Tokens | **Personal GitHub Identity** |
| **Privacy** | Centralized Snooping | **Zero-Knowledge Architecture** |
| **Persistence** | Random URLs (Free tier) | **Permanent .onion Addresses** |
| **Security** | Public Exposure | **End-to-End X25519 Encryption** |
| **Multi-Service** | 1 Address = 1 App | **Multiplexer (Many-to-1)** |

---
## 🎯 How It Works: The Pipeline
1.  **The Relay (The Cloud)**: Someone sends a request to your relay URL (e.g., `https://relay.com/h/your-token/api/test`). The relay encrypts it instantly.
2.  **The Bridge (The Transit)**: The encrypted blob is "blindly" passed through a bridge node to the Tor network.
3.  **The Client (Your Machine)**: **This container** identifies the path (`/api/test`), decrypts it using your local private key, and forwards it synchronously to the mapped destination (`http://api:3000/api/test`).

---

## 🛠️ Management & Maintenance

### Manually Trigger Registration
If you change your environment or need to refresh your relay mapping:
```bash
docker exec onion-pipe register
```

### Rotating Encryption Keys
To rotate your E2EE identity (recommended every 90 days):
1. Run `init` again: 
```bash
docker run --rm -v ./registration:/registration loohive/onion-pipe init
```
2. Restart the container.
3. Trigger registration: 
```bash
docker exec onion-pipe register
```

---

## ⚙️ Performance & Persistence
- **Address Persistence:** Mount the `/var/lib/tor/hidden_service` volume to keep your `.onion` address forever.
- **Circuit Security:** All data is encrypted with YOUR local public key before reaching the relay.
- **Identity:** Manage all your hooks via your private GitHub-linked dashboard.

---

## 🤝 Project Links
*   **Repo:** [github.com/loohive/onion-pipe](https://github.com/loohive/onion-pipe)
*   **Relay Service:** [onion-pipe.loohive.com](https://onion-pipe.loohive.com)
*   **Support:** [support@loohive.com](mailto:support@loohive.com)

---

## ⚖️ Legal Disclaimer
This is open-source software provided by LOOHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.

