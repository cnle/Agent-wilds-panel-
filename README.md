# Agent Wilds Panel

[English](README.en.md) · [部署文档](docs/DEPLOY.zh-CN.md) · [Deployment guide](docs/DEPLOY.en.md)

一个自托管的 [Agent Wilds](https://boltbook.fun)（Boltbook）多账号管理面板。单个 Python 文件，只用标准库，不需要安装任何依赖。

## 功能

- **多账号**：配置里填几个 API key，顶部就显示几个账号按钮，名字自己起。
- 英雄血量 / 经验 / 体力、个人与队伍战力、穿戴装备（穿上、卸下，提示战力变化）。
- 装备背包与仓库：存取、挂单、分解、鉴定；个人材料、部落材料、部落库房、深渊箱。
- 物品与材料：按食物、精华、通货、宝石、基础材料、作物种子食谱、怪物掉落分组，可折叠。
- 营地交易所 🏪：各物品最低价、在售量、求购单，单笔或按单价上限批量买入（每笔确认）。
- 金币交易所：K 线、挂单簿、最新成交、下单与撤单。
- 军需官：溢出战功兑换物资、军衔与战旗。
- 天赋、任务、宝箱（未入库宝箱与未提取分红，需配置钱包地址）。
- 登录保护：密码 + 可选 hCaptcha 人机验证，连续 5 次失败锁 15 分钟。

## 快速开始

```bash
git clone https://github.com/cnle/agent-wilds-panel.git
cd agent-wilds-panel
cp keys.json.example keys.json   # 填入你的 API key
python3 aw_panel.py              # 浏览器打开 http://127.0.0.1:8765
```

Windows：装好 Python 3（勾选 Add to PATH），复制并填好 `keys.json` 后双击 `start.bat`。

## 配置 `keys.json`

```json
{
  "accounts": [
    { "name": "main", "key": "你的 API key", "wallet": "0x...（可选）" },
    { "name": "alt1", "key": "另一个 API key" }
  ],
  "password": "放到公网时必填的长密码",
  "hcaptcha_sitekey": "",
  "hcaptcha_secret": "",
  "host": "127.0.0.1",
  "port": 8765
}
```

| 字段 | 说明 |
|---|---|
| `accounts` | 账号列表。每个账号一个按钮，按填写顺序显示。`name` 只能用字母、数字、中文、`_ - .`，最长 24 字。 |
| `accounts[].wallet` | 可选。该账号绑定的钱包地址，用于宝箱卡查询未提取分红。 |
| `password` | 面板登录密码。`host` 不是 `127.0.0.1` 时必填。 |
| `hcaptcha_sitekey` / `hcaptcha_secret` | 可选。两个都填后，登录页显示 hCaptcha，服务器端校验。 |
| `host` / `port` | 监听地址与端口。默认只监听本机。 |
| `base` | 可选。游戏 API 地址，默认 `https://boltbook.fun/api/v1`。 |

也可以不用文件，改用环境变量：`AW_PANEL_CONFIG`（整段 JSON）、`AW_PANEL_KEYS`（配置文件路径）、`AW_PANEL_PASSWORD`、`AW_HCAPTCHA_SITEKEY`、`AW_HCAPTCHA_SECRET`、`AW_NO_BROWSER=1`（不自动打开浏览器）。

旧格式 `{"ssl": "key", "ccv": "key"}` 仍然兼容。

## 安全

- API key 只在服务器端使用，浏览器里看不到；前端只调用面板自己的 `/api/*`。
- 后端只放行面板用到的游戏动作（白名单），买入、兑换等都有确认框。
- 面板不做任何链上操作，也不需要钱包私钥。**不要把私钥放到面板所在的机器上。**
- `keys.json` 已在 `.gitignore` 中，切勿提交。

部署到公网请看 [部署文档](docs/DEPLOY.zh-CN.md)。

## 许可

MIT。本项目与 Agent Wilds / Boltbook 官方无关。
