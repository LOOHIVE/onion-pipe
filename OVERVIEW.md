# <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/torbrowser.svg" height="32"> Sapphive Onion-Pipe

![Docker Pulls](https://img.shields.io/docker/pulls/sapphive/onion-pipe) ![License](https://img.shields.io/badge/license-MIT-green) ![Security](https://img.shields.io/badge/security-hardened-orange)

## 🚀 The Solution
**Onion-Pipe** is a zero-config, anonymous webhook gateway. It allows developers to receive webhooks from services like GitHub, Stripe, or Shopify directly on their local machine or a private server—**even if it is behind a restrictive firewall or CGNAT.**

By using Tor Hidden Services, Onion-Pipe provides a permanent `.onion` entry point that securely tunnels traffic to any local port without requiring port forwarding, static IPs, or exposing your host to the public clear-net.

---

## 🛠️ Rapid Deployment (Docker Compose)

Expose your local service (running on port 8080) to the darknet in seconds:

```yaml
services:
  onion-pipe:
    image: sapphive/onion-pipe:latest
    container_name: webhook-gateway
    environment:
      - FORWARD_DEST=http://host.docker.internal:8080
      - LISTEN_PORT=80
    volumes:
      - ./onion_keys:/var/lib/tor/hidden_service
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
```

---

## 💎 Features & Comparison

| Feature | Ngrok / Cloudflare | **Sapphive Onion-Pipe** |
| :--- | :--- | :--- |
| **Cost** | Paid Tiers for Static URLs | **100% Free Forever** |
| **Anonymity** | Centralized Logging | **Zero-Knowledge (Tor-based)** |
| **Setup** | Requires Auth Tokens | **Plug & Play** |
| **Limits** | Bandwidth/Connection Caps | **Unlimited** |
| **Exposure** | Publicly Indexed | **Darknet-Only (Optional Security)** |

---

## 🎯 Use Cases

### 1. **Testing Webhooks Locally**
Hook up Stripe or GitHub to your local dev environment. Since the `.onion` address is cryptographic and persistent (if you mount the `onion_keys` volume), you never have to re-configure your webhook URL in the provider's dashboard.

### 2. **Private API Gateways**
Provide an API entry point for your IoT devices or remote workers that doesn't show up on search engines like Shodan.

### 3. **Firewall Bypassing**
Receive data on a server inside a corporate network or home lab where you don't have access to the router settings.

---

## ⚙️ Performance & Security
1.  **E2E Encryption:** Every request is encrypted twice—once by Nginx (Self-signed SSL) and once by the Tor circuit.
2.  **Privacy:** Your real IP address is never revealed to the webhook provider.
3.  **Persistence:** Your URL stays the same as long as you keep the `./onion_keys` folder.

---

## 🤝 Support
Developed by the **SAPPHIVE Infrastructure Team**.
*   **Repo:** [github.com/sapphive/onion-pipe](https://github.com/sapphive/onion-pipe)
*   **Inquiries:** [support@sapphive.com](mailto:support@sapphive.com)

---

## ⚖️ Legal Disclaimer
Tor is a trademark of The Tor Project, Inc. This project is a community-driven implementation managed by SAPPHIVE and is not an official product of The Tor Project. All logos and trademarks belong to their respective owners.
