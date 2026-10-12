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

## 调研方法（下次照做，省时间）

1. **npm registry API**（`registry.npmjs.org/<pkg>`）—— 拿版本、peer、描述
   ⚠️ `web_search` 在本机不可用（无 `DEEPSEEK_API_KEY`），用 `Invoke-RestMethod`
2. **npm 下载量**（`api.npmjs.org/downloads/point/last-month/<pkg>`）—— **判断真实采用度**
3. **GitHub API**（`api.github.com/repos/<owner>/<repo>`）—— 拿 ★、更新时间、结构
4. **看 `description` 里的关键词**：出现 Hermes / Claude / Codex 等**别的框架名**时，
   先确认是不是**跨框架插件**（大概率装不上）

**关键判据**：GitHub ★ 高 ≠ npm 下载高。OMH 就是 ★3,305 但 npm 仅 1,527/月
（用户从源码装）。**两个数据都要看。**
