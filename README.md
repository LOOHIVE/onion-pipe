# <img src="https://raw.githubusercontent.com/SAPPHIVE/onion-pipe/main/src/assets/logo/logo.png" height="32"> Onion-Pipe Client (by Sapphive)

**Onion-Pipe** is an open-source anonymous webhook system maintained by the Sapphive Infrastructure Team. It allows you to receive webhooks on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

## ⚡ Quick Setup

### 1. Authorize via CLI (Professional Flow)
Skip the website setup and authorize directly from your terminal:
```bash
docker run -it --rm sapphive/onion-pipe login
```
Follow the prompts to log in via GitHub. It will provide you with the final command to start your tunnel.

### 2. Manual Setup (Alternative)

1. **Initialize Keys**: Run once to generate your E2EE keypair:
   ```bash
   docker run --rm -v ./registration:/registration sapphive/onion-pipe init
   ```

2. **Launch the Tunnel**: Replace `YOUR_API_TOKEN` with the one from the [Dashboard](https://onion-pipe.sapphive.com):
   ```bash
   docker run -d --name onion-pipe -v ./registration:/registration -v ./onion_id:/var/lib/tor/hidden_service -e API_TOKEN="YOUR_API_TOKEN" -e FORWARD_DEST="http://host.docker.internal:8080" sapphive/onion-pipe
   ```

### 3. Verification & Management
Check your logs to see your new `.onion` address:
```bash
docker logs onion-pipe -f
```

If you need to manually re-register or rotate keys:
```bash
docker exec onion-pipe register
```

---

## ⚙️ Advanced Configuration

| Variable       | Default                            | Purpose                                          |
| :------------- | :--------------------------------- | :----------------------------------------------- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Where the decrypted traffic is "piped" to.       |
| `LISTEN_PORT`  | `80`                               | The port the client uses inside its own network. |

## 🛡️ Why use this?

When you use a standard relay, the relay owner can read your webhooks (GitHub tokens, private data, etc.). **Onion-Pipe** uses "sealed box" encryption. Only the client running on **your** computer has the key to see the data. The relay only sees random scrambled text.

| Variable       | Default                            | Description                              |
| :------------- | :--------------------------------- | :--------------------------------------- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Local target where traffic is forwarded. |
| `LISTEN_PORT`  | `80`                               | Internal port the client listens on.     |

## 📦 Persistence

To keep the same `.onion` address across restarts, **always** mount a volume to `/var/lib/tor/hidden_service`. If this folder is lost, a new address will be generated.

## ⚖️ Legal Disclaimer

This is open-source software provided by SAPPHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.
