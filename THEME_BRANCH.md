# 主题版维护线（`personal-theme`）

这条分支只保留：**深潮主题 + 工作台 + 个人 userData 隔离 + AUMID 分离 + 构建复用**。  
**不含 GenUI、不含 `dsh-ui` 注入**；完整 GenUI 线保留在 `personal` 分支，不合并、不影响这条线。

## 当前状态（2026-11-08）

| 项 | 值 |
|---|---|
| 分支 | `personal-theme` |
| 基座 | 上游 v0.7.7 + 2026-11-01 主题提交（`3e198207`） |
| 主题新提交 | AUMID 修复 + agent-desktop 复用 + `.gitattributes` LF 固定 |
| 当前运行包 | `desktop\build-artifacts\personal-theme-aumid\win-unpacked` |
| 桌面快捷方式 | `Claude Code Haha (Personal Theme 2026-11-01).lnk` → junction `C:\Users\26056\cc-haha-personal-theme-aumid` |
| 远端 | `origin/personal-theme`（自己的 fork） |

## 功能地图（冲突时按这张表查）

| 功能 | 关键文件 |
|---|---|
| 深潮主题 | `desktop/src/types/settings.ts`、`theme/systemAppearance.ts`、`theme/globals.css`、`desktop/index.html`、`GeneralSettings.tsx`、`H5GeneralSettings.tsx`、`ShareImageDialog.tsx`、5 个 locale |
| 工作台 | `desktop/src/pages/WorkbenchHome.tsx`、`stores/tabStore.ts`、`components/layout/ContentRouter.tsx`、`components/layout/Sidebar.tsx` |
| userData 隔离 | `desktop/electron/main.ts`（`claude-code-desktop-personal`） |
| AUMID 分离 | `desktop/electron/services/appIdentity.ts`（`com.claude-code-haha.desktop.personal`） |
| 构建复用 | `desktop/scripts/native-agent-desktop.ts`、`.gitattributes` |

**不要加回**：`desktop/src/components/genui/**`、`src/server/services/genuiSystemPrompt.ts`、`@changfenhuang/dsh-genui`。`verify-theme.ps1` 会主动检查它们不存在。

## 上游更新流程

双击 `更新主题版.cmd`，或：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\update-theme.ps1 -Build
```

脚本顺序：

1. 确认当前在 `personal-theme` 分支
2. 检查目标输出目录是否被占用（`theme-next`）
3. 清工作树（只容忍生成的 `preview-agent.js`）
4. `git fetch upstream --tags` + `git rebase upstream/main`
5. 跑 `verify-theme.ps1`：源标记 + **261 项主题测试**（5 个文件）
6. 四处 `bun install`（root / desktop / mobile / adapters）
7. 构建 sidecar → renderer → Electron → 打包到 `desktop\build-artifacts\theme-next\win-unpacked`
8. 再校验打包产物（exe / app.asar / sidecar / 构建 CSS 含 deepseek）

**有冲突**：脚本会停在 rebase，按上表保留个人改动；解决后 `git add` + `git rebase --continue`。冲突通常只在 Sidebar 的图标 import、locale、settings 列表。

## 关于「能不能保证跟得上」

不能保证上游永远不改接口——没人能保证。但这条线把风险压到最低：

- 只改了主题/工作台相关的少量文件，rebase 冲突面小且集中在上表。
- 每次更新自动跑 261 项主题测试 + 完整构建 + 产物校验；**任何一项失败就停，不会产出坏包**。
- GenUI 被明确排除并有反向检查，不会因为上游/其他分支把它带回来。
- 最坏情况：冲突太多时，可以按上表在最新 `upstream/main` 上重新挑主题提交，不碰 GenUI。

## 已知无关失败

全量 `src/theme` 里有 2 个项目文件与主题无关的上游失败（`H5AccessSettings.tsx` 的 stock palette、`preview-agent` 的 CSS 变量解析）。`verify-theme.ps1` 只跑与主题直接相关的 5 个测试文件，不把这些上游噪声算进验收。
