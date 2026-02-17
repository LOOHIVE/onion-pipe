# <img src="https://raw.githubusercontent.com/loohive/onion-pipe/main/src/assets/logo/logo.png" height="32"> Onion-Pipe Client (by LOOHIVE)

**Onion-Pipe** is an open-source anonymous webhook system maintained by the LOOHIVE Infrastructure Team. It allows you to receive webhooks on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

## ⚡ Quick Setup

### 1. Authorize via CLI (Professional Flow)
Skip the website setup and authorize directly from your terminal:
```bash
docker run -it --rm loohive/onion-pipe login
```
Follow the prompts to log in via GitHub. It will provide you with the final command to start your tunnel.

### 2. Manual Setup (Alternative)

1. **Initialize Keys**: Run once to generate your E2EE keypair:
   ```bash
   docker run --rm -v ./registration:/registration loohive/onion-pipe init
   ```

2. **Launch the Multiplexer**: Replace `YOUR_API_TOKEN` with the one from the [Dashboard](https://onion-pipe.loohive.com).
   
   **Standard (Full Tunnel):**
   ```bash
   docker run -d --name onion-pipe \
     -v ./registration:/registration \
     -v ./onion_id:/var/lib/tor/hidden_service \
     -e API_TOKEN="YOUR_API_TOKEN" \
     -e SERVICES_MAP="/api=http://host.docker.internal:3000,/web=http://host.docker.internal:8080" \
     loohive/onion-pipe
   ```

### 3. Verification & Management
Check your logs to see your new `.onion` address:
```bash
docker logs onion-pipe -f
```

---

## ⚙️ Advanced Configuration (Multiplexer)

Onion-Pipe now supports **Full Tunnel Multiplexing**. You can route different path prefixes to different backend services through a single Tor circuit.

| Variable       | Example/Default | Purpose |
| :--- | :--- | :--- |
| `SERVICES_MAP` | `/api=http://api:3000,/=http://web:80` | **Multiplexer:** Map path prefixes to specific local URLs. |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | **Legacy:** Fallback destination if `SERVICES_MAP` is not set. |
| `RELAY_URL` | `https://onion-pipe.loohive.com` | The public relay endpoint. |
| `LOG_LEVEL` | `info` | Set to `debug` to see routing and decryption logs. |

### Example Routing
- Request to `https://relay.com/h/token/api/v1/users` → Goes to `http://api:3000/api/v1/users`
- Request to `https://relay.com/h/token/web/index.html` → Goes to `http://web:80/web/index.html`

---

## 🛡️ Why use this?

When you use a standard relay, the relay owner can read your webhooks (GitHub tokens, private data, etc.). **Onion-Pipe** uses "sealed box" encryption. Only the client running on **your** computer has the key to see the data. The relay only sees random scrambled text.

| Variable       | Default                            | Description                              |
| :------------- | :--------------------------------- | :--------------------------------------- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Local target where traffic is forwarded. |
| `LISTEN_PORT`  | `80`                               | Internal port the client listens on.     |

## 📦 Persistence

To keep the same `.onion` address across restarts, **always** mount a volume to `/var/lib/tor/hidden_service`. If this folder is lost, a new address will be generated.
**Note:** This image is security-hardened. It runs processes as non-root users (`tor`, `nginx`, `node`). Docker volume permissions are automatically handled on startup.

## ⚖️ Legal Disclaimer

This is open-source software provided by LOOHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.
