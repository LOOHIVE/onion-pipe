# <img src="https://raw.githubusercontent.com/SAPPHIVE/onion-pipe-relay/main/src/assets/logo/logo.png" height="32"> Onion-Pipe Client (by Sapphive)

![Docker Pulls](https://img.shields.io/docker/pulls/sapphive/onion-pipe) ![License](https://img.shields.io/badge/license-MIT-green) ![Security](https://img.shields.io/badge/security-hardened-orange)

## 🚀 Overview
**Onion-Pipe** is an open-source anonymous webhook system maintained by the Sapphive Infrastructure Team. It allows you to receive webhooks on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

By using the Onion-Pipe community relay network, you get a persistent, encrypted gateway that is identity-verified via GitHub.

---

## 🛠️ Rapid Setup (Docker Compose)

Establish your secure tunnel in seconds. First, generate your keys:
`docker run --rm -v $(pwd)/onion_keys:/keys sapphive/onion-pipe init`

Then, use the following `docker-compose.yml`:

```yaml
services:
  onion-pipe:
    image: sapphive/onion-pipe:latest
    container_name: webhook-gateway
    environment:
      - FORWARD_DEST=http://host.docker.internal:8080  # Local endpoint that receives webhook payloads
      - API_TOKEN=your_api_token_here                # Get this from onion-pipe.sapphive.com
    volumes:
      - ./onion_keys:/var/lib/tor/hidden_service
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
```

Note: `FORWARD_DEST` should point to the local HTTP endpoint that will receive decrypted webhook payloads from external webhook providers (for example: GitHub, Stripe, GitLab, PayPal). When running Docker on Windows or macOS, `host.docker.internal` maps to the host machine; if your service runs in another container, set `FORWARD_DEST` to that container's address and port.

---
## 💎 Features & Advantages

| Feature | Ngrok / Alternatives | **Sapphive Onion-Pipe** |
| :--- | :--- | :--- |
| **Authentication** | Shared Tokens | **Personal GitHub Identity** |
| **Privacy** | Centralized Snooping | **Zero-Knowledge Architecture** |
| **Persistence** | Random URLs (Free tier) | **Permanent .onion Addresses** |
| **Security** | Public Exposure | **End-to-End X25519 Encryption** |

---

## 🎯 How It Works: The Pipeline
1.  **The Relay (The Cloud)**: Someone sends a webhook to your relay URL (e.g., `https://relay.com/h/your-token`). The relay encrypts it instantly.
2.  **The Bridge (The Transit)**: The encrypted data is "blindly" passed through a bridge node to the Tor network.
3.  **The Client (Your Machine)**: **This container** receives that data from Tor, decrypts it using your local key, and delivers it to your application.

---

## 🛠️ Step-by-Step Setup

### Step 1: Link your Identity
Sign in at [onion-pipe.sapphive.com](https://onion-pipe.sapphive.com) (or your own self-hosted Master) to get your **API Key**.

### Step 2: Establish the Tunnel (Docker)
Run the client container locally. This acts as the "exit point" for your webhooks.

```yaml
services:
  onion-pipe:
    image: sapphive/onion-pipe:latest
    environment:
      # WHERE should the webhook go when it reaches your machine?
      # Example: http://localhost:8080/webhooks
      - FORWARD_DEST=http://host.docker.internal:8080
    volumes:
      - ./onion_keys:/var/lib/tor/hidden_service  # Keeps your address permanent
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
```

### Step 3: Register your Address
Once the container starts, it generates a unique `.onion` address. You must link this address to your account so the relay knows where to send your traffic.
- Use the **Dashboard UI** to add your new `.onion` address.
- Or use the **CLI**: `onion-pipe register <your-id>` (No .onion suffix).

---

## ⚙️ Performance & Persistence
- **Address Persistence:** Mount the `/var/lib/tor/hidden_service` volume to keep your `.onion` address forever.
- **Circuit Security:** All data is encrypted with YOUR local public key before reaching the relay.
- **Identity:** Manage all your hooks via your private GitHub-linked dashboard.

---

## 🤝 Project Links
*   **Repo:** [github.com/sapphive/onion-pipe](https://github.com/sapphive/onion-pipe)
*   **Relay Service:** [onion-pipe.sapphive.com](https://onion-pipe.sapphive.com)
*   **Support:** [support@sapphive.com](mailto:support@sapphive.com)

---

## ⚖️ Legal Disclaimer
This is open-source software provided by SAPPHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.

