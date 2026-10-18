# intent/dsh.md 的补充：手机远程方案选型对照（2026-10-12 首记，2026-10-16 更新）

> 这份是**选型记录**，防止下次再一个个搜、再一个个踩兼容性坑。

## 需求

手机（Android）远程操控电脑上的 DSH 会话。

## 候选全景（npm 实际搜索结果，2026-10-12）

搜 `dsh remote` / `dsh phone` / `dsh android` 得到 20+ 个包。按**兼容性**筛掉之后只剩两个安全：

| 包 | 版本 | peer 锁 0.1.x | 判定 |
|---|---|---|---|
| **`@linxin666/dsh-remote-web-ui`** | 0.4.6 | **0 个**（peer 只有 `@deepseek-ai/dsh >=0.2.0-rc.2`） | ✅ **已装** |
| **`@xmanrui/dsh-im`** | 4.38.1 | **0 个**（零 peer） | ✅ 待评估 |
| `dsh-mobile` | 0.6.4 | 0 个（peer 全 `*`/optional） | ⚠️ 能装但**五道坎没修**（见下） |
| `dsh-wechat-plugin` | 0.39.3 | **1 个** | ❌ 会崩 |
| `@eternalloveone/dsh-palm` | 1.5.4 | **2 个** | ❌ 会崩 |
| `@michengai/dsh-im-connect` | 0.1.74 | **6 个** | ❌ 会崩 |
| `dsh-public-proxy` | 0.3.0 | **2 个** | ❌ 会崩 |
| `deepseek-harness-weixin` | 0.2.5 | 依赖 `dsh-credentials-local@0.1.0-rc.7` | ❌ **已装过，把 DSH 搞崩了** |
| `@mrrisega/dsh-remote` | 0.7.0 | 0 个但**无 dsh 字段** | ⚠️ 非 DSH 插件，形态不明 |
| `dsh-remote` / `dsh-remote-plugin` / `dsh-remote-bridge` 等 | — | — | SSH / 办公向，非手机 |

> 🔴 **这张表就是 `conventions.md` 第十一条纪律的价值** ——
> `dsh-wechat-plugin` 描述写着「No OpenClaw and no public IP required」，
> 看上去完美，**但 peer 锁 0.1.x，装上就崩**。不看 peer 细节 = 白折腾。

## 选型结论

| 需求 | 方案 |
|---|---|
| **手机浏览器操控同一套 DSH 界面** | ✅ **`@linxin666/dsh-remote-web-ui`** —— 「共享同一份界面」，不是第二套 |
| 聊天软件里发消息 | ✅ `dsh-bot-gateway`（Telegram 通道，**无需公网 IP**） |
| 微信通道 | ❌ 现有 `deepseek-harness-*` 全锁 0.1.x，**等作者适配 0.2.0** |
| 全平台 IM（微信/飞书/QQ/TG/WhatsApp…） | `@xmanrui/dsh-im`（零 peer，20 MB，未评估） |

**三条并存不冲突**：`remote-web-ui`（主）、`dsh-bot-gateway`（备用/通知）、
`dsh-mnemon`（记忆）。

## `dsh-mobile` 0.6.4 为什么仍不推荐（2026-10-12 复核）

新版本（今天发布）修了输入栏溢出、Windows 启动期 picker 冲突、配对码输入体验、
证书/Caddy/ETag 一堆可靠性，Android App 升到 0.6.3。

**但上次卡住你的五道坎，一道没修**：

| 坑 | 0.6.4 |
|---|---|
| ① CLI `ERR_MODULE_NOT_FOUND`（`@deepseek-ai/cordis` 是 optional peer 且未装） | ❌ 未提 |
| ② Client 一半要重启才加载 | ❌ 未提 |
| ③ 出厂只绑 `127.0.0.0/8` | ❌ 未提 |
| ④ 防火墙诊断误报 | ❌ 未提 |
| ⑤ 管理 API 的 POST 要 cookie | ❌ 反而更严（多处强调 requires administrator approval） |

**且作者自己承认**：

> the reported community Desktop 2.0.17 failure and remote timeout
> **still require acceptance in that environment**

## `@linxin666/dsh-remote-web-ui` 的关键机制

**为什么它比 dsh-mobile 顺**（都做到了但实现方式不同）：

| | dsh-mobile | remote-web-ui |
|---|---|---|
| CLI | ❌ 坏掉 | **不需要** |
| 初始化 | ❌ 手调管理 API | **面板点一下** |
| 防火墙 | ❌ 只会误报 | ✅ **自动维护放行规则**（`firewall.js`） |
| 网卡 | ❌ 手填 | ✅ **自动探测**（`lan.js: lanIPv4Addresses()`） |
| 写配置 | ❌ 手工 | ✅ **自己写 patch 绑定块** |
| 状态反馈 | 模糊诊断 | ✅ **精确状态码** |

**入口位置（易踩）**：

- **面板**（侧栏底部、设置按钮旁的**手机图标**）→ 只有状态 + 二维码 + 设备列表
- **设置卡片**（**设置 → 插件 → 远程访问**）→ **开关在这里**

⚠️ 面板里那个只是看状态的，**「局域网访问（绑定 0.0.0.0）」开关在设置卡片里**。

**开完要重启 DSH 才生效**（它会往 `cordis.patch.yml` 写一个
`# --- remote-web-ui lan-bind block (managed - do not edit) ---` 块）。

**排障端点**：

```powershell
GET /api/pair/status
# → {"phase":"lan-required"|"paired", "lanAvailable":bool, "lanAddresses":[...], ...}
```

`lanAvailable:false` / `lanAddresses:[]` = 局域网开关没开。

---

## 2026-10-13 定型 · 2026-10-16 更新现状：自研原生移动端 dsh-native-mobile（终极方案）

> 开源仓库：[github.com/caixuf/dsh-native-mobile](https://github.com/caixuf/dsh-native-mobile)
> 本地工作区：`C:\Users\20247\Downloads\aiwork\dsh-native-mobile`

### 现状（2026-10-16 收工时，tag `v1.3.2`）

当天连发 7 个 tag（`v1.0.6` → `v1.3.2`），从「能连上」推进到「能日常用」：

| 版本线 | 内容（按各 tag 的 release note） |
|---|---|
| v1.0.x | 配对、会话列表、遥控与审批中继（Android 前台服务） |
| v1.1.0 | 全新浅色界面（MiniMax 风格）+ 个人中心 + 对比度全面达标 |
| v1.1.1 | 会话列表与分组视觉重构 + 工作区切换器 |
| v1.2.0 | 主题 / 皮肤中心 —— 四套配色一键切换 |
| v1.3.0 | 浅色主题 5 处「浅色字 + 浅色底」（实测 1.27:1 ~ 2.37:1，肉眼不可读）；待办挂住不消失；皮肤切换无效；**演示主机抢占真实主机位** |
| v1.3.1 | 键盘弹起时输入坞悬浮到屏幕中间 + 顶栏透明导致内容穿帮 |
| v1.3.2 | 自定义壁纸设了没反应（屏幕根节点不透明白底把壁纸全盖住） |

**分发现状**：APK 用 **debug 密钥**签名（可覆盖安装，**不适合上架分发**），
`minSdk 26`（Android 8.0）。发布节奏 = **每项修复一个 tag + 一个 Release**。

> ⚠️ 本节此前只写到 2026-10-13 的 v1.0.x 形态 —— **查版本请以
> `git tag` / Releases 为准**，本文的版本表是快照，会再次落后。

### 为什么从 Web UI 走向原生移动端
`remote-web-ui` 解决了手机浏览器访问问题，但手机浏览器存在根本局限：
1. 没有系统级通知与手势交互，无法提供沉浸式客户端体验。
2. 缺乏安全的长期设备凭据存储机制（无法使用 Android Keystore / EncryptedSharedPreferences）。
3. 依赖全量 Web 界面渲染，公网弱网环境下延迟高、开销大。

### 架构与核心规范
```
Android App (Kotlin/Compose) ──HTTPS/WSS──▶ Caddy (公网白名单) ──▶ FRP 隧道 (2443 回环) ──▶ DSH 宿主网关 (19387)
```
1. **宿主插件 `dsh-mobile-gateway`**：
   - 挂载在机器级 `cordis.patch.yml`（作为宿主插件，防止 profile 重建丢失）。
   - 单一 WebSocket Mux 模式：`/mobile-gateway/remote.mux` 承载 `$events` 流与 RPC 转发。
   - 安全模型：管理面 `/mobile-gateway/manage` 校验 `req.socket.remoteAddress` 仅限回环，
     特权方法（设置、文件系统全盘、插件管理）硬拦截。
     🔴 **但这条校验在 LAN 桥上会失效** —— 见下节「回环校验的漏洞」。公网侧不受影响
     （Caddy 白名单把 `/mobile-gateway/manage` 挡成 404）。

### 🔴 回环校验的漏洞（2026-10-18 实测并修复）

**现象**：从局域网机器访问，管理面连鉴权都没有就返回 200：

```
http://192.168.31.79:19387/mobile-gateway/manage            → 200, 12435 B
http://192.168.31.79:19387/mobile-gateway/manage/api/state  → 200, 17558 B
  body 含 99 个设备的 id/name/platform/lastSeenAt、credentials{username,passwordSet}、lanAddresses
对照组（宿主自身围栏是好的）：LAN /api → 403
```

**根因**：`manage.mjs` 的守卫是
`isLoopbackAddress(req.socket.remoteAddress)`（`lib/manage.mjs:349`），
而 `lan-bridge/dsh-lan-bridge.mjs` 是**本机 TCP 转发**（`net.connect(19387,'127.0.0.1')`）——
局域网来电经过它之后，`remoteAddress` **恒为 127.0.0.1**，守卫恒真。
**是桥把调用者身份抹掉了。**

**为什么不能靠改 Host 头校验**：Host 是调用方可控的。实测
`curl -H "Host: 127.0.0.1:19387" http://192.168.31.79:19387/...` 会被接受。

**修法（落在桥上，因为只有桥还知道请求来自外部）**：
`dsh-lan-bridge.mjs` 在转发前嗅探请求行，命中 `/mobile-gateway/manage` 前缀
（含 `/manage/...`、大小写变体、绝对 URL 形式）直接回 403
`{"error":{"code":"lan_bridge_blocked"}}`，不建上游连接。

**验证**：

| 请求 | 修复前 | 修复后 |
|---|---|---|
| LAN `/mobile-gateway/manage` | 200 | **403** |
| LAN `/manage/api/state` | 200 | **403** |
| 本机回环 manage（桌面面板） | 200 | 200 |
| LAN 手机 App `/api/*` | 401 | 401（仍转发） |
| 公网 VPS `/manage` | 404 | 404 |

> 📌 **可复用教训**：任何「只允许本机」的校验，在**代理/转发/隧道**后面都会失真。
> 加一层转发就等于把所有调用者伪装成本机 —— 围栏必须建在**能看见真实来源的那一跳**。
> 这条同样适用于 `netsh portproxy`。

2. **原生 Android App**：
   - Kotlin 2.0 + Jetpack Compose + Material 3。
   - 对齐 DSH Web 客户端与 MiniMax 移动端设计语言，支持按电脑工作区（`cwd`）分组展示会话。
   - 原生支持流式富文本与审批/提问卡片。

