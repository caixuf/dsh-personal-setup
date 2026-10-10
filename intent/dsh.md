# intent/dsh.md — DSH（DeepSeek Harness）个性化配置

## 这是什么

DSH 桌面端的插件组合与外观配置。共 **12 个 bundle**，全部经验证 `fiberPhase: active`。

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
| `dsh-our-free-model` | 免费模型接入 | ✅ **npm 上也有**（`dsh-our-free-model@2.0.0`）；模板里那条 `file:` tgz 只是旧机私存副本，新机直接用 npm 版 |
| `dsh-wsl-tool` | WSL 命令/路径/环境工具 | 注册 `wsl`/`wsl-path`/`wsl-env`/`wsl-doctor` |
| `dsh-wsl-workspace` | 会话执行环境落地 WSL | 兼容 `0.2.0-rc.2` 已声明 |
| `dsh-wsl-workspace-picker` | 目录选择器直达 `/mnt/*` | |
| `dsh-whale-girl-pet` | 鲸鱼娘桌宠 | ⚠️ 见下方「桌宠脆弱性」 |
| `@linxin666/dsh-client-ui-skin-center` | 皮肤中心 | 提供 `blue-fantasy` 鲸鱼娘皮肤 |
| `dsh-terminal-panel` | 主栏全尺寸终端 | 最多 12 标签，刷新回放 256KB |
| `@anionex/dsh-eye-care` | 暖色护眼主题 | 明暗双套，不劫持 Appearance |
| `@weibaohui/dsh-sync` | 多机同步/备份 | Git + WebDAV + 本地文件夹三协议 |
| `dsh-mnemon` | 长期记忆 | 附带 11 个子行（4 source + 5 strategy） |

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

## 外观取向（用户偏好）

来自多轮交互确认，**不要**改成别的：

1. **鲸鱼娘外观由 skin-center 的 `blue-fantasy` 皮肤提供**，不用 `dsh-theme-whalegirl`
2. `ui-theme.preference` 应为 **`dark`**
3. 皮肤中心的**背景遮挡 `backgroundOpacity`** 由用户自行调节（0 = 壁纸全裸，用户嫌遮挡视线）。
   **不要写死具体数值** —— 实测用户会在 15~72 之间自行调整，见 `~/.dsh/skin-center-active.json`。
4. eye-care 当前 `mode: off`，但保留（用户可自行启用暖色）

### ⚠️ 已排除的插件（不要再装）

| 插件 | 排除原因 |
|---|---|
| `dsh-theme-whalegirl` | **独占式**：`colorScheme` 只有 light 一套 + 监听 `theme/change` 无条件回弹。导致暗色看不清、切换被劫持。**已卸载** |
| `dsh-plugin-ops-bundle` | 37 条警告全属误报（见下）。**已卸载** |
| `@linxin666/dsh-web-all` | 内含 skin-center，**与已装的重复挂载**会报错 |

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
#    ✅ 正解：改用 npm 版（同一个包，同一个 2.0.0）
#      "dsh-our-free-model": "^2.0.0"
#    （2026-10-10 实测：npm 上有作者正式发布的 2.0.0，peer 窗口 ^0.2.0-rc.1 正好匹配 0.2.0-rc.2）

# 4. 逐个装 bundle（不要指望一条 install 全搞定，见下方「假失败」）
#    Desktop 版最省事的是直接用 DSH 的 plugin_manager 工具逐个 install_bundle
dsh plugin --profile desktop install
```

### `dsh-our-free-model` 的取法（换机必读）

| 途径 | 说明 |
|---|---|
| **npm（推荐）** | `dsh-our-free-model@^2.0.0`，公开 registry，无需 tgz |
| 旧机 tgz | `C:\Users\20247\dsh-plugin-packages\dsh-our-free-model-2.0.0.tgz`，**不在 `~/.dsh` 内，迁移易漏**；本仓库不含它 |

两者是同一个包（维护者 `fish-under-sea`，`dsh.bundle.patch` 指向自带 `cordis.patch.yml`）。
**优先 npm 版** —— 否则新机一定卡住。

## 验证

```bash
# 全部 bundle 应为 active
dsh plugin --profile desktop list
```

期望：10 个 bundle 全部 `fiberPhase: active`、零加载失败。

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
2. `@linxin666/dsh-client-ui-skin-center` 的 `legacy-bridge` — ⚠️ **会重写整个 YAML 并丢弃注释**
   （`lib/index.js:3383` 正则命中 `name: "@linxin666/dsh-client-ui-skin-..."` 即触发）
3. `dsh-config-editor` — 设置页保存时（保留注释）

**用户层表现**：在「设置 → 通用 → 外观」改了明暗，会被皮肤中心覆盖。

**正确做法**：**改明暗去「设置 → 皮肤中心」改**，不要只改通用设置。

## 数据位置（迁移时）

| 路径 | 内容 | 可否直接复制 |
|---|---|---|
| `~/.dsh/profiles/desktop/{package.json,cordis.patch.yml,pnpm-lock.yaml}` | 插件配置 | ✅ 小且关键 |
| `~/.dsh/profiles/desktop/node_modules/` | 依赖产物 100.8 MB | ❌ **不要复制**，重建 |
| `~/.dsh/skin-center-active.json` | 皮肤选择 | ✅ 260 字节 |
| `~/.dsh/.credentials.yaml` | 密钥 19 条 | ❌ 见 `secrets.md` |
| `~/.dsh/sessions/` | 会话记录 11 MB | 可选 |
| `C:\Users\<user>\dsh-plugin-packages\*.tgz` | free-model 的旧机私存副本 | ⚠️ 不在 `~/.dsh` 内、本仓库也不含；**新机不必带它，改用 npm 版** |
