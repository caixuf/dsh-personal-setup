# intent/dsh.md — DSH（DeepSeek Harness）个性化配置

## 这是什么

DSH 桌面端的插件组合与外观配置。共 **17 个 bundle**，全部经验证 `fiberPhase: active`。
（曾装过 `dsh-mobile`，因 CLI 损坏 + 流程繁琐**已卸载**，踩坑记录见下方「dsh-mobile」一节 —— 新机**不要装**。）

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
| `dsh-wsl-workspace` | 会话执行环境落地 WSL | 兼容 `0.2.0-rc.2` 已声明 |
| `dsh-wsl-workspace-picker` | 目录选择器直达 `/mnt/*` | |
| `dsh-whale-girl-pet` | 鲸鱼娘桌宠 | ⚠️ 见下方「桌宠脆弱性」。**独立插件，不依赖皮肤中心** |
| `dsh-theme-studio` | 主题/配色 | 12 预设 + 深色对比度守护（亮度 < 0.18 自动提亮）。见「外观插件教训」 |
| `dsh-terminal-panel` | 主栏全尺寸终端 | 最多 12 标签，刷新回放 256KB |
| `@anionex/dsh-eye-care` | 暖色护眼主题 | 明暗双套，不劫持 Appearance |
| `@weibaohui/dsh-sync` | 多机同步/备份 | Git + WebDAV + 本地文件夹三协议 |
| `dsh-mnemon` | 长期记忆 | 附带 11 个子行（4 source + 5 strategy） |
| `@linxin666/dsh-client-ui-skill-explorer` | **skill 管理中心** | 补内置缺口：GUI 里按来源浏览/启停/增删 skill。见「Skill 加载机制」 |
| `@deepseek-ai/dsh-experimental-agent-team-profile` | **Agent Teams**（官方实验） | 多 teammate 协作、共享任务板。本会话正在使用 |
| `@deepseek-ai/dsh-experimental-voice-input-bundle` | **语音输入**（官方实验） | 官方实验特性 |
| `dsh-browser-cdp` | **浏览器自动化**（能力级） | 用**你已装的 Chrome**，37 个 `bcdp_*` 工具。见 `ecosystem.md` |
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

## 外观取向（用户偏好）

来自多轮交互确认，**不要**改成别的：

1. **桌宠本体 `dsh-whale-girl-pet` 是独立插件**（不依赖任何皮肤系统）。
   ⚠️ 2026-10-12 已卸载 `skin-center`，`blue-fantasy` 皮肤随之消失，**这是可接受的**
   —— 用户明确说「不需要花哨皮肤」。若将来要恢复皮肤，**不要**用 `skin-center`
   （见「外观插件教训」），优先 `dsh-theme-gallery`（3,709/月）。
2. `ui-theme.preference` 应为 **`dark`**
   ⚠️ 曾误改成 `light`（记错了「GUI 里选的是 light」）—— 已按本文件改回 `dark`。
   **明暗以本文件为准。**
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

# 2. 复制配置三件套
cp templates/dsh/package.json       ~/.dsh/profiles/desktop/package.json
cp templates/dsh/cordis.patch.yml   ~/.dsh/profiles/desktop/cordis.patch.yml

# 3. 【重要】不要把模板里的 file: 依赖照抄到新机
#    模板那条：
#      "dsh-our-free-model": "file:C:/Users/20247/dsh-plugin-packages/dsh-our-free-model-2.0.0.tgz"
#    指向旧机的私存 tgz —— 新机**没有这个文件**，照抄会让整个 install 失败。
#    ✅ 正解：改用 npm 版（同一个包，现在最新 2.1.0）
#      "dsh-our-free-model": "^2.1.0"
#    （2026-10-10 实测：npm 上有作者正式发布的 2.0.0，peer 窗口 ^0.2.0-rc.1 正好匹配 0.2.0-rc.2；
#      2026-10-12 本机已升到 2.1.0，peer 窗口不变，仍兼容）

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

```bash
# 全部 bundle 应为 active
dsh plugin --profile desktop list
```

期望：17 个 bundle 全部 `fiberPhase: active`、零加载失败。
（若将来装 `dsh-mobile` 则为 18 个，但当前**不建议装**，见该节。）

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
4. **作者与已装的 skin-center 同一人**（`@linxin666`），兼容性风险低

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

> ⚠️ `~/.dsh/skills` 在本机**尚不存在**。若想自建用户级 skill 且优先于 `.agents/skills`，用这个路径（400 > 500）。

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

实测输出（2026-10-12）：
```
[bundled     ] diagnose-windows-sandbox-acl, office-docx, office-pptx, office-xlsx
[user-dsh    ] evidence-boundary          ← 自建，level=user-dsh, modelInvocable=true
[user-agents ] tabbit
```

**设计取舍**：正文仅 ~2KB（每轮都进上下文，刻意写短）；只用 `name` + `description`
两个 frontmatter 字段（与官方 office-* 一致）；`description` 中英双写触发词以提高命中率。

> 💡 **`oh-my-hermes` 是什么**：它是 **Hermes Agent**（`NousResearch/hermes-agent`）
> 的插件，**不是 DSH 插件，装不上**。但它的工程结构值得借鉴 ——
> 142 个 skill 共用一份 `skill-common-rail.md`（避免每轮重复 88 份文本），
> 以及 `prepared_not_observed` / `not_observed` 的证据边界词汇。
> 本仓库只借鉴**理念**，不搬运其代码（工具名/路径/agent 机制全不同）。

### 本机实际加载的 skill（2026-10-12）

```
diagnose-windows-sandbox-acl   内置
office-docx                    内置
office-pptx                    内置
office-xlsx                    内置
tabbit                         磁盘（~/.agents/skills）
```

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
| `~/.dsh/.credentials.yaml` | 密钥 19 条 | ❌ 见 `secrets.md` |
| `~/.dsh/sessions/` | 会话记录 11 MB | 可选 |
| `C:\Users\<user>\dsh-plugin-packages\*.tgz` | free-model 的旧机私存副本 | ⚠️ 不在 `~/.dsh` 内、本仓库也不含；**新机不必带它，改用 npm 版** |
