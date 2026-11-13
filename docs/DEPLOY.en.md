# Deployment guide

The panel is a long-running Python process that holds your API keys on its own machine. Options are listed from most to least recommended.

> Rule of thumb: keys stay on the server; the panel listens on `127.0.0.1` only and is exposed through an HTTPS tunnel; login uses a long password plus hCaptcha.

## 0. Prepare

1. Python 3.8+ (not needed for Docker).
2. Copy `keys.json.example` to `keys.json` and fill in accounts and password.
3. `chmod 600 keys.json` on Linux / macOS.

## 1. Local only (simplest)

```bash
python3 aw_panel.py
```

Open `http://127.0.0.1:8765`. No password needed while it only listens on localhost.

## 2. Always-on home PC / NAS / Raspberry Pi + Cloudflare Tunnel (recommended)

No public IP, no router port forwarding, HTTPS included.

1. Add your domain to Cloudflare.
2. Install `cloudflared`: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/>
3. Log in and create a tunnel:

```bash
cloudflared tunnel login
cloudflared tunnel create aw-panel
cloudflared tunnel route dns aw-panel panel.example.com
```

4. Create `~/.cloudflared/config.yml`:

```yaml
tunnel: aw-panel
credentials-file: /home/you/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: panel.example.com
    service: http://127.0.0.1:8765
  - service: http_status:404
```

5. Keep `"host": "127.0.0.1"` in `keys.json` and set `password` plus hCaptcha (section 5).
6. Run `python3 aw_panel.py` and `cloudflared tunnel run aw-panel`, then open `https://panel.example.com`.

See section 4 for starting on boot.

## 3. Free cloud VM (e.g. Oracle Cloud Always Free)

1. Create a small Ubuntu VM.
2. Do **not** open port 8765 in the security list / firewall.
3. Upload the project and set up Cloudflare Tunnel as in section 2, or use Caddy / Nginx as an HTTPS reverse proxy.
4. Prefer passing config through the environment instead of a file:

```bash
export AW_PANEL_CONFIG='{"accounts":[{"name":"main","key":"..."}],"password":"...","hcaptcha_sitekey":"...","hcaptcha_secret":"..."}'
```

## 4. Start on boot with systemd (Linux)

`/etc/systemd/system/aw-panel.service`:

```ini
[Unit]
Description=Agent Wilds Panel
After=network-online.target

[Service]
User=youruser
WorkingDirectory=/opt/agent-wilds-panel
Environment=AW_NO_BROWSER=1
ExecStart=/usr/bin/python3 /opt/agent-wilds-panel/aw_panel.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now aw-panel
```

To keep secrets in a separate file, use `EnvironmentFile=/etc/aw-panel.env` (mode 600) with `AW_PANEL_PASSWORD=...` and so on.

## 5. Set up hCaptcha

1. Sign up at <https://dashboard.hcaptcha.com>, add a site and your domain (add `localhost` for local testing).
2. Copy the **Sitekey** and the account **Secret**.
3. Put them in `keys.json`:

```json
"hcaptcha_sitekey": "your sitekey",
"hcaptcha_secret": "your secret"
```

or set `AW_HCAPTCHA_SITEKEY` / `AW_HCAPTCHA_SECRET`.

4. Restart the panel. The login page shows the challenge, and the server verifies it with `https://api.hcaptcha.com/siteverify` before checking the password. If either value is missing, hCaptcha is off.

For local testing you can use hCaptcha's test keys: sitekey `10000000-ffff-ffff-ffff-000000000001`, secret `0x0000000000000000000000000000000000000000` (anyone passes — **never use them in production**).

## 6. Docker

```bash
docker build -t aw-panel .
docker run -d --name aw-panel --restart unless-stopped \
  -p 127.0.0.1:8765:8765 \
  -e AW_PANEL_CONFIG="$(cat keys.json)" \
  aw-panel
```

Inside a container the panel must listen on `0.0.0.0`, so set `"host": "0.0.0.0"` (a password is then required). `-p 127.0.0.1:8765:8765` keeps it local to the host; expose it with a tunnel.

## 6.5 Wasmer Edge (free hosting, no server of your own)

Wasmer Edge runs Python directly and gives you HTTPS. The bundled `cacert.pem` exists for it: Wasmer's Python runtime has no system root certificates.

**1. Prepare a folder** (Wasmer's Python preset expects the entry point at `src/main.py`):

```bash
mkdir aw-wasmer && cd aw-wasmer && mkdir src
cp ../aw_panel.py src/main.py
cp ../bg.jpg ../cacert.pem src/
```

**2. Create `app.yaml`** (set `owner` to your Wasmer username; pick any `name`):

```yaml
kind: wasmer.io/App.v0
name: agent-wilds-panel
owner: YOUR_WASMER_USERNAME
package: .
env:
  AW_NO_BROWSER: "1"
  HOST: "0.0.0.0"
  # Enable these after you add a custom domain (step 5)
  # AW_ALLOWED_HOSTS: "panel.example.com"
# domains:
#   - panel.example.com
```

Never put keys or passwords in `app.yaml`.

**3. Install the CLI and deploy:**

```bash
curl https://get.wasmer.io -sSfL | sh      # on Windows see the wasmer.io docs
wasmer login                               # or set WASMER_TOKEN
wasmer deploy --non-interactive --build-remote
```

You get a `https://<name>.wasmer.app` address when it finishes.

**4. Set Secrets in the Wasmer dashboard** (App → Settings → Secrets), then press **Redeploy** for them to take effect:

| Secret | Value |
|---|---|
| `AW_PANEL_CONFIG` | The whole `keys.json` content (valid JSON: paste one `{...}` only, no example text) |
| `AW_PANEL_PASSWORD` | Login password (required on the internet) |
| `AW_HCAPTCHA_SITEKEY` / `AW_HCAPTCHA_SECRET` | Optional, turns on hCaptcha |

From the CLI: `wasmer app secret create --app YOUR_WASMER_USERNAME/agent-wilds-panel AW_PANEL_PASSWORD 'long-password'`, then `wasmer deploy` again.

Check the logs: `wasmer app logs YOUR_WASMER_USERNAME/agent-wilds-panel` should show `accounts / 账号: ...`. An error like `Extra data` means `AW_PANEL_CONFIG` is not valid JSON.

**5. Use your own domain (optional)**

1. Add the domain under `domains` in `app.yaml` and deploy again.
2. At your DNS provider add a CNAME: `panel` → `<name>.wasmer.app`. On Cloudflare set it to **DNS only (grey cloud, not proxied)**, or Wasmer cannot issue the certificate.
3. After a few minutes open `https://panel.example.com`.

**Custom domain only:** set `AW_ALLOWED_HOSTS` (comma-separated). The panel then answers 404 to every other host, `*.wasmer.app` included. Turn it on only after the custom domain works, or you lock yourself out.

**Updating:** replace `src/main.py` and run `wasmer deploy --non-interactive --build-remote` again.

## 7. Security checklist

- [ ] `keys.json` is mode 600 and not committed.
- [ ] The panel listens on `127.0.0.1`; port 8765 is closed on the VM firewall.
- [ ] Accessed over HTTPS (tunnel or reverse proxy); the cookie gets `Secure` automatically.
- [ ] A long password and hCaptcha are set.
- [ ] One API key per game account; if one leaks, regenerate it in the game, update the config and restart.
- [ ] No wallet private keys on this machine.

## Not recommended

- Static hosts (GitHub Pages, Netlify): there is no backend, so keys would sit in the browser for anyone to read.
- Opening port 8765 to the internet with only a password.
- Unknown free tunneling tools.
