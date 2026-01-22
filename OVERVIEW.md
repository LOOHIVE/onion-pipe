# <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/torbrowser.svg" height="32"> Sapphive Onion-Pipe Client

![Docker Pulls](https://img.shields.io/docker/pulls/sapphive/onion-pipe) ![License](https://img.shields.io/badge/license-MIT-green) ![Security](https://img.shields.io/badge/security-hardened-orange)

## 🚀 Overview
**Onion-Pipe** is a secure, anonymous webhook client. It allows you to receive traffic on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

By using the Sapphive Relay Network, you get a persistent, encrypted gateway that is identity-verified via GitHub.

---

## 🛠️ Rapid Setup (Docker Compose)

Establish your secure tunnel in seconds:

```yaml
services:
  onion-pipe:
    image: sapphive/onion-pipe:latest
    container_name: webhook-gateway
    environment:
      - FORWARD_DEST=http://host.docker.internal:8080
    volumes:
      - ./onion_keys:/var/lib/tor/hidden_service
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
```

---

## 💎 Features & Advantages

| Feature | Ngrok / Alternatives | **Sapphive Onion-Pipe** |
| :--- | :--- | :--- |
| **Authentication** | Shared Tokens | **Personal GitHub Identity** |
| **Privacy** | Centralized Snooping | **Zero-Knowledge Architecture** |
| **Persistence** | Random URLs (Free tier) | **Permanent .onion Addresses** |
| **Security** | Public Exposure | **End-to-End X25519 Encryption** |

---

## 🎯 How It Works
1.  **Dashboard Login:** Sign in at [onion-pipe.sapphive.com](https://onion-pipe.sapphive.com) to get your API Key.
2.  **CLI Registration:** Use the `onion-pipe` CLI to register your new `.onion` address.
3.  **Tunnel Active:** Start this container locally. Any traffic sent to the public relay will be encrypted and delivered directly to your localhost.

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

