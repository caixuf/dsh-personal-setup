# 公网入口复刻 —— VPS 侧（FRP + Caddy）

> 配套文件：`templates/dsh/frps.toml`、`templates/dsh/caddy/dsh-mobile.caddy`、`scripts/provision-vps.sh`
> 客户端侧见 `templates/dsh/frpc.toml`（家里电脑用）。

## 数据流

```
手机 App ──HTTPS 2444──▶ Caddy（TLS + 路径白名单）
                              │  只放行 /mobile-gateway/{health,login,pair,api/*,remote.mux}
                              │  管理面 /manage* 显式 404
                              ▼
                        127.0.0.1:2443  ← frps 分配，**只绑回环**
                              │  FRP 隧道（tls.force）
                              ▼
                     家里电脑 frpc ──▶ DSH 127.0.0.1:19387
```

## 一条命令架设新 VPS

```bash
FRP_TOKEN='<你的令牌>' VPS_IP='<VPS公网IP>' bash provision-vps.sh
```

脚本做六件事，幂等可重跑：
1. 装 frps（默认 0.71.0）
2. 写 `/etc/frp/frps.toml`（权限 600）
3. 注册 + 启动 `frps.service`
4. 写 Caddy 站点配置，**validate 通过才 reload**
5. ufw 放行 7000 / 2444 / 80 / 443，**不放行 2443**
6. 打印下一步清单

只读自检（不改任何东西）：

```bash
bash provision-vps.sh --verify
```

## 🔴 三个安全设计，一个都不能少

### 1. `allowPorts = [{ single = 2443 }]`
只允许分配 2443 这一个远端端口。

**为什么**：frpc 客户端可以指定 `remotePort`。不限制的话，任何能连上 7000 端口的人都能让你的 VPS 变成开放代理。

### 2. `proxyBindAddr = "127.0.0.1"`
隧道端口**只绑回环**，公网侧直接连 2443 会失败，只能经 Caddy 进。

**为什么**：这一条比 allowPorts 更重要。它让 2443 在公网上"根本不存在"，攻击面直接归零。uff 也不要放行 2443。

### 3. `transport.tls.force = true`
强制 frp 链路加密，否则 `auth.token` 会被嗅探。

## 🔴 最容易漏的一环：管理面必须在 Caddy 挡掉

DSH 的 `/api` **没有认证层**，只有一道 Host/Origin 栅栏。而经过 FRP 隧道后，DSH 看到的对端是 `127.0.0.1`（frpc），于是「回环才算本地」这个判断**被隧道抹平了** —— 网关自己的回环闸门会误判公网请求为本地请求。

所以 `/mobile-gateway/manage*` 只能由 Caddy 在最外层显式 404：

```
handle /mobile-gateway/manage* { respond "Not Found" 404 }
```

改白名单时**千万别把这行删掉**。

## 换 VPS 时按这个顺序排查

| 症状 | 先查 |
|---|---|
| 手机连不上 | `bash provision-vps.sh --verify` → ufw 7000/2444 是否放行；**云厂商安全组**也要放 |
| 某个功能 404 | Caddy 白名单少路径了（对照上面 `handle` 列表） |
| 隧道连上但没流量 | frpc 的 `remotePort` 与 frps 的 `allowPorts` 不一致 |
| 证书签不下来 | IP 证书只能走 HTTP-01，主 Caddyfile 里要有按 IP 匹配的 `:80` 块 |
| 管理面板 404（**正确行为**） | 这是设计如此，见上文第 3 条 |

## 云厂商安全组（VPS 内层之外）

ufw 只是第一层。腾讯云 / 阿里云等控制台的**安全组**也要单独放行：
- `7000/tcp`（frp bindPort）
- `2444/tcp`（Caddy）
- `80/tcp`、`443/tcp`（ACME + 你自己的站点）

**不要**放行 2443。

## 相关

- 客户端配置：`templates/dsh/frpc.toml`
- 完整换机流程：`intent/新机器复刻清单.md`
- 协议与安全模型细节：`dsh-native-mobile/docs/public-access.md`
