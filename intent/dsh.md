# intent/dsh.md — DSH（DeepSeek Harness）个性化配置

## 这是什么

DSH 桌面端的插件组合与外观配置。共 **17 个 bundle**，全部经验证 `fiberPhase: active`。
（曾装过 `dsh-mobile`，因 CLI 损坏 + 流程繁琐**已卸载**，踩坑记录见下方「dsh-mobile」一节 —— 新机**不要装**。）

另有 1 个**宿主插件** `dsh-bot-gateway`，**不挂在 profile 而挂机器级 patch**
（`~/.dsh/cordis.patch.yml`），见其专节 —— 换机时别漏了这一处。

## 约束（AI 必读）

| 项 | 值 | 说明 |
|---|---|---|
| DSH 版本 | **`0.2.0-rc.2`** | 插件 peer 窗口极窄，**不要**装到此版本之外 |
| 内置 Node | **v24.21.0** | 来自 `runtime/primary-runtime/dependencies/node` |
| profile 名 | **`desktop`** | 路径 `~/.dsh/profiles/desktop/` |
| 形态 | **Desktop 便携版** | 官方依赖在 `app.asar` 内，**不存在** `~/.dsh/profiles/node_modules` |

## 插件清单与用途

| bundle | 用途 | 备注 |
|---|---|---|
| `@deepseek-ai/dsh-base` | 官方核心 | 必需 |
| `@deepseek-ai/dsh-web-app` | Web 界面层 | 必需 |
| `dsh-our-free-model` | 免费模型接入 | ✅ 用 **npm 版**（`dsh-our-free-model@^2.1.0`）；本机已于 2026-10-12 从旧机 `file:` tgz 切到 npm |
| `dsh-wsl-tool` | WSL 命令/路径/环境工具 | 注册 `wsl`/`wsl-path`/`wsl-env`/`wsl-doctor` |
| `dsh-wsl-workspace` | 会话执行环境落地 WSL | **本地 fork，基线 0.7.5** —— WSL 用户级 skill 可见（61 个）。见「WSL 用户级 skill fork」 |
| `dsh-wsl-workspace-picker` | 目录选择器直达 `/mnt/*` | |
| `dsh-whale-girl-pet` | 鲸鱼娘桌宠 | ⚠️ 见下方「桌宠脆弱性」。**独立插件，不依赖皮肤中心** |
| `dsh-theme-studio` | 主题/配色 | 12 预设 + 深色对比度守护（亮度 < 0.18 自动提亮）。见「外观插件教训」 |
| `dsh-terminal-panel` | 主栏全尺寸终端 | 最多 12 标签，刷新回放 256KB |
| `@anionex/dsh-eye-care` | 暖色护眼主题 | 明暗双套，不劫持 Appearance |
| `@weibaohui/dsh-sync` | 多机同步/备份 | Git + WebDAV + 本地文件夹三协议 |
| `dsh-mnemon` | 长期记忆 | 附带 **10 个子行**（2 主行 + 3 source + 5 strategy；其中 4 个 strategy 默认禁用） |
| `@linxin666/dsh-client-ui-skill-explorer` | **skill 管理中心** | 补内置缺口：GUI 里按来源浏览/启停/增删 skill。见「Skill 加载机制」 |
| `@deepseek-ai/dsh-experimental-agent-team-profile` | **Agent Teams**（官方实验） | 多 teammate 协作、共享任务板。本会话正在使用 |
| `@deepseek-ai/dsh-experimental-voice-input-bundle` | **语音输入**（官方实验） | ⚠️ **只有输入（STT），没有输出（TTS）** —— 做不了「像语音通话那样对话」 |
| `dsh-browser-cdp` | **浏览器自动化**（能力级） | 用**你已装的 Chrome**，**38 个** `bcdp_*` 工具。见 `ecosystem.md` |
| `dsh-wallpaper-bg` | **壁纸**（外观） | 只做壁纸，peer 仅 `react`。见 `ecosystem.md` |
| `dsh-mobile` | 手机远程操控 DSH | ❌ **已卸载**，见下方专节（新机不要装） |

### ⚠️ 包装错名陷阱（曾踩过）

**`dsh-sync` ≠ `@weibaohui/dsh-sync`**，是两个完全不同的包：

| 包 | peer 情况 | 结果 |
|---|---|---|
| `dsh-sync`（无 scope） | 14 个 peer 全锁 `0.1.0-rc.6` | ❌ 被兼容性门禁拒绝 |
| **`@weibaohui/dsh-sync`** | **无 peer** | ✅ 可装 |

后者才是本仓库使用的包。同类陷阱：生态里有多个同名/近名包（`dsh-doctor` 就有 5+ 个
不同作者版本，下载量悬殊）。

### ❌ 装不上的包（peer 版本窗口过窄）

| 包 | 不兼容原因 |
|---|---|
| `dsh-kb-rag` 1.6.7 | peer `@deepseek-ai/dsh-tools: ^0.1.0-rc.6` —— 语义化版本下 `^0.1.x` **不含 `0.2.x`** |

**用户决定暂不装**。若日后需要本地知识库，兼容替代品：

| 替代 | peer | 能力 | 差距 |
|---|---|---|---|
| `dsh-knowledge-base` | 全 `*` | 导入 md/txt/json/**docx/pdf** + FTS5 + 管理 UI | 无向量检索 |
| `dsh-context-milvus` | `^0.2.0-rc.1`（**精确匹配**） | Milvus 语义代码搜索 | 面向代码而非文档 |

⚠️ 两者都**没有** `dsh-kb-rag` 的「混合检索 + 交叉编码器重排 + 页码级引用」，属降级替代。

## ❌ `dsh-mobile`（手机远程操控）—— **已卸载，新机不要装**

**版本**：曾装插件 `0.6.3`（npm `dsh-mobile`）+ Android App `0.6.2`（要求 Android 10+）。

**状态（2026-10-12 复核）**：插件**已完全卸载** —— `package.json`、`bundles`、
`pnpm-lock.yaml`、`node_modules`、`cordis.patch.yml` **五处均无残留**。
`~/.dsh/mobile-access/` 目录已删除，端口 3443 **未监听**，局域网**未暴露**。

> 下文保留完整踩坑记录，供**将来官方修好后**重装时参考，避免重走一遍。

### 为什么卸载

不是装不上，是**流程太别扭**，五道坎要人工跨（详见下「踩坑清单」）。
用户原话：「还是不行啊，好麻烦，算了吧，等官方搞」。

### 🔴 踩坑清单（重装前必读，可省一轮折腾）

| # | 坑 | 事实 |
|---|---|---|
| 1 | **Client 一半要刷新才加载** | 装完立刻点「移动访问」没用。必须**重启 DSH**，诊断面板才会出现 |
| 2 | **CLI 是坏的** | `dsh-mobile setup` 报 `ERR_MODULE_NOT_FOUND: @deepseek-ai/cordis`。该包在 `peerDependenciesMeta` 标了 `optional` 且**实际未装** → README 让你跑 CLI，但**本机跑不通**，只能走 GUI 或管理 API |
| 3 | **出厂只绑回环** | `cordis.patch.yml` 默认 `initiallyEnabled: false` + `allowedCidrs: [127.0.0.0/8]` → 手机**根本连不进来**，必须手动放开 |
| 4 | **防火墙诊断是误报** | 本机 Domain/Private/Public **三档全关**（见 `conventions.md`），「未允许读取防火墙状态」**不影响连接** |
| 5 | **管理 API 有会话门槛** | `GET /api/mobile-access/diagnostics` 免凭据；`POST lan/control` 要浏览器 cookie，脚本直连拿 **401** |

### ✅ 唯一走通的路：直接调管理 API

GUI 点不动 / CLI 跑不了时，用这个（已实测成功）：

```powershell
# 1. 看候选网卡（免凭据）
GET  http://127.0.0.1:19387/api/mobile-access/lan/setup
#    → {"configured":false,"networks":[{"name":"以太网","address":"192.168.31.79","recommended":true}, ...]}

# 2. 提交初始化（免凭据；configureFirewall:false 避免它去动防火墙）
POST http://127.0.0.1:19387/api/mobile-access/lan/setup
     {"confirm":true,"address":"192.168.31.79","configureFirewall":false}
#    → {"configured":true,"restartRequired":true,"pendingOrigin":"https://192.168.31.79:3443"}
```

请求**必须带** `Origin: http://127.0.0.1:19387` + `Sec-Fetch-Site: same-origin`，否则 403。

产物落在 `~/.dsh/mobile-access/`：`setup.json`（网卡 + 上游 `http://127.0.0.1:19387`）、
`control.json`、`tls/{ca,server-cert,server-key}.pem`、`tls/dsh-mobile-ca.cer`。

### 🔴 回滚（不玩了就这样收）

那句 `restartRequired: true` 意味着**重启后 3443 会在 `192.168.31.79` 上暴露**。
不玩了必须收回，两条都做：

1. `~/.dsh/mobile-access/control.json` → `{"version":1,"enabled":false}`
2. `cordis.patch.yml` 里**删掉**手工加的 `mobile-access` 段（`initiallyEnabled: true` / `listenHost: 0.0.0.0`）

> ⚠️ `listenHost: 0.0.0.0` 与插件自己生成的 `setup.json` 是**两套配置来源**，
> 冲突时行为未验证 —— 别两边都设。插件的 `setup.json` 才是权威配置。

### 附：手机装 APK（USB 已通）

```powershell
$adb = "C:\Users\20247\WorkBuddy\2026-09-13-17-45-46\.workbuddy\platform-tools\adb.exe"
& $adb devices -l                                    # 先确认是 device 不是 unauthorized
& $adb install -r "<apk 路径>"                        # → Success
& $adb shell pm list packages | Select-String dsh     # → io.github.sayach.dshmobile
```

**手机上要先开「USB 调试」**。不开时设备仍会以 **MTP** 出现（`VID_22D9&PID_2764`），
但 `adb devices` 是空的 —— 别以为没连上。**realme/OPPO 的 VID 是 `22D9`**：
`PID_2764` = 纯 MTP，`PID_2765` = MTP + ADB。

## ✅ `dsh-bot-gateway`（聊天软件当远程入口）—— 已装

**用途**：把 QQ（NapCat OneBot v11 / 官方机器人）/ Telegram / 飞书 / 钉钉 接成 DSH 的
**远程任务网关**。手机聊天里发条消息就能建任务、续聊、查进度、收交付物 ——
**这正是 `dsh-mobile` 没做成的事的另一条路**（见上一节）。

**包**：`dsh-bot-gateway@0.3.9-beta`，MIT，**零运行时依赖、零 peer**（不会撞 DSH 的窄 peer 窗口）。

### 🔴 挂载必须用**机器级** patch（换机必读）

这是本插件**最关键**、也最容易做错的一点。README 原文警告：

> 插件由组合树的**一行**组成（在 **`<dsh-home>\cordis.patch.yml` 机器级补丁层** ——
> 注意**不是** `profiles\<name>\cordis.patch.yml`：DSH Desktop 桌面壳在后端启动失败时会把
> 整个 `profiles` 目录隔离为 `profiles.broken-<时间戳>` 并重建，**profile 级补丁会随之丢失**；
> 机器级补丁不受影响，重启后始终生效）。

**所以本机是两处 patch 并存**，别合并：

| 文件 | 放什么 |
|---|---|
| `~/.dsh/cordis.patch.yml`（机器级） | `bot-gateway` 这一行 |
| `~/.dsh/profiles/desktop/cordis.patch.yml` | 其余所有 bundle 的配置 |

机器级那行的写法（零配置开箱即用，运行时数据默认落 `~/.dsh/bot-gateway/`）：

```yaml
- insert:
    - id: bot-gateway
      name: dsh-bot-gateway
      # config: { tasksRoot, statePath, settingsPath }  可选，默认 dsh-home/bot-gateway/
```

### ⚠️ 解析路径是 `<dsh-home>\node_modules\`，不是 profile 的

README 明确：浏览器半边从 **`<dsh-home>\node_modules\dsh-bot-gateway\`** 定位 `package.json`
（`profiles\<name>\node_modules` 只是"可放 junction 镜像保证 profile 解析稳定"）。

**本机做法**：`plugin_manager install_bundle` 只装到 `profiles/desktop/node_modules/`，
**需再复制一份到 `~/.dsh/node_modules/dsh-bot-gateway/`** 才能被机器级 patch 解析到。

### ⚠️ `install_bundle` 会报 `not-bundle` —— 不是失败

本插件是**宿主插件**（`main: ./index.mjs` + `dsh.client` 注入），**没有** `dsh.bundle.patch`，
所以 `plugin_manager install_bundle` 返回 `application: failed` / `error.code: not-bundle`。

**但 pnpm 其实已装成功**（输出 `added 1, done in 3.4s`）。判定与处理：

1. 确认包已落盘：`~/.dsh/profiles/desktop/node_modules/dsh-bot-gateway/`（27 个文件）
2. 复制到机器级 `node_modules`（见上）
3. 机器级 patch 加那一行 → **重启 DSH**

### 验证

```powershell
# 1. 启动自检日志（看板 404 时先看这个；后端 stderr 对桌面用户不可见）
Get-Content "$env:USERPROFILE\.dsh\bot-gateway\boot.log"

# 2. 浏览器半边自证端点（README 说外部无法靠探测 URL 验证注册，要用这个）
#    /bot-gateway/api/client

# 3. 设置页应出现「机器人网关」分区（slots: settings.section, order=5，内嵌 /bot-gateway/ iframe）
```

**看板**：📊 总览 ｜ 🐱 QQ 个人号（NapCat 安装/扫码/OneBot11）｜ 🤖 QQ 官方机器人 ｜
✈️ Telegram ｜ 🐦 飞书 ｜ 💬 钉钉 ｜ ⚙️ 通用设置。
**NapCat 一键安装 + 全部账号设置都在网页看板完成，无需改配置文件。**

> 💡 NapCat 走 **WSL2 内置运行，免 Docker**：插件把 Docker 镜像导入为 Windows 内置的
> WSL2 发行版并全程托管（本机已有 Docker 镜像时 `docker export` 复用，零下载）。
> 备选 docker 模式需已装 Docker Desktop。

### 桌面截图监控（值得一提的能力）

`desktopWatch.enabled: true` 后，用 **Electron desktopCapturer** 每 `intervalSec`（默认 60）秒
捕获全部显示器并主动推送；任意通道发 `/桌面` 立即现拍一张。**锁屏时抓的是桌面应用窗口画面**
（文件名带 `-L`），不是锁屏图。截图落 `bot-gateway/screen-shots/`，滚动保留最近 `keepLast`（默认 60）张。
支持免打扰时段（可跨零点）。

⚠️ 这项会把你的屏幕内容发到聊天软件 —— **按需开启，不用时关掉**。

## 外观取向（用户偏好）

来自多轮交互确认，**不要**改成别的：

1. **桌宠本体 `dsh-whale-girl-pet` 是独立插件**（不依赖任何皮肤系统）。
   ⚠️ 2026-10-12 已卸载 `skin-center`，`blue-fantasy` 皮肤随之消失，**这是可接受的**
   —— 用户明确说「不需要花哨皮肤」。若将来要恢复皮肤，**不要**用 `skin-center`
   （见「外观插件教训」），优先 `dsh-theme-gallery`（3,709/月）。
2. `ui-theme.preference` —— **当前实机值 = `light`**（`cordis.patch.yml`，`fontSize: 17`）
   ⚠️ **本文早期版本曾写「应为 `dark`」，那是 skin-center 覆盖时期的判断，现已作废。**
   `skin-center` 已于 2026-10-12 卸载，配置不再被回写，**以实机实际值为准**。
   🔴 **这是全机唯一「文档与实机直接对立」的配置项，未擅自更改** ——
   明暗是用户的视觉偏好，AI **不要**自己切。用户若想要 `dark`，
   去「设置 → 通用 → 外观」改，改完回来更新本行。
3. **背景遮挡由用户自行调节，AI 不要写死数值**：
   - 现在归 `dsh-wallpaper-bg` 管：`overlayOpacity`（默认 40）、`lightFog`（默认 55）
   - 用户按壁纸深浅自己拉到看得清为止
   - ⚠️ 别开壁纸插件的「原生背景」开关 —— 开了雾层就没了
4. eye-care 当前 `mode: off`，但保留（用户可自行启用暖色）
5. **用户原话**：「不需要花哨，能换壁纸就很舒服了」—— 别给ta塞一整套皮肤系统

### ⚠️ 已排除的插件（不要再装）

| 插件 | 排除原因 |
|---|---|
| `dsh-theme-whalegirl` | **独占式**：`colorScheme` 只有 light 一套 + 监听 `theme/change` 无条件回弹。导致暗色看不清、切换被劫持。**已卸载** |
| `dsh-plugin-ops-bundle` | 37 条警告全属误报（见下）。**已卸载** |
| `@linxin666/dsh-web-all` | 内含 skin-center，**与已装的重复挂载**会报错 |

## WSL 用户级 skill fork（2026-10-12）

> **状态：✅ 已装入并生效**（基线 `v0.7.5`，提交 `f1f30d2`）。
> 第一次基于 0.7.7 的尝试炸了并回滚，真因见下方「❌ 致命坑」。**重做方法：fork 0.7.5。**

### 问题（**装 fork 之前**的状态）

> ⚠️ 本节描述的是**问题本身**。该问题已由 fork 解决 —— 现状见下方「✅ 生效验证」。

WSL 里有 **61 个 skill**，但 DSH 开 WSL 会话时**只加载 5 个**（4 内置 + tabbit）：

```
/home/caixuf/.claude/skills/            ← 61 个（真实目录）
/home/caixuf/.agents/skills -> .claude/skills   ← 符号链接
```

**根因**：官方 `dsh-wsl-workspace` 的 `src/host/wsl-skills.ts` **只扫项目级**
（`<项目>/.dsh/skills`、`<项目>/.agents/skills`），**从不扫 WSL 用户级 `~/.agents/skills`**。

### 改动

仓库 `~/code/dsh-wsl-workspace`，**分支 `feat/wsl-user-skills-075`（基线 v0.7.5 = 97f0e82）**，提交 `f1f30d2`：

| 项 | 内容 |
|---|---|
| `src/host/wsl-skills.ts` | +172/−4 行（增删合计 176） |
| `lib/index.js` | 构建产物，**不入库**（`forks/` 只放源码）。重建靠 `npm run build` |
| `tests/wsl-skills.test.ts` | +85/−1 行（合计 86），Windows 侧 36/36 通过 |

- `USER_DSH_RANK=400` / `USER_AGENTS_RANK=500`（对齐 DSH 官方 5 级优先级）
- `resolveDistributionHome()` —— 经 `wsl.exe -d <distro> -- printenv HOME` 取真实 home
- `discoverUserSkillRoots()` —— **带符号链接回退**（本机 `~/.agents/skills` 就是链接）
- `discoverAllSkillRoots()` —— 合并项目级 + 用户级

端到端实测：WSL 侧 `~/.claude/skills` 发现 **61 个 skill**；
经 skill-explorer API 观察 `user-agents` 组为 **62 个**（多一个 Windows 侧写入的 `tabbit`）。
两个口径都对，别混用 —— 详见下方「✅ 生效验证」。

### ❌ 致命坑：0.7.5 → 0.7.7 **不是补丁升级**

装上 fork（基于上游 0.7.7）后，**所有 WSL 会话都打不开**：

```
resume failed for session "session-7029a315...": RemoteError:
Unknown agent preset: wsl-standard (gateway/internal)
```

**已排除是我的改动**：diff 只碰 `src/host/wsl-skills.ts`，preset/apply/materialize 零改动。
（此处原写「main 与 HEAD 的 `variantGeneration` 命中数都是 10」，该数字**已无法复现**，
且与下方表格的 0 / 4 冲突 —— 现已删除，以可复现的 npm 版本实测为准。）

**真因是版本跳级**。`wsl-standard` 不是内置的，是**插件启动时从内置 preset 派生**的；
上游 0.7.5 → 0.7.7 **重写了这套派生机制**：

| 符号 | 0.7.5（能跑） | 0.7.7（装上就崩） |
|---|---|---|
| `variantGeneration` | **0 处** | 4 处 |
| `agentPresets` | 15 处 | 19 处 |

新机制要配套的新配置，而 profile 里没有 → 派生不出 `wsl-standard` → 旧会话 resume 全挂。

⚠️ **这正是「能跑的配置别动」那条铁律要防的事**：小版本号 +N 不代表兼容。

### ✅ 当前安装形态

```
node_modules\dsh-wsl-workspace ──junction──> C:\Users\20247\Downloads\minimax_work\dsh-wsl-workspace-fork
package.json: "dsh-wsl-workspace": "link:C:/Users/20247/Downloads/minimax_work/dsh-wsl-workspace-fork"
版本 0.7.5   variantGeneration = 0   discoverUserSkillRoots = 2 处
```

WSL 侧 `~/code/dsh-wsl-workspace`（分支 `feat/wsl-user-skills-075`）是 git 源，
`minimax_work\dsh-wsl-workspace-fork` 是**运行副本** —— 改代码要两边同步：

```bash
# 1. 在 WSL 源仓改 src/
cd ~/code/dsh-wsl-workspace
# 2. 编译（必须 node >=24，0.7.5 的 engines 要求）
export PATH=$HOME/.n/bin:$PATH && node -v    # 需 v24
npm run build                                  # 末尾须打印 verify-lib OK
# 3. 同步到运行副本
tar --exclude=node_modules --exclude=.git -cf - . \
  | tar -C /mnt/c/Users/20247/Downloads/minimax_work/dsh-wsl-workspace-fork -xf -
# 4. 哨兵复核（见下）
```

### 🚨 装之前必查的哨兵

```bash
grep -c variantGeneration lib/index.js    # 必须输出 0
```

`variantGeneration` 是 **0.7.7 preset 派生机制的标志**，非 0 就是炸弹 ——
上一次整台 DSH 的 WSL 会话全挂就是它。

⚠️ **cherry-pick 时 `lib/` 会冲突**，如果图省事用 `--theirs`，会把 **0.7.7 的编译产物**
一起带进来（炸弹就是这么进的）。**正确做法**：

```bash
git checkout v0.7.5 -- lib/     # 先回到纯净基线
npm run build                   # 再重新编译（勿手工解冲突）
```

### 安装路径的三个坑（都踩过）

| 尝试 | 结果 | 原因 |
|---|---|---|
| `link:~/code/dsh-wsl-workspace` | ❌ `failed` | `~` 被解析成 `C:\Users\20247\code\...`，**目录不存在** |
| `link:\\wsl.localhost\Ubuntu-24.04\...` | ❌ `failed` | 反斜杠被吃成 `C:\wsl.localhost\...` → 坏 junction |
| `link:` Windows 工作区副本 | ✅ 能装上 | 先复制到 Windows 可访问路径 |

⚠️ 前两次失败**中途把能用的官方版卸掉了**（`Packages: -1`），且留下坏 junction。
**教训：每次 `install_bundle` 后先查状态再动下一步**，别连续试。

### 回滚方式（第一次回滚已验证有效）

```bash
# 1. package.json 里把 "link:..." 改回 "^0.7.5"
# 2. 删 junction（只删链接，别动目标目录里的真实文件）
# 3. plugin_manager install dsh-wsl-workspace
# 4. 重启 DSH
```

⚠️ 备份：`_profile-desktop-backup-20261012-143715-before-fork-075/`（`cordis.patch.yml`、`package.json`）

### 测试注意（两个坑，都会误导判断）

1. **用 `node --test`，不是 vitest。**
   `tests/wsl-skills.test.ts` 头部写明跑 `node --test`（Node >= 23.6 直接剥类型）。
   误用 `npx vitest run` 会报 **`No test suite found`** —— 看着像文件坏了，其实只是 runner 不对。

2. **Linux 下 34/36，那 2 个失败与改动无关。**
   失败项是路径分隔符差异：Linux 走 `posix.join` 产出 `/`，Windows 走 `path.join` 产出 `\`。
   **真实部署环境是 Windows，以 Windows 结果为准：36/36 全过。**

### 别做过的无用功

**不要**试图在文件系统层验证 `lib/` 的依赖解析。
`lib/` 只 import `@deepseek-ai/*`（peer，DSH 自己的 ModuleLoader 注入）+ Node 内置，
**不走 Node 标准解析** —— 查文件系统必然得出错误结论。
`js-yaml` 只是 `src/` 的 dev 依赖，编译后已内联，`lib/` 里根本 import 不到它。

**也不要**只凭 `fiberPhase: active` + `application: restart-required` 就宣布装好了 ——
第一次正是这两个信号全绿、测试全对、端到端 61 skill 全对，**运行时却整个 WSL 打不开**。
`restart-required` 的含义是**还没生效**，此时说"装好了"就是提前下结论。

**更不要**在 `install_bundle` 失败后直接试下一条路径 —— 失败会**中途卸掉能用的包**
（`Packages: -1`）并留下坏 junction。**每次操作后先查状态。**

## ⚠️ 外观插件教训：`skin-center` 已卸载（2026-10-12）

用户诉求是「**不同壁纸下字体可见度不同**」。折腾一圈的结论：

| 插件 | 为什么不行 |
|---|---|
| `@linxin666/dsh-client-ui-skin-center` | ❌ **已卸载**。设置项走 locale 本地化，中文界面找不到；注册处包了 `catch { return () => {} }` **静默失败**；且它是「皮肤系统」，与壁纸叠加反而更乱 |
| `dsh-theme-studio` | ✅ 当前采用。`ensureDarkContrast()` 在亮度 < 0.18 时自动提亮 |

**但要说清楚 theme-studio 也解决不了全部**：

- 它守的是**强调色**（按钮、选中态），**不是正文文字**
- 代码注释写明 *"never touches the DOM"*，只调 `ctx.theme.overrideTokens`
- `customCss` 的 `parseCustomCss()` **只接受 `--dsw-*` token 赋值**，塞 `text-shadow` 会被拒
- 它的对比度守护有**不对称 bug**（`apply.js` `resolveAccentPair`）：**只护深色，浅色裸奔**

**所以「壁纸全开 + 字全清楚」目前只能靠调 `dsh-wallpaper-bg` 的雾层**
（`overlayOpacity` 40→65~75、`lightFog` 55→75~85），这是插件自带正规设置，零改动。

**行业标准解法是 `text-shadow`**（Instagram/微信/B站 都用），但**本机没有零成本注入口**：
`cordis.yml` 无自定义 CSS 插件入口，`cordis-client-runner`/`client-hmr` 是新增机制。
真要做必须 fork 或写客户端模块 —— 属于改动宿主，**未做，谨慎评估后再做**。

### 卸载 skin-center 的副作用（已验证无害）

- **桌宠不受影响**：`dsh-whale-girl-pet` 是独立插件，`blue-fantasy` 皮肤目录随卸载移除，但桌宠本体 70/70 完好
- `~/.dsh/skin-center-active.json` 残留但 `active: null`，**无人读取，留着无害**
- 卸载后 `cordis.patch.yml` 的 `ui-skin-center` 块**需手动删**（`plugin_manager` 不清），已删并验证 YAML 可解析

## 安装步骤

```bash
# 1. 确认 DSH 版本为 0.2.0-rc.2（版本不符时先问用户，不要硬装）
dsh --version

#    ⚠️ Desktop 便携版**不一定把 dsh 放进 PATH**（实测新机就没有）。
#    找不到时二选一：
#      a) 直接用内置 CLI：
#         "%LOCALAPPDATA%\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd" --version
#      b) 读版本真值：
#         resources/runtime/primary-runtime/runtime.json  →  "desktopVersion": "0.2.0-rc.2"

# 2. 复制 DSH profile 配置（三件）
cp templates/dsh/package.json         ~/.dsh/profiles/desktop/package.json
cp templates/dsh/cordis.patch.yml     ~/.dsh/profiles/desktop/cordis.patch.yml
cp templates/dsh/pnpm-workspace.yaml  ~/.dsh/profiles/desktop/pnpm-workspace.yaml
#    ↑ 第三件容易漏。它含 nodeLinker: hoisted / autoInstallPeers: false，
#      不复制会导致 pnpm 装出来的目录结构不同。

# 3. 模板里的依赖形态（2026-10-12 已改，照抄模板即可）
#    ✅ dsh-our-free-model 现在是 npm 版："^2.1.0"
#    ⚠️ 模板里唯一带机器绑定的是 dsh-wsl-workspace 的 link: 路径：
#         "dsh-wsl-workspace": "link:C:/Users/20247/Downloads/minimax_work/dsh-wsl-workspace-fork"
#       新机**必须改成自己的路径**，否则 install 报
#       「cannot resolve profile bundle」（该目录不存在）。
#    📌 历史：旧机曾用 file: 指向私存 tgz（dsh-plugin-packages/*.tgz），
#       那条已废弃 —— 若你在旧备份里见到 file: 引用，那是残留，不要照抄。

# 4. 逐个装 bundle（不要指望一条 install 全搞定，见下方「假失败」）
#    Desktop 版最省事的是直接用 DSH 的 plugin_manager 工具逐个 install_bundle
dsh plugin --profile desktop install
```

### `dsh-our-free-model` 的取法（换机必读）

| 途径 | 说明 |
|---|---|
| **npm（推荐）** | `dsh-our-free-model@^2.1.0`，公开 registry，无需 tgz |
| 旧机 tgz | `C:\Users\20247\dsh-plugin-packages\dsh-our-free-model-2.0.0.tgz`，**不在 `~/.dsh` 内，迁移易漏**；本仓库不含它 |

两者是同一个包（维护者 `fish-under-sea`，`dsh.bundle.patch` 指向自带 `cordis.patch.yml`）。
**优先 npm 版** —— 否则新机一定卡住。

### 版本现状（2026-10-12 更新）

本机已从 `file:` tgz（2.0.0）**切到 npm 版 2.1.0**。

**为什么必须切**：`file:` 引用锁死在 tgz 里的版本，**无法通过改版本号升级**。
要拿 2.1.0 就必须改成 npm registry 引用 —— 这同时消除了「绝对路径 + 新机易漏」两个迁移隐患。

**升级实测（一次成功）**：

1. 改 `package.json`：`file:...2.0.0.tgz` → `"^2.1.0"`
2. `plugin_manager install_bundle dsh-our-free-model`
   → `exitCode 0`、`added 1, done in 2.8s`、`application: restart-required`（需重启生效，非失败）
3. 桌宠体检 **70/70、51/51、4/4 分毫未动**（因走 `plugin_manager` 而非裸 `pnpm install`，
   避开了「rename 包目录 → `assets/` 被占 → EPERM」那条路径）

### 🔴 免费模型「可用性」是**探测出来的**，不是配置出来的（换机必读）

**最常见的误解**：以为换了机器、装了同一个插件，免费模型列表就该一样。
**不是。** 列表由**出口 IP 的国籍**决定，同一份配置在两台机器上可以完全不同。

**机制**（见 `src/probe.js`，2026-10-12 读源码确认）：

上游网关**不会**声明哪些模型可用 —— 它只给一个扁平 id 列表，排除只在请求被拒
（返回 `RegionError`）时才显现。所以插件只能**发一个最小请求去问**：
每 `probeIntervalMinutes`（默认 15）分钟，对目录里每个模型发一次
`ping`（`max_tokens: 16`），按返回判定：

| 判定 | 触发 | 在模型选择器里 |
|---|---|---|
| `available` | 正常回包 | ✅ 显示 |
| `region-blocked` | 网关回 "This model is not available in your country" | ⚠️ 标灰（需 `exposeRegionModels`） |
| `unavailable` | 400/404/422，或消息含 `no such model` 等 | ❌ 隐藏 |
| `throttled` | 配额 | ❌ 隐藏 |
| `unknown` | 5xx / 超时 / 没收到答复 | ❌ 隐藏 |

> ⚠️ **5xx 不当作不可用**：那是网关自己的故障。源码注释明确写了这条不对称设计
> —— 「列表里留一个过期条目，用户只是白跑一轮；而一个因抖动消失的模型，
> 用户要等一整轮重探才知道」。曾因把 503 的 "Service Unavailable" 当判据，
> 把一个好模型踢出了列表。

**两条通道**（模型 id 形态不同）：

| 通道 | id 形态 | 例子 |
|---|---|---|
| `kilo` | 裸 id | `step-5-preview-free`、`nemotron-3.5-lightning-free`、`ling-3.1-flash-free` |
| `eac` | `org/model` | **`deepseek-ai/deepseek-v4.1-flash`**（即「免费国际版 DeepSeek」）、`moonshotai/kimi-k3`、`z-ai/glm-5.3` |

eac 那 6 个是 `catalog.json` 的 `sealIds` **内置写死**的，不需要填任何 Key；
**但它们完全不参与上一节的探测**（见下）。

> ⚠️ **「免费的国际版 DeepSeek」＝ EAC 通道，不是免费车道。**
> 这是最容易搞混的一点：`deepseek-v4.1-flash`（EAC）与你在本机 `availability.json`
> 里看到的那些 `*-free`（opencode 免费车道）**不是一回事**，两套门控、互不相关。
>
> 🔴 **EAC 不进 `availability.json`** —— `src/catalog.js` 的通道注释写明：
> *"the probe skips them"*（探测跳过它们）。所以**上一节的 region / throttled
> 判定对 EAC 模型根本不适用**，别拿 `availability.json` 去解释 EAC 模型不显示 ——
> 查错地方了。EAC 的显示与否由**下一节的宿主闸门 + GitHub 授权**决定。

**本机快照（2026-10-12，出口 IP `64.118.149.187`）**：

> ⚠️ **这是快照，不是恒定值。** 出口 IP 与逐模型状态都会变
> （同一天内本机出口就从 `112.87.186.2` 变成了 `64.118.149.187`）。
> **判断当前状态一律以 `availability.json` 现值为准**，下表只用于了解字段形态。

| 模型 | 状态 |
|---|---|
| `muse-spark-1.2-contributor-free` / `muse-spark-1.3-contributor-free` | `available` |
| `space-bunny-free` / `mimo-v2.6-flash-free` / `longcat-2.5-preview-free` / `nemotron-3.5-lightning-free` / `nemotron-3-ultra-free` | `available` |
| `step-5-preview-free` / `ling-3.1-flash-free` | `throttled` |
| `jev-1.13-free` | `unavailable` |
| `ling-3.0-flash-fin-free` / `exo-free` | `unknown`（`exo-free` 已废弃） |

**另一台机器缺模型时的排查顺序**：

```powershell
# 1. 看出口国籍与逐模型状态（这是唯一权威依据）
Get-Content "$env:USERPROFILE\.dsh\our-free-model\availability.json"

# 2. 看开关：exposeRegionModels=false 会让被挡模型彻底消失（而非标灰）
(Get-Content "$env:USERPROFILE\.dsh\our-free-model\settings.json" | ConvertFrom-Json).exposeRegionModels
```

**两台机器对比时只看两个数**：`egress.ip` 和具体模型在 `results.<模型id>.state` 的值。

> ⚠️ **字段名**：文件里**没有 `country` 字段** —— `egress` 只有 `{ ip }` 一个键。
> 模型状态在 `results.<id>.state`，**不是**顶层 `models`。照老写法会取到空值。

不一致就是出口问题，**与配置无关**，改配置没用。

### 🔴 EAC 通道（含「免费国际版 DeepSeek」）的 GitHub 授权闸门

**这一节很可能是「另一台机器不显示免费国际版 DeepSeek」的第一嫌疑** ——
比出口国籍更常见，且**与网络无关**。

插件公告原文（v1.5.0 / v2.0.0 的 release note，README 已核实）：

> EAC 协付渠道接入 GitHub 授权（**登录 + Star**）；**取消 Star 会失效**；
> 服务器每 **12 小时**复查一次 Star，取消后授权会在复查窗口内失效。
> **免费车道完全不受影响。**
>
> **EAC 授权强制已开启**，即日起**未登录并 star 仓库将无法使用 EAC 模型**。

README「EAC 渠道」专节对闸门的**精确表述**（⚠️ 别夸大范围）：

> **GitHub 授权闸门**：*自建网关（宝塔 Node 形态）*另带一道按人计的授权闸门
> —— 对话请求除签名外还需携带一枚**专属令牌**，而令牌只发给
> 「用 GitHub 登录 + 已 star 本仓库」的账号。……网关默认每 12 小时用保存的授权
> 复查一次 star，取消 star 即在复查窗口内吊销令牌；GitHub 侧不可达时保留既有
> 判定，不会误伤已授权用户。网关只申请 `read:user` 最小权限。

> ⚠️ 另一形态是**签名网关（Cloudflare Worker）**，README 标为「推荐形态」，
> 其门控是 HMAC 签名 + 模型白名单 + 可选按 IP 限速，**不涉及 GitHub star**。
> 即「要不要 star」取决于插件接的**是哪一种网关**，不是一刀切。
> 判断依据看设置页：要求 GitHub 登录并校验 star 的，就是自建网关形态。

**为什么**：EAC 是**协付**通道，容量跟着本仓库的 Star 数走（每 1 个 Star，号池 +1.5）。
把使用权与 Star 绑定，是让"用的人"与"撑住容量的人"对上。

**表现**：未授权时 EAC 模型卡带 **🔒 锁标记**；已授权显示 `EAC DeepSeek V4.1 Flash`。
只申请 `read:user` 最小权限，仅用于 star 复查。

**解锁步骤**（在**那台不显示的机器**上做，不是本机）：

> 设置 → Our Free Model → **EAC 渠道授权** → 「使用 GitHub 登录」
> → 浏览器自动打开授权页 → 登录并 Star → 回到应用，插件自动完成领取
> （**无需复制粘贴任何东西**；未 star 时页面给「我已 star，重新检查」，不必重新登录）

**另一台机器缺 EAC 模型的排查顺序**（按可能性排序）：

| # | 检查 | 怎么看 |
|---|---|---|
| 1 | **GitHub 授权 + Star 状态** | 设置页「EAC 渠道授权」看登录名与 star 校验；模型卡有无 🔒。**仅自建网关形态需要**（见上） |
| 2 | **宿主闸门** | EAC **仅存在于两个桌面宿主**：DSHEAC AIO（Tauri 壳，需内核路径 + 内嵌 node + `web-desktop` profile 三重信号同时命中）与 DeepSeek Harness 桌面端（Electron 壳）。命令行 / 纯 `dsh web` / 任何其它运行方式中**该通道整体不存在** |

> ⚠️ 第 2 条是硬门槛：如果那台机器不是 **DeepSeek Harness 桌面端 / DSHEAC AIO 桌面端**，
> EAC 六个模型**根本不会出现**，怎么配都没用 —— 这时该用的是免费车道（opencode）的模型。
>
> 🔴 **出口国籍不在这张表里**：EAC 被 probe 跳过（见上），region 判定对它不适用。
> 拿 `availability.json` 解释 EAC 模型不显示 = 查错了地方。

**真要改，只有两条路**（都涉及改网络出口，⚠️ 按 `conventions.md` 属于要先问的范畴）：

1. **换出口** —— `settings.json` 的 `egress` 段（当前 `enabled: false`）：
   - `client` 模式：填现成的 http/https/socks5 代理地址
   - `subscription` 模式：插件自己拉起 mihomo（Clash 核心）跑订阅链接
   改完**等下一轮探测**（默认 15 分钟）才会变。
2. **开 `exposeRegionModels`** —— 只让被挡模型**显示出来并标灰**，不改变可用性。

### ⚠️ pnpm 会自动写入 `minimumReleaseAgeExclude`

安装 24 小时内发布的新版本时，pnpm 的供应链防护（`minimumReleaseAge`，默认 1440 分钟）本会拦截。
因是显式安装，pnpm 自动在 `pnpm-workspace.yaml` 记一条：

```yaml
minimumReleaseAgeExclude:
  - dsh-our-free-model@2.1.0
```

**这是正常的**，只豁免这一条，不影响其它包的防护。**不要手动删它** —— 删了下次会被重新拦，
或者反过来手工添加会绕过防护。

## 验证

```
# 全部 bundle 应为 active
plugin_manager list_plugins     ← 用这个工具，不是 CLI
```

⚠️ **不要用 `dsh plugin --profile desktop list`** —— 该子命令是**纯 pnpm 透传**
（`dsh plugin --profile <name> <pnpm-args...>`），只会列出 13 个已装包，
**输出里根本没有 `fiberPhase` 字段**，无法证明任何加载状态。
观察 `fiberPhase` 的**唯一正确途径**是 `plugin_manager` 工具的 `list_plugins` / `list_bundles`。

期望：17 个 bundle 全部 `fiberPhase: active`、零加载失败。
（若将来装 `dsh-mobile` 则为 18 个，但当前**不建议装**，见该节。）

⚠️ **`active` 只代表「加载成功」，不代表「功能可用」。** 本机已两次踩到：
内置 Tabbit 是 `active` 但浏览器本体没装；skin-center 是 `active` 但设置项静默注册失败。
**下结论前必须实测功能**（见本文件开头「证据边界」原则）。

### 桌宠完整性自检（**每次 plugin_manager 操作后必做**）

```powershell
$pet="$env:USERPROFILE\.dsh\profiles\desktop\node_modules\dsh-whale-girl-pet"
"文件: $((Get-ChildItem $pet -Recurse -File -Force -EA SilentlyContinue).Count)/70"
"动画: $((Get-ChildItem "$pet\assets\thumb" -File -Force -EA SilentlyContinue).Count)/51"
```

**期望值恒为 70 / 51。**

## ⚠️ 桌宠脆弱性（重要教训）

**`plugin_manager` 的 install/remove 一旦报 `ERR_PNPM_EPERM`，其失败回滚不保证包内容完整** ——
它会清空 `assets/` 却保留 `lib/`，或两者都清空，而 `package.json` 看起来完全正常。

**已发生三次**：

| | 官方包 | 第 1 次 | 第 2 次 | 第 3 次 |
|---|---|---|---|---|
| 文件总数 | 70 | 3 | 16 | **47** |
| 动画 | 51 | 3 | 1 | **32** |
| 预览图 | 4 | 0 | 0 | **0** |
| `lib/` 代码 | 有 | **丢失** | 保住 | 保住 |

**根因（2026-10-10 精确定位，此前描述不准确）**：

不是「部分 webm 不可读写」。逐层探测的实际结果是：

| 层级 | 锁状态 |
|---|---|
| `lib/` | **FREE**（代码模块，import 后释放） |
| `package.json` | **FREE** |
| **`assets/`** | **LOCKED** ← 唯一被锁的 |
| `assets/` 内的文件 | 全部 FREE（可读、可写、可删） |

**`assets/` 可读可写可删，唯独不能 `rename`** —— 这是**宿主持有目录句柄**
（在做静态资源服务 / watch），不是文件锁，也不是权限问题。

**EPERM 的确切机制**：pnpm 安装时要把包目录整体 `rename`（`importPackage`），
而 `assets/` 被占用 → rename 失败 → `ERR_PNPM_EPERM` → 触发回滚。
回滚本身也不完整，于是包被留成残缺态。

### 🔴 为什么在会话内无法自愈

句柄属于**运行中的 DSH 进程**，而操作者（AI）就跑在那个进程里。表现为：

- ✅ 能删文件、补文件、读文件
- ❌ **永远无法让目录 rename 成功**

所以无论怎么清残留、补文件，下一次 pnpm 操作照样 EPERM。
**只有重启 DSH（释放进程内句柄）才能打破这个循环。**

### ✅ 已验证的有效复原流程（2026-10-10 实测成功）

1. **重启 DSH**（关键前置，释放 `assets/` 句柄）
2. 确认锁已释放：
   ```powershell
   $pet="$env:USERPROFILE\.dsh\profiles\desktop\node_modules\dsh-whale-girl-pet"
   Rename-Item $pet "$pet`_probe"   # 成功 = 锁已释放
   Rename-Item "$pet`_probe" $pet
   ```
3. 走真实流程重装（**不要手工补文件**）：
   `plugin_manager remove_bundle` → `install_bundle`
4. 期望结果：`application: applied`（而非 `failed`），
   且 pnpm 输出 `added 1, done` 而非 `ERR_PNPM_EPERM`

**实测结果**（重启后执行）：文件 `70/70`、动画 `51/51`、预览 `4/4`、
逐文件 diff 官方包 **缺失 0、多余 0**、lockfile 含 `whale`。

### ⚠️ 复原后的残留风险（知悉即可）

重装成功后，插件重新加载，`assets/` **会再次被锁** —— 这是必然且正常的
（只要桌宠在跑，资源目录就被持有）。

**但性质与之前不同**：

- ❌ 之前：残缺包 + 失败回滚 → 每次操作都碎得更厉害
- ✅ 现在：pnpm 的完整副本已干净落盘 → 即使某次操作回滚，也只是**回到这个完整状态**

**恢复源建议**：保留一份完整官方包离线副本，例如
```bash
npm pack dsh-whale-girl-pet@0.3.9    # 解包后作为逐文件恢复源
```

**体检命令**（每次 `plugin_manager` 操作后执行）：
```powershell
$pet="$env:USERPROFILE\.dsh\profiles\desktop\node_modules\dsh-whale-girl-pet"
"文件: $((Get-ChildItem $pet -Recurse -File -Force -EA SilentlyContinue).Count)/70"
"动画: $((Get-ChildItem "$pet\assets\thumb" -File -Force -EA SilentlyContinue).Count)/51"
"预览: $((Get-ChildItem "$pet\assets\preview" -File -Force -EA SilentlyContinue).Count)/4"
```

**装插件的最佳时机**：刚启动 DSH、页面尚未加载桌宠时（此时 `assets/` 未被持有）。

## Skill 管理插件的选择依据（2026-10-12）

内置 `dsh-skill-filesystem` 只缺「GUI 可见性 + 启停/增删」，因此只需补一个。
生态里有多个同类，**选型实测数据**（npm 月下载量）：

| 插件 | 月下载 | 定位 |
|---|---|---|
| **`@linxin666/dsh-client-ui-skill-explorer`** ✅ 已选 | **169,660** | 按来源浏览（bundled/project/user/custom/runtime）+ 启停 + 增删 |
| `dsh-skill-hub` | 7,149 | 读官方 `ctx.skills` registry（含第三方 provider） |
| `dsh-skill-picker` | 5,792 | 输入框旁按钮，插入 `/skill-name` |
| `dsh-skill-mcp-panel` | 4,343 | skill + MCP 服务器管理 |
| `dsh-skill-market` | 2,218 | 技能市场（SkillHub + ClawHub 双源） |
| `dsh-skill-studio` | 1,811 | 可视化编辑 + 从会话日志挖掘 skill |
| `dsh-skills-nexus` | 1,569 | 把任意 git 仓库注册成 skill |
| `dsh-plugin-skill-manager` | 114 | ⚠️ **别装**：8 月包、无 peer 声明、描述仅一行 |

**为什么选第一个**：

1. **下载量是第二名的 24 倍**，生态事实标准
2. 按**来源分类**浏览 —— 正好对上「Skill 加载机制」那套 5 级优先级
3. 依赖极干净：peer 只有 `react` + `@deepseek-ai/dsh`
4. **作者与已卸载的 skin-center 同一人**（`@linxin666`）。⚠️ skin-center 已于 2026-10-12 卸载，
   但 skill-explorer 同作者且工作正常 —— 作者相同**不再**作为兼容性依据，仅作背景

**安装实测**（一次成功，无 EPERM）：

```
install_bundle @linxin666/dsh-client-ui-skill-explorer
  → application: applied, exitCode 0, added 1, done in 1.5s
  → 桌宠体检 70/70、51/51、4/4 分毫未动（diff 官方源 缺失 0、多余 0）
  → fiberPhase: active（patchId: ui-skill-explorer）
```

> 💡 注意：这次**没有**触发 EPERM，说明「`assets/` 被锁」并非必然导致失败 ——
> 与当时 pnpm 是否需要 `rename` 整个包目录有关。**仍应每次操作后体检。**

## ⚠️ plugin_manager 装插件的两种「假失败」（2026-10-10 实测）

**症状**：`install_bundle` 返回 `application: failed` 或超时，看起来装失败了。

| 症状 | 实际原因 |
|---|---|
| `PostQueuedCompletionStatus: (6) 句柄无效` + `application: failed` | pnpm 已经打印 `Done in Ns`，但在 Windows 上收尾时崩溃 |
| `dsh: pnpm printed nothing for 600000ms and was terminated` | pnpm 同样已 `Done`，但进程不退出，被 10 分钟看门狗杀掉 |

**关键**：这两种情况下包**通常已完整落盘**，缺的只是清单登记
（`package.json` 的 `dependencies`/`bundles`，或 `pnpm-lock.yaml`）。
表现为「文件都在，但插件不加载」——**别急着重装或手工补文件，先判定**。

**判定**（Windows 侧，`$d = "$env:USERPROFILE\.dsh\profiles\desktop"`）：

```bash
ls "$d/node_modules/<包名>"                    # 包在不在
grep '<包名>' "$d/node_modules/.modules.yaml"  # pnpm 是否已登记
grep '<包名>' "$d/pnpm-lock.yaml"              # 锁文件是否已登记
```

**修复 A —— 直接重试（首选）**：包已在盘上时 pnpm 会说 `Already up to date`，
通常亚秒级完成，第二次就 `applied`。实测 `dsh-mnemon`、`dsh-our-free-model` 均如此。

**修复 B —— 只差锁文件时用 `--lockfile-only`**：

```bash
# Desktop 便携版：用 DSH 内置 node + 自带 pnpm，避免 PATH 上没有 node/pnpm
NODE="$LOCALAPPDATA/Programs/DeepSeek Harness/resources/runtime/primary-runtime/dependencies/node/bin/node.exe"
PNPM="$LOCALAPPDATA/Programs/DeepSeek Harness/resources/runtime/pnpm/bin/pnpm.cjs"
cd "$USERPROFILE/.dsh/profiles/desktop"
"$NODE" "$PNPM" install --lockfile-only
```

`--lockfile-only` **不写 `node_modules`**，所以不会触发下面桌宠那种
「pnpm 要 `rename` 包目录 → `assets/` 被占 → `ERR_PNPM_EPERM`」的路径。
**锁文件缺条目时，这是最安全的补齐方式**（实测：补完后桌宠仍 70/70、51/51、4/4 分毫未动）。

**🔴 绝对不要做的**：包已落盘但清单没写时，对**已加载的桌宠**跑普通 `pnpm install`
—— 那正是把它打成残缺态的操作。桌宠坏了就走上方的「已验证复原流程」（需先重启 DSH）。

## ⚠️ 关于 `plugin_manager` 报的 37 条 peer-gap 警告

**它们全是误报，忽略即可**（该诊断插件已卸载，此处仅存档结论）。

原因：`dsh-plugin-ops-core/lib/peers.js` 从「共享闭包镜像」`~/.dsh/profiles/node_modules/` 解析 peer，
而 **Desktop 便携版不存在该目录**（官方依赖在 `app.asar` 内），于是所有 peer 都报 gap。

**决定性反证**：所有 bundle 均 `active`。若 peer 真缺失，加载时就会直接失败。

**切勿按提示去"安装缺失的 peer"** —— 那会造成 double-instance 冲突（该工具自己判为 `fatal`）。

### 只保留了 2 条有效信息（升级前须知）

| 插件 | 不支持的版本 | 当前 |
|---|---|---|
| `dsh-whale-girl-pet` | `0.1.7-rc.2` | ✅ `0.2.0-rc.2` |
| `@anionex/dsh-eye-care` | `0.2.1-alpha.1` | ✅ `0.2.0-rc.2` |

**⚠️ 升级到 `0.2.1-alpha.1` 时 `eye-care` 会被跳过**，需更新插件或走版本豁免。

## ⚠️ 配置写入方冲突（明暗外观"被覆盖"的原因）

`cordis.patch.yml` 存在**多个写入方**：

1. `plugin_manager` — 启停插件时
2. ~~`@linxin666/dsh-client-ui-skin-center` 的 `legacy-bridge`~~ — ✅ **2026-10-12 已卸载，此风险解除**
   （曾会重写整个 YAML 并丢弃注释：`lib/index.js:3383` 正则命中
   `name: "@linxin666/dsh-client-ui-skin-..."` 即触发）
3. `dsh-config-editor` — 设置页保存时（保留注释）
4. `dsh-theme-studio` — 通过 `ctx.theme.overrideTokens` 覆盖 token，**不改 YAML**

**现在的正确做法**：改明暗去「**设置 → 通用 → 外观**」，或用 `dsh-theme-studio` 的主题面板。
⚠️ **不要再引用「皮肤中心」那个入口 —— 插件已卸载，点了没用。**

## Skill 加载机制（2026-10-12 实测）

DSH 的 skill 有**两条来源**，之前本仓库完全没记录，换机时容易漏。

### 一、内置 skill（随安装包，只读）

| skill | 位置 | 机制 |
|---|---|---|
| `office-docx` / `office-pptx` / `office-xlsx` | `resources/runtime/office-skills/` | 代码**硬编码**注册 `assetRoot` |
| `diagnose-windows-sandbox-acl` | 同目录 `scripts/` | 同上 |

路径由环境变量算出（asar 内原文）：

```js
process.env.DSH_PRIMARY_RUNTIME ?? process.env.DSH_BUNDLED_PRIMARY_RUNTIME
  + '/../office-skills'
```

**跟着 DSH 升级走，不要手改。**

### 二、磁盘扫描（可自建）

`dsh-skill-filesystem` 按**优先级**扫描（数字小的赢，同名时高优先级遮蔽低的）：

| 优先级 | 名称 | 路径 |
|---|---|---|
| 100 | `project-dsh` | `<项目根>/.dsh/skills` |
| 200 | `project-agents` | `<项目根>/.agents/skills` |
| 300 | `custom` | `Config.customSkillDirs` |
| 400 | `user-dsh` | `<DSH home>/skills`（即 `~/.dsh/skills`） |
| 500 | `user-agents` | `<agents home>/skills`（即 `~/.agents/skills`） |

> **项目根 = 最近的含 `.git` 的祖先目录**；没有则用 cwd。
> 用户级 DSH 根会**跳过 `.system` 子目录**。

**其他配置项**（asar 文档原文）：

| 项 | 默认 | 含义 |
|---|---|---|
| `includeDefaultRoots` | `true` | 是否包含项目/用户根 |
| `watch` | `true` | **监视目录变更并自动失效重扫**（热重载） |
| `bundledSkillDir` | — | 内置 skill 根，按 rank 扫描 |

### ⚠️ 多工具共用 `.agents/skills`（易混淆）

`~/.agents/skills` 是**多工具共享**目录。实测本机 `tabbit` 同时出现在：

```
~/.agents/skills/tabbit                    ← 优先级 500
~/.claude/skills/tabbit                    ← Claude Code 自己的目录
~/.workbuddy/plugins/cache/tabbit-browser/tabbit   ← WorkBuddy 写入
```

**装了 WorkBuddy / CodeBuddy 之后，它们会往 `.agents/skills` 塞东西**，所以那个目录的内容不完全由你控制。

### 内置够不够用

| 能力 | 内置支持 |
|---|---|
| 多根扫描（5 级优先级） | ✅ |
| 热重载（`watch: true`） | ✅ |
| `customSkillDirs` 自定义目录 | ✅ |
| **GUI 里看见加载了哪些 skill** | ❌ |
| **启用/禁用单个 skill** | ❌ |
| **新建/编辑/删除 skill** | ❌ |

**结论：读够用，管理不够。** 自己手写 `SKILL.md` 丢目录 → 够用；想可视化管理和开关 → 需插件（见下）。

### 怎么自己加一个 skill

项目级（跟项目走，可入库）：
```
<项目根>/.dsh/skills/<名字>/SKILL.md
```

用户级（所有项目可用）：
```
~/.dsh/skills/<名字>/SKILL.md
```

`SKILL.md` 需 frontmatter（`name` + `description`），**description 要写清触发场景** —— 模型只看这个描述决定是否加载。

> ✅ `~/.dsh/skills` 在本机**已存在**（含自建 `evidence-boundary`）。
> 想再加自建用户级 skill 就放这个路径 —— 它优先于 `.agents/skills`（400 > 500）。

### 📌 本仓库自建 skill：`evidence-boundary`（2026-10-12）

**位置**：`~/.dsh/skills/evidence-boundary/SKILL.md`（模板在 `templates/skills/`）
**优先级**：`user-dsh`（400），高于 `tabbit` 所在的 `.agents/skills`（500）

**它解决什么**：两次真实事故的病根都是
**「把文档/代码里写的当成实际是什么」**——

| 事故 | 当时依据 | 真实原因 |
|---|---|---|
| WorkBuddy 缺模型 | 读插件源码 + 作者注释 | **设置页一个开关**（答案在 `state.json`，没打开过） |
| R6 编译失败 | 读 handover 文档的推断 | **`subst` 子串替换写成 `_im_im`**（一条 `grep conaninfo.txt` 即可证伪） |

**核心机制**（借鉴 `oh-my-hermes` 的 `prepared_not_observed` 契约，改写为 DSH 原生）：

1. **证据分级**：每条结论标注 `observed`（实测+命令+输出）/ `read`（文件:行号）/ `inferred`（推理，标明未验证）
2. **裁决词表**：`VERIFIED` / `FIX_READY` / `NEEDS_MORE_EVIDENCE` / `BLOCKED_BY_ENVIRONMENT` / `DISPROVEN`
   —— **禁止**"应该可以了""大概率是"
3. **同一假设失败 2 次 → 强制换假设**（不是换变体）
4. **用户说"以前是好的"时，先找 delta**，先证明"什么没变"
5. 改前**隔离现场**（移到备份目录而非 `rm`）+ **临时文件验证语义**
6. 改完**端到端验证**（用与失败时完全相同的参数重跑）

**安装**：
```bash
mkdir -p ~/.dsh/skills/evidence-boundary
cp templates/skills/evidence-boundary/SKILL.md ~/.dsh/skills/evidence-boundary/
```

**验证**（走 skill-explorer 的真实 API）：
```powershell
$h = @{ Origin="http://127.0.0.1:19387"; Referer="http://127.0.0.1:19387/" }
(Invoke-WebRequest "http://127.0.0.1:19387/api/dsh-skill-explorer/list" -Headers $h -UseBasicParsing).Content |
  ConvertFrom-Json | Select-Object -ExpandProperty groups |
  ForEach-Object { "[$($_.key)] " + (($_.skills | ForEach-Object { $_.name }) -join ', ') }
```

实测输出（2026-10-12，**装 fork 前**）：
```
[bundled     ] diagnose-windows-sandbox-acl, office-docx, office-pptx, office-xlsx
[user-dsh    ] evidence-boundary          ← 自建，level=user-dsh, modelInvocable=true
[user-agents ] tabbit
```

**✅ 生效验证（装 fork 后，2026-10-12 实测）**：

```
[bundled     ]  4 个
[user-dsh    ]  1 个   （evidence-boundary）
[user-agents ] 62 个   （imfl-* 28、lark-* 30、meegle、tabbit …）
──────────────────────
合计           67 个   ← 装 fork 前只有 5 个
```

⚠️ **数字口径**：WSL 侧 `~/.claude/skills` 是 **61** 个；
API 的 `user-agents` 组是 **62** 个 —— 因为 `~/.agents/skills` 除链接目标外
还含 Windows 侧独立写入的 `tabbit`。两个数都对，**口径不同**，别混用。

**设计取舍**：正文仅 ~2KB（每轮都进上下文，刻意写短）；只用 `name` + `description`
两个 frontmatter 字段（与官方 office-* 一致）；`description` 中英双写触发词以提高命中率。

> 💡 **`oh-my-hermes` 是什么**：它是 **Hermes Agent**（`NousResearch/hermes-agent`）
> 的插件，**不是 DSH 插件，装不上**。但它的工程结构值得借鉴 ——
> 142 个 skill 共用一份 `skill-common-rail.md`（避免每轮重复 88 份文本），
> 以及 `prepared_not_observed` / `not_observed` 的证据边界词汇。
> 本仓库只借鉴**理念**，不搬运其代码（工具名/路径/agent 机制全不同）。

### 本机实际加载的 skill

**装 fork 前（2026-10-12 上午，5 个）**：
```
diagnose-windows-sandbox-acl   内置
office-docx                    内置
office-pptx                    内置
office-xlsx                    内置
tabbit                         磁盘（~/.agents/skills）
```

**装 fork 后（同日，67 个）**：上述 5 个 + `evidence-boundary`（自建）
+ **62 个 `user-agents`**（`imfl-*` 28、`lark-*` 30、`meegle`、`tabbit` …）。

⚠️ **这个清单每个会话可能不同** —— `project-dsh` / `project-agents` 依赖**当前项目根**。
例如 `imfl_auto_test` 项目会额外加载该项目自己的 skill
（`agent-context-boundary-principle`、`cpp-concurrency-dds-principles`、
`deterministic-sil-architecture`、`imfl-auto-test-architecture` 等）。

## 数据位置（迁移时）

| 路径 | 内容 | 可否直接复制 |
|---|---|---|
| `~/.dsh/profiles/desktop/{package.json,cordis.patch.yml,pnpm-lock.yaml}` | 插件配置 | ✅ 小且关键 |
| `~/.dsh/profiles/desktop/node_modules/` | 依赖产物 100.8 MB | ❌ **不要复制**，重建 |
| `~/.dsh/skin-center-active.json` | ~~皮肤选择~~ | ⚪ **已失效**，插件卸载后无人读取，可不迁移 |
| `~/.dsh/cordis.patch.yml` | **机器级**补丁层：`bot-gateway` 那一行 | ✅ 必须迁移 —— 见 `dsh-bot-gateway` 专节（profile 级 patch 会被 DSH 的 `profiles.broken-<ts>` 隔离丢掉） |
| `~/.dsh/node_modules/dsh-bot-gateway/` | 该插件的**机器级**副本（浏览器半边按此路径解析） | ❌ 重建：装包后复制一份即可 |
| `~/.dsh/bot-gateway/` | 该插件的运行时数据 + `boot.log` 启动自检 | ❌ 不迁移 |
| `~/.dsh/our-free-model/{settings,availability,catalog}.json` | 免费模型的开关 / **逐模型可用性** / 目录 | ⚠️ **不要复制** `availability.json` —— 它是本机出口 IP 的探测结果，换机必然失效（见「可用性」一节） |
| `~/.dsh/.credentials.yaml` | 密钥 19 条 | ❌ 见 `secrets.md` |
| `~/.dsh/sessions/` | 会话记录 11 MB | 可选 |
| `C:\Users\<user>\dsh-plugin-packages\*.tgz` | free-model 的旧机私存副本 | ⚠️ 不在 `~/.dsh` 内、本仓库也不含；**新机不必带它，改用 npm 版** |
