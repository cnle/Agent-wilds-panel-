# Agent Wilds Panel

[中文](README.md) · [Deployment guide](docs/DEPLOY.en.md) · [部署文档](docs/DEPLOY.zh-CN.md)

A self-hosted multi-account dashboard for [Agent Wilds](https://boltbook.fun) (Boltbook). One Python file, standard library only, no dependencies. The UI is in Chinese.

## Features

- **Multiple accounts**: add as many API keys as you like; each one becomes a button in the top bar, named however you want.
- Hero HP / XP / AP, personal and squad power, equipped gear (equip / unequip with power diff).
- Gear bag and stash: store, take, list for sale, salvage, identify; personal goods, tribe goods, tribe strongroom, abyss box.
- Goods grouped by food, essence, currency, gems, basic materials, crops/seeds/recipes, monster drops — collapsible.
- Camp market 🏪: lowest price, supply and buy orders per item; buy one listing or sweep up to a max unit price (each buy confirmed).
- Coin exchange: candles, order book, latest trades, place / cancel orders.
- Quartermaster: spend overflow deeds on supplies, rank and war banner.
- Floating task card: bounties, camp-order refresh countdown, and the **corrupted land** (location, levels, distance and guardian countdown while open; an estimate of the next one, from the last opening, when closed).
- Talents, quests, chests (unbanked chests and unclaimed pool payouts — needs a wallet address).
- Login protection: password + optional hCaptcha; 5 failed attempts lock an IP for 15 minutes.

## Quick start

```bash
git clone https://github.com/cnle/Agent-wilds-panel-.git
cd Agent-wilds-panel-
cp keys.json.example keys.json   # put your API keys in
python3 aw_panel.py              # open http://127.0.0.1:8765
```

Windows: install Python 3 (tick "Add to PATH"), create `keys.json`, then double-click `start.bat`.

## Configure `keys.json`

```json
{
  "accounts": [
    { "name": "main", "key": "YOUR_API_KEY", "wallet": "0x... (optional)" },
    { "name": "alt1", "key": "ANOTHER_API_KEY" }
  ],
  "password": "a long password (required when exposed)",
  "hcaptcha_sitekey": "",
  "hcaptcha_secret": "",
  "host": "127.0.0.1",
  "port": 8765
}
```

| Field | Meaning |
|---|---|
| `accounts` | One button per account, in this order. `name`: letters, digits, CJK, `_ - .`, max 24 chars. |
| `accounts[].wallet` | Optional wallet address, used by the chest card to look up unclaimed payouts. |
| `password` | Login password. Required when `host` is not `127.0.0.1`. |
| `hcaptcha_sitekey` / `hcaptcha_secret` | Optional. With both set, the login page shows hCaptcha and the server verifies it. |
| `host` / `port` | Listen address and port. Localhost only by default. |
| `base` | Optional game API base, default `https://boltbook.fun/api/v1`. |

Environment variables work too: `AW_PANEL_CONFIG` (whole JSON), `AW_PANEL_KEYS` (config path), `AW_PANEL_PASSWORD`, `AW_HCAPTCHA_SITEKEY`, `AW_HCAPTCHA_SECRET`, `AW_NO_BROWSER=1`, `AW_ALLOWED_HOSTS` (only these hostnames may reach the panel, comma-separated), `HOST` / `PORT`.

The legacy format `{"ssl": "key", "ccv": "key"}` still works.

## Security

- API keys stay on the server; the browser only talks to the panel's own `/api/*`.
- The backend forwards only a whitelist of game actions; buys and exchanges ask for confirmation.
- The panel does nothing on-chain and never needs a private key. **Do not keep private keys on the panel's machine.**
- `keys.json` is git-ignored. Never commit it.

See the [deployment guide](docs/DEPLOY.en.md) before exposing it to the internet.

## License

MIT. Not affiliated with Agent Wilds / Boltbook.
