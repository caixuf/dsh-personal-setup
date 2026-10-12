# templates/dsh/ — 使用说明

## 三件套

| 文件 | 作用 |
|---|---|
| `package.json` | 依赖清单 + bundle 名单 |
| `cordis.patch.yml` | **profile 级**补丁（大部分插件配置） |
| `pnpm-workspace.yaml` | pnpm 供应链豁免（`minimumReleaseAgeExclude`） |

## ⚠️ `dsh-bot-gateway` 不进 `bundles` 数组

它在 `dependencies` 里（保证 `pnpm install` 不清掉），但**不在** `dsh.profile.bundles` ——
因为它是**宿主插件**（`main: ./index.mjs` + `dsh.client` 注入），没有 `dsh.bundle.patch`，
挂 bundle 名单里会报 `cannot resolve profile bundle`。

**它的挂载点在机器级** `<dsh-home>/cordis.patch.yml`：

```yaml
- insert:
    - id: bot-gateway
      name: dsh-bot-gateway
```

为什么必须是机器级：DSH Desktop 后端启动失败时会把整个 `profiles/` 目录隔离成
`profiles.broken-<时间戳>` 并重建，**profile 级补丁会随之丢失**；机器级的不受影响。

详见 `intent/dsh.md` 的「`dsh-bot-gateway`」专节。

## 还有一处不在本目录：机器级 patch

`<dsh-home>/cordis.patch.yml` **不在** `templates/dsh/` 里 —— 它位于 profile 目录**上一级**。
换机时容易漏，审计脚本会提醒（见下）。

## 审计：模板 vs 本机实机的 drift

```bash
bash scripts/audit-dsh-drift.sh --profile "/mnt/c/Users/<你>/.dsh/profiles/desktop"
```

它会报出：本机有模板无 / 模板有本机无（依赖 + bundle）、模板残留的 `link:`/`file:`
机器路径、机器级 patch 是否已登记进仓库。

> 💡 **模板领先于本机是正常的**（模板是目标态）。看到「模板有本机无」不代表模板错，
> 只说明本机还没 `apply.sh --dsh`。反过来「本机有模板无」才需要判断是不是该补进模板。
