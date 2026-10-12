# forks/dsh-wsl-workspace — 本机 fork

> **这不是上游仓库。** 它是 `dsh-wsl-workspace` 的**本地修改版**，
> 只为解决一个具体问题：让 WSL 会话能读到 WSL 用户级 skill。
> 上游仓库完整历史在 <https://github.com/dsh-wsl-workspace-maintainers/dsh-wsl-workspace>。

## 为什么存在

本机 WSL 里有 **61 个 skill**（`~/.claude/skills`，`~/.agents/skills` 是它的符号链接），
但 DSH 开 WSL 会话时**只加载 5 个**（4 个内置 + tabbit）。

官方 `src/host/wsl-skills.ts` **只扫项目级**（`<项目>/.dsh/skills`、`<项目>/.agents/skills`），
从不扫 WSL 用户级 `~/.agents/skills` —— 那 61 个等于不存在。

## 改了什么

基线锁定 **`v0.7.5`**，只叠加 skill 扫描改动，preset 派生机制保持 0.7.5 原样。

| 项 | 内容 |
|---|---|
| `src/host/wsl-skills.ts` | +176 行 |
| `tests/wsl-skills.test.ts` | +86 行，Windows 36/36 通过 |
| `lib/index.js` | ⚠️ **不在本目录**，是构建产物，用下面的命令生成 |

- `USER_DSH_RANK = 400` / `USER_AGENTS_RANK = 500`（对齐 DSH 官方 5 级 skill 优先级）
- `resolveDistributionHome()` —— 经 `wsl.exe -d <distro> -- printenv HOME` 取真实 home
- `discoverUserSkillRoots()` —— **带符号链接回退**（本机 `~/.agents/skills` 就是链接，
  且 Windows 9P 共享无法跟随 Linux 符号链接，必须让发行版自己解析）
- `discoverAllSkillRoots()` —— 合并项目级 + 用户级

## 🚨 构建前必查的哨兵

```bash
grep -c variantGeneration lib/index.js     # 必须输出 0
```

`variantGeneration` 是**上游 0.7.7 preset 派生机制的标志**。
本机曾误装 0.7.7，导致所有 WSL 会话报 `Unknown agent preset: wsl-standard` 而打不开
（该 preset 由插件启动时从内置 preset 动态派生，新机制要配套新配置）。
**非 0 就是炸弹。**

## 构建

```bash
# 需要 node >= 24（package.json 的 engines 要求）
node -v
npm install
npm run build          # 末尾须打印 verify-lib OK: 11 lib entries, all calls bound
```

## 测试

```bash
node --test tests/wsl-skills.test.ts
```

**注意**：

1. 用 `node --test`，**不是 vitest**。误用 `npx vitest` 会报 `No test suite found`，
   看着像文件坏了，其实只是 runner 不对。
2. **Linux 下 34/36** 那 2 个失败与本改动无关 —— 是路径分隔符差异
   （Linux 走 `posix.join` 产出 `/`，Windows 走 `path.join` 产出 `\`）。
   真实部署环境是 Windows，以 Windows 结果为准：**36/36 全过**。

## 装到 DSH

DSH 用 `link:` 指向一份**运行副本**（放在 Windows 可访问的路径下）：

```json
"dsh-wsl-workspace": "link:C:/Users/<你的用户名>/<某个工作目录>/dsh-wsl-workspace-fork"
```

同步源码 → 运行副本（`<WIN_DIR>` 换成你实际的工作目录）：

```bash
# 1) 先编译（运行副本靠 lib/index.js 被 DSH 加载，缺了装不上）
npm run build
grep -c variantGeneration lib/index.js      # 必须为 0

# 2) 连 lib/ 一起同步 —— 注意不要 --exclude=lib
tar --exclude=node_modules --exclude=.git -cf - . \
  | tar -C /mnt/c/<你的用户名>/<某个工作目录>/dsh-wsl-workspace-fork -xf -
```

> ⚠️ **不要把 `--exclude=lib` 加进这条命令。** 本仓 `forks/` 出于体积与
> 「lib 是产物」的考虑**不入库**，但**运行副本必须有 `lib/`** ——
> DSH 加载的就是它。漏了会导致插件装上但加载失败。

完整的踩坑记录（安装路径的三个坑、回滚流程、`cherry-pick` 把编译产物带进来的陷阱）
见 `../../intent/dsh.md` 的「WSL 用户级 skill fork」节。

## 许可

上游为 **MIT**（见本目录 `LICENSE`，Copyright (c) 2026 dsh-wsl-workspace contributors）。
本目录保留上游许可证与版权声明。
