# intent/dsh.md 的补充：手机远程方案选型对照（2026-10-12）

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
