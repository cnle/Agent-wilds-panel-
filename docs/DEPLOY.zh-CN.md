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
