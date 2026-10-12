# intent/ecosystem.md — 生态调研结论（避免重复调研）

> 这份记录**调研过什么、结论是什么、为什么**。
> 目的：下次再看到这些名字，不用重跑一轮调研。
> **看名字眼熟但不确定时，先查这里。**

## oh-my-hermes（OMH）—— **不是 DSH 插件，装不上**

| 项 | 值 |
|---|---|
| 归属 | **Hermes Agent**（`NousResearch/hermes-agent` ★252,827）的插件 |
| 仓库 | `rlaope/oh-my-hermes` ★3,305（Python） |
| npm | `oh-my-hermes@3.0.2`，月下载仅 **1,527**（多数人从源码装） |
| CLI | `omh` |
| 规模 | **142 个 skill** + 22 个 src 模块 + 20 个 surfaces 文件 |

**为什么装不上**：DSH 和 Hermes 是**两个不同的 agent 框架**，插件格式、工具名、路径、agent 机制全不同。

**它的定位**（README 原文）：

> OMH 是 Hermes 原生 skill **之上的操作层**：框定问题、选择工作流和**证据门**，
> 并把原生 skill 作为能力运行在这条受治理的路径内。
> **从不替换 Hermes**，也不把编码执行器藏在后面。

### 三个维度对照（2026-10-12 实测）

| 维度 | oh-my-hermes | DSH | 谁更强 |
|---|---|---|---|
| **多 agent 编排** | `omh_agent_board` 单工具，只算 `native_action`，**自己从不执行**，委托给 Hermes 原生 Kanban | 官方 `dsh-experimental-agent-team`：**durable peer mailbox + 共享任务 DAG** | **DSH** |
| **编排的图形界面** | 无（靠 Hermes chat） | `dsh-experimental-client-ui-agent-team`：roster + task board + teammate 导航，**月下载 664,780** | **DSH** |
| **HUD / 状态展示** | 20 个 surfaces 文件（hud/menubar/show_shape/artifact） | Web GUI 原生 slot 体系；生态有 task-board（159,254/月）、dsh-context（147,041/月） | **DSH** |
| **skill 工程化** | 142 个 skill 共用一份 `skill-common-rail.md` | 无等价设计 | **OMH** |
| **证据边界契约** | `prepared_not_observed` / `not_observed` 词汇 + 裁决词表 | 无内置 | **OMH** |

**结论：功能上 DSH 不缺（且官方那套你已在用），值得学的只有「工程纪律」和「skill 组织方式」。**

### ✅ 已借鉴（2026-10-12）

`evidence-boundary` skill（见 `intent/dsh.md`）—— 借鉴其证据边界契约，改写为 DSH 原生。

### 📌 值得记住的三条工程纪律（写插件时用）

**1. 拒绝优雅降级**

> "an unavailable board is reported as **unavailable, not downgraded to delegation**"

看板不可用就报不可用。**降级会让上层以为拿到了 durable 协调，实际只是临时委托** ——
这与用户硬规则「看起来等价的开关实际不等价」是同一个道理。

**2. `prepared` ≠ `observed`，严格分离**

> "prepared context, **not execution evidence**"
> "executor lanes provide observed coding evidence **only after a separate runtime record exists**"

**3. 薄桥接，不越权**

> "OMH **never calls a native tool** from the handler."

它只返回「该调哪个工具、参数是什么」，由宿主走正常工具循环执行。

**反面案例**：`dsh-mobile`（已卸载）—— 自己起 TLS 服务、要动防火墙，属于越权设计。

### 💡 skill 组织方式（142 个 skill 不撑爆 token 的秘诀）

> "It is kept here **once instead of inside each `SKILL.md`** so an install does not pay
> the same bytes **88 times per turn**."

**共性抽到 `skill-common-rail.md` 一份，每个 skill 只写自己的差异。**

⇒ 本项目自建 skill 时遵循同一原则：**正文尽量短**（`evidence-boundary` 仅 ~2KB）。

---

## DSH 的图形化 / 多 agent 生态现状（备查）

### 多 agent（官方，已装）

| 插件 | 说明 |
|---|---|
| `@deepseek-ai/dsh-experimental-agent-team-profile` | ✅ 已装。profile bundle，启用 Agent Teams |
| `@deepseek-ai/dsh-experimental-agent-team` | Implicit-root roster + durable peer mailbox + 共享任务 DAG |
| `@deepseek-ai/dsh-experimental-client-ui-agent-team` | Web 端 roster / task board / teammate 导航 |

### 任务看板（社区，多个作者并存）

| 插件 | 月下载 | 备注 |
|---|---|---|
| `@linxin666/dsh-client-ui-task-board` | **159,254** | Host-authoritative |
| `@firetruck666/dsh-task-board` | — | 多列面板 |
| `@ukewea/dsh-taskboard` | — | 独立维护 |
| `@linsibin/dsh-task-board` | — | 加 kanban tab |
| `@mkaliezz/dsh-task-board` | — | evidence task board |
| `dsh-agent-board` | 5,661 | 任务卡片 + 一次性 W… |

⚠️ **同功能多作者并存**，选型时看下载量与维护活跃度，别只看名字。

### 状态/HUD 类

| 插件 | 月下载 | 说明 |
|---|---|---|
| `dsh-context` | **147,041** | 上下文洞察与管理 |
| `dsh-token-hud` | 527 | 实时 Token HUD（可拖拽） |
| `@linxin666/dsh-perf` | — | 性能观测与治理 |

---

## 浏览器能力（2026-10-12 实测）

> **这是能力升级，不是外观插件。** 补齐后 DSH 具备前端/后端工程师的完整开发闭环。

### ❌ 内置 Tabbit 浏览器：**无法使用**

| 项 | 状态 |
|---|---|
| `%LOCALAPPDATA%\Tabbit\LocalAgent\bin\tabbit-cli.exe` | ✅ 存在（2.67 MB，有 `tabs/claim/resume/nodejs/diagnose`） |
| **Tabbit 浏览器本体** | ❌ **未安装**（目录里只有 `User Data`，无 exe） |
| 进程 | ❌ 未运行 |

**结论**：CLI 只是"遥控器"，**遥控的电视没买**。
而且内置 skill 描述写的是 *"Control **the user's** Tabbit Browser"* ——
它**假定你自己装了 Tabbit**，不是 DSH 内置浏览器。**不要指望它。**

### ✅ 已装：`dsh-browser-cdp` 0.18.19（9,206/月）

**它是 ego-lite 的封装，自带运行时**（`runtime/` 37 个文件，含 `ego-browser` + `ego-linux`）。

**关键优势**：用**你已装的 Chrome**（`bcdp_doctor` 实测指向
`...\Google\Chrome\Application\chrome.exe`），**不下载新浏览器**。

**实测验证（2026-10-12，全绿）**：

| 能力 | 结果 |
|---|---|
| `bcdp_doctor` | ✅ `ok=true`，37 个 `bcdp_*` 工具 |
| 导航 | ✅ example.com → 自动跳 IANA，title 正确 |
| **语义快照** | ✅ 完整 DOM 树 + `ref=109` 可点击引用 |
| ref 读取 | ✅ `ref=109` → `"Instructions and Guides"` |
| **点击** | ✅ 跳转 `/help`，title 更新 |
| JS 执行 | ✅ 返回计算样式、链接列表 |
| **DOM/CSS 注入** | ✅ 注入粉红块，`getComputedStyle` 正确 |
| **截图** | ✅ 视觉确认 "PROBE OK" 真实渲染，尺寸与 JS 计算一致 |
| 元素截图 | ✅ `#__probe` 精确截取 80×40 |

**对前端开发的意义**：快照定位元素 → 注入调试 → 截图验证视觉，
正是改样式/调布局的核心循环。**完全够用。**

**额外能力**：
- `bcdp_login_import` —— 从日常 Chrome/Edge/Brave **按域名导入登录态**
  （兼容 Chrome 127+ App-Bound Encryption，不做离线解密）
- **实时观察窗**（SSE 推流 + 鼠标直控），能看着 agent 操作并随时接管
- 未装 `dsh-better-sidebar` 时自动回退为右下角**浮动观察球**

⚠️ 已知：`bcdp_doctor` 报 `judge laya: key=MISSING`（视觉判断链路未配置）。
**不影响**上述 CDP 能力，那些是纯 CDP 操作。

### 其他候选（备查，未装）

| 插件 | 月下载 | 说明 |
|---|---|---|
| `dsh-ego-browser` | 4,332 | 同源（`Fisfzy/dsh-ego-browser`），30+ `ego_*` 工具 + SSE 画面 |
| `@caob23/dsh-browser-control` | 2,166 | Chrome 扩展 + 插件，操控真实浏览器 |
| `dsh-browser-tool` | 958 | 从 **oh-my-pi 移植**，支持 headless/CDP/真实 Chrome |
| `dsh-playwright-browser` | 1,053 | Playwright 语义多标签 |
| `dsh-agent-browser` | 396 | 基于 **Vercel agent-browser** 的封装 |

**上游对比**：`vercel-labs/agent-browser` ★43,831、npm **767 万/月**（Rust）；
`citrolabs/ego-lite` ★17,139 但**无 npm 包**（从源码装）。
⚠️ **DSH 侧的封装下载量都偏低**（最高 9,206/月），尚无事实标准。

---

## 壁纸 / 外观（2026-10-12）

### 已装：`dsh-wallpaper-bg` 0.5.12（3,289/月）

**选它的理由**：**peer 只有 `react`** —— 依赖最干净，不捆绑额外插件
（对比 `dsh-any-background` 需要 `dsh-better-sidebar`）。

**能力**：
- 内置 **10 张 Unsplash 高清图**
- **本地自定义图片 / 视频上传**
- **只读接入本机 Wallpaper Engine 壁纸库**（视频/网页壁纸原生渲染）
- 「同步桌面壁纸」模式（只读跟随当前桌面）
- **浅色外观自动铺半透明白雾、深色自动压暗** → 保证界面细字始终清晰
- 主页面标题区有「**原生背景**」开关：一键清掉雾层/遮挡
- 壁纸层与桌面 Wallpaper Engine **完全独立**（在 DSH 换壁纸不动你的桌面）

**入口**：
- `settings.section` —— 设置页面板
- `conversation.header.leading` —— 主页面开关（空白首页与会话页都可见）

**为什么选它而不是 skin-center**：用户明确说「**不需要花哨皮肤，能换壁纸就很舒服**」。
`@linxin666/dsh-client-ui-skin-center` 是整套皮肤系统（且会覆盖通用外观设置，见 `dsh.md`），
`dsh-wallpaper-bg` 只做壁纸这一件事。

### 其他候选（未装）

| 插件 | 月下载 | 特点 | peer |
|---|---|---|---|
| `dsh-background-by-model` | **8,159** | 按模型配不同壁纸 + 布局模式 | 6 |
| `dsh-any-background` | **7,273** | 颜色轮 + 透明度/模糊 + 主界面/设置界面分开调 | 6（含 `dsh-better-sidebar`） |
| `dsh-wallpaper-rotator` | 177 | 定时轮换 + 交叉淡入 | **0** |
| `@frog755/dsh-wallpaper` | 770 | 图片 + 本地压缩 MP4 | 6 |
| `@baiiii/dsh-wallpaper-local` | 185 | Wallpaper Engine/Steam 选择器 | 2 |

---

## 调研方法（下次照做，省时间）

1. **npm registry API**（`registry.npmjs.org/<pkg>`）—— 拿版本、peer、描述
   ⚠️ `web_search` 在本机不可用（无 `DEEPSEEK_API_KEY`），用 `Invoke-RestMethod`
2. **npm 下载量**（`api.npmjs.org/downloads/point/last-month/<pkg>`）—— **判断真实采用度**
3. **GitHub API**（`api.github.com/repos/<owner>/<repo>`）—— 拿 ★、更新时间、结构
4. **看 `description` 里的关键词**：出现 Hermes / Claude / Codex 等**别的框架名**时，
   先确认是不是**跨框架插件**（大概率装不上）
5. **查 peer 数量** —— peer 越少越好装、越不容易牵连额外插件
6. **装完必须实测**（`bcdp_doctor` 这类自检 + 真实操作），
   **`fiberPhase: active` 不等于能用** —— 内置 Tabbit 就是 active 但浏览器根本没装

**关键判据**：GitHub ★ 高 ≠ npm 下载高。OMH 就是 ★3,305 但 npm 仅 1,527/月
（用户从源码装）。**两个数据都要看。**
