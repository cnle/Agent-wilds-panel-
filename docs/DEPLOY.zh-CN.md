# 部署文档

面板是一个长期运行的 Python 程序，API key 保存在它所在的机器上。下面按推荐程度列出几种部署方式。

> 原则：key 只放服务器端；面板只监听 `127.0.0.1`，通过 HTTPS 隧道对外；登录用长密码 + hCaptcha。

## 0. 准备

1. Python 3.8 以上（Docker 部署可跳过）。
2. 复制 `keys.json.example` 为 `keys.json`，填好账号和密码。
3. 在终端执行 `chmod 600 keys.json`（Linux / macOS），只让自己能读。

## 1. 只在本机用（最简单）

```bash
python3 aw_panel.py
```

浏览器打开 `http://127.0.0.1:8765`。只监听本机时可以不设密码。

## 2. 家里常开的电脑 / NAS / 树莓派 + Cloudflare Tunnel（推荐）

不需要公网 IP，路由器不用开端口，自带 HTTPS。

1. 在 Cloudflare 添加你的域名。
2. 安装 `cloudflared`：<https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/>
3. 登录并创建隧道：

```bash
cloudflared tunnel login
cloudflared tunnel create aw-panel
cloudflared tunnel route dns aw-panel panel.你的域名.com
```

4. 新建 `~/.cloudflared/config.yml`：

```yaml
tunnel: aw-panel
credentials-file: /home/你/.cloudflared/<隧道ID>.json
ingress:
  - hostname: panel.你的域名.com
    service: http://127.0.0.1:8765
  - service: http_status:404
```

5. `keys.json` 保持 `"host": "127.0.0.1"`，并设置 `password` 与 hCaptcha（见第 5 节）。
6. 分别运行 `python3 aw_panel.py` 和 `cloudflared tunnel run aw-panel`，然后打开 `https://panel.你的域名.com`。

开机自启见第 4 节 systemd。

## 3. 免费云主机（如 Oracle Cloud 永久免费层）

1. 申请一台 Ubuntu 小虚机。
2. 安全组 / 防火墙**不要**开放 8765 端口。
3. 上传项目，按第 2 节装 Cloudflare Tunnel；或者用 Caddy / Nginx 反向代理 + HTTPS。
4. 建议把配置放在环境变量里，不落盘：

```bash
export AW_PANEL_CONFIG='{"accounts":[{"name":"main","key":"..."}],"password":"...","hcaptcha_sitekey":"...","hcaptcha_secret":"..."}'
```

## 4. 用 systemd 开机自启（Linux）

`/etc/systemd/system/aw-panel.service`：

```ini
[Unit]
Description=Agent Wilds Panel
After=network-online.target

[Service]
User=你的用户名
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

如需把密钥放到单独文件：`EnvironmentFile=/etc/aw-panel.env`（权限 600），里面写 `AW_PANEL_PASSWORD=...` 等。

## 5. 配置 hCaptcha

1. 到 <https://dashboard.hcaptcha.com> 注册，添加站点，填你的域名（本地测试可加 `localhost`）。
2. 复制 **Sitekey** 和账户设置里的 **Secret**。
3. 写入 `keys.json`：

```json
"hcaptcha_sitekey": "你的 sitekey",
"hcaptcha_secret": "你的 secret"
```

或环境变量 `AW_HCAPTCHA_SITEKEY` / `AW_HCAPTCHA_SECRET`。

4. 重启面板。登录页会出现人机验证；服务器向 `https://api.hcaptcha.com/siteverify` 校验通过后才比对密码。两个值缺一个时不启用。

本地测试可用 hCaptcha 官方测试密钥：sitekey `10000000-ffff-ffff-ffff-000000000001`，secret `0x0000000000000000000000000000000000000000`（任何人都能通过，**正式环境不要用**）。

## 6. Docker

```bash
docker build -t aw-panel .
docker run -d --name aw-panel --restart unless-stopped \
  -p 127.0.0.1:8765:8765 \
  -e AW_PANEL_CONFIG="$(cat keys.json)" \
  aw-panel
```

注意：在容器里要监听 `0.0.0.0` 才能被端口映射访问，所以配置里写 `"host": "0.0.0.0"` 并必须设置密码；`-p 127.0.0.1:8765:8765` 保证宿主机只在本机暴露，再用 Tunnel 对外。

## 6.5 Wasmer Edge（免费托管，无需自己的服务器）

Wasmer Edge 能直接跑 Python 程序，自带 HTTPS。仓库里的 `cacert.pem` 就是为它准备的（Wasmer 的 Python 运行环境没有系统根证书）。

**1. 准备目录**（Wasmer 的 Python 预设要求入口是 `src/main.py`）：

```bash
mkdir aw-wasmer && cd aw-wasmer && mkdir src
cp ../aw_panel.py src/main.py
cp ../bg.jpg ../cacert.pem src/
```

**2. 新建 `app.yaml`**（`owner` 换成你的 Wasmer 用户名，`name` 自取）：

```yaml
kind: wasmer.io/App.v0
name: agent-wilds-panel
owner: YOUR_WASMER_USERNAME
package: .
env:
  AW_NO_BROWSER: "1"
  HOST: "0.0.0.0"
  # 绑定自定义域名后再打开下面两行（见第 5 步）
  # AW_ALLOWED_HOSTS: "panel.example.com"
# domains:
#   - panel.example.com
```

不要把 key 或密码写进 `app.yaml`。

**3. 安装 CLI 并部署**：

```bash
curl https://get.wasmer.io -sSfL | sh      # Windows 见 wasmer.io 文档
wasmer login                               # 或设置环境变量 WASMER_TOKEN
wasmer deploy --non-interactive --build-remote
```

部署完成后会给出 `https://<name>.wasmer.app` 地址。

**4. 在 Wasmer 后台设置 Secrets**（App → Settings → Secrets），然后点 **Redeploy** 才会生效：

| Secret | 内容 |
|---|---|
| `AW_PANEL_CONFIG` | 整段 `keys.json` 内容（必须是合法 JSON，只粘贴一个 `{...}`，不要混入示例文字） |
| `AW_PANEL_PASSWORD` | 登录密码（公网必填） |
| `AW_HCAPTCHA_SITEKEY` / `AW_HCAPTCHA_SECRET` | 可选，开启 hCaptcha |

也可以用命令行：`wasmer app secret create --app YOUR_WASMER_USERNAME/agent-wilds-panel AW_PANEL_PASSWORD '长密码'`，之后重新 `wasmer deploy`。

看日志确认账号都读到：`wasmer app logs YOUR_WASMER_USERNAME/agent-wilds-panel`，应出现 `accounts / 账号: ...`。若报 `Extra data` 之类，说明 `AW_PANEL_CONFIG` 不是合法 JSON。

**5. 绑定自己的域名（可选）**

1. 在 `app.yaml` 的 `domains` 里加上域名，重新部署。
2. 到 DNS 服务商加一条 CNAME：`panel` → `<name>.wasmer.app`。用 Cloudflare 时要设为 **仅 DNS（灰云，不代理）**，否则 Wasmer 无法签发证书。
3. 等几分钟后用 `https://panel.example.com` 打开。

**只允许自定义域名访问**：设置环境变量 `AW_ALLOWED_HOSTS`（逗号分隔，可写多个），面板会对其他域名（包括 `*.wasmer.app`）一律返回 404。确认自定义域名能打开后再开启，否则会把自己锁在外面。

**更新**：替换 `src/main.py` 后重新 `wasmer deploy --non-interactive --build-remote`。

## 7. 安全清单

- [ ] `keys.json` 权限 600，没有提交到 Git。
- [ ] 面板只监听 `127.0.0.1`，云主机防火墙没开 8765。
- [ ] 通过 HTTPS 访问（Tunnel 或反向代理），Cookie 会自动加 `Secure`。
- [ ] 设置了长密码和 hCaptcha。
- [ ] 每个游戏账号使用独立的 API key；怀疑泄露时在游戏里重新生成，再更新配置并重启。
- [ ] 钱包私钥不在这台机器上。

## 不推荐

- GitHub Pages / Netlify 等纯静态托管：没有后端，key 只能放在前端，等于公开。
- 直接把 8765 端口开到公网、只靠密码。
- 来路不明的免费内网穿透工具。
