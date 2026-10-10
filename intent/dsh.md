# intent/dsh.md — DSH（DeepSeek Harness）个性化配置

## 这是什么

DSH 桌面端的插件组合与外观配置。共 **10 个 bundle**，全部经验证 `fiberPhase: active`。

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
| `dsh-our-free-model` | 免费模型接入 | ⚠️ **`file:` 依赖，绝对路径，换机必改** |
| `dsh-wsl-tool` | WSL 命令/路径/环境工具 | 注册 `wsl`/`wsl-path`/`wsl-env`/`wsl-doctor` |
| `dsh-wsl-workspace` | 会话执行环境落地 WSL | 兼容 `0.2.0-rc.2` 已声明 |
| `dsh-wsl-workspace-picker` | 目录选择器直达 `/mnt/*` | |
| `dsh-whale-girl-pet` | 鲸鱼娘桌宠 | ⚠️ 见下方「桌宠脆弱性」 |
| `@linxin666/dsh-client-ui-skin-center` | 皮肤中心 | 提供 `blue-fantasy` 鲸鱼娘皮肤 |
| `dsh-terminal-panel` | 主栏全尺寸终端 | 最多 12 标签，刷新回放 256KB |
| `@anionex/dsh-eye-care` | 暖色护眼主题 | 明暗双套，不劫持 Appearance |

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

# 2. 复制配置三件套
cp templates/dsh/package.json       ~/.dsh/profiles/desktop/package.json
cp templates/dsh/cordis.patch.yml   ~/.dsh/profiles/desktop/cordis.patch.yml

# 3. 【必改】修正 file: 依赖的绝对路径
#    把 C:/Users/<旧用户名>/dsh-plugin-packages/... 改成新机实际路径
#    并把该 tgz 拷到新机对应位置

# 4. 安装依赖
dsh plugin --profile desktop install
```

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

**已发生两次**：

| | 官方包 | 第一次损坏后 | 第二次损坏后 |
|---|---|---|---|
| 文件总数 | 70 | 3 | 16 |
| 动画 | 51 | 3 | 1 |

**根因**：`dsh-whale-girl-pet` 的部分 webm 处于不可读写状态，pnpm 无法重命名整个目录。

**恢复方法**：从完整官方包逐文件补齐，被锁文件视为已存在而跳过。

**预防**：加装插件前**先卸载桌宠**，装完再装回。

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
| `C:\Users\<user>\dsh-plugin-packages\*.tgz` | free-model 包 | ✅ 但**不在 `~/.dsh` 内**，易漏 |
