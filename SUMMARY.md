# SUMMARY — CC-Haha 个人版（personal fork）

更新：2026-11-06

## 一句话

个人版 = 上游 CC-Haha 源码 + 6 项个人功能（深潮主题、工作台、独立 userData、通知 AUMID、GenUI 渲染、GenUI 宿主注入）。所有改动都在 `personal` 分支，更新方式是 rebase 到 `upstream/main`，不再改官方安装目录的压缩 bundle。

## 当前基线

| 项 | 值 |
|---|---|
| 上游仓库 | `NanmiCoder/cc-haha`（remote `upstream`） |
| 上游版本 | v0.7.7 / `fbbebdee` |
| 个人仓库 | `TimesOldRoman-1/cc-haha`（remote `origin`） |
| 个人分支 | `personal`（当前 HEAD 以 `git log -1` 为准） |
| 工作树 | `C:\Users\26056\Desktop\小试验\CC-Haha_Personal` |

## 功能地图

| 功能 | 关键文件 | 验证方式 |
|---|---|---|
| 深潮主题 `deepseek` | `desktop/src/types/settings.ts`、`theme/systemAppearance.ts`、`theme/globals.css`、`index.html` | 主题测试 234 项 |
| 工作台首页 | `desktop/src/pages/WorkbenchHome.tsx`、`stores/tabStore.ts`、`components/layout/ContentRouter.tsx`、`Sidebar.tsx` | 源文件标记 + tsc/Vite 构建 |
| 个人 userData 隔离 | `desktop/electron/main.ts`（`claude-code-desktop-personal`） | 源文件标记 |
| 通知 AUMID 分离 | `desktop/electron/services/appIdentity.ts` | `appIdentity.test.ts` 8 项 |
| GenUI 渲染 | `desktop/src/components/genui/**`、`MarkdownRenderer.tsx`、`AssistantMessage.tsx`、`scripts/copy-genui-assets.ts` | Markdown 65 + GenUI 4 项 |
| GenUI 宿主注入 | `src/server/services/genuiSystemPrompt.ts`、`conversationService.ts` | server 测试 2 项 |

一键校验：`powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1`  
（`-SkipTests` 只查源文件；`-BuildDir desktop\build-artifacts\personal-next` 追加校验打包产物。）

## 构建产物

| 目录 | 用途 | 状态 |
|---|---|---|
| `desktop\build-artifacts\personal-genui-inject` | 当前运行的 GenUI + 宿主注入版（条件式 UI） | 运行中（本次重启前） |
| `desktop\build-artifacts\personal-ui-default` | 默认优先 UI 的新版 | 已打包，待重启切换 |
| `desktop\build-artifacts\personal-next` | 更新脚本的默认暂存输出 / 回退版 | 每次 `-Build` 重建 |
| `desktop\build-artifacts\genui-preview` | GenUI file:// 预览验证 | 测试用，23 MB |

旧的 `electron`、`personal-aumid`、`personal-genui` 已删除（约 2.4 GB）。

ASCII junction：

- `C:\Users\26056\cc-haha-personal-ui` → `personal-ui-default`（桌面 GenUI+Inject 快捷方式已指向它）
- `C:\Users\26056\cc-haha-personal-genui-inject` → 当前运行版
- `C:\Users\26056\cc-haha-personal` → `personal-next`（更新脚本的切换入口）

官方安装目录 `C:\Claude Code Haha` 永远不碰。

## 更新流程（上游发版后）

1. 双击 `更新个人版.cmd`（或跑 `update-personal.ps1 -Build`）。
2. 脚本依次做：检查暂存目录是否被占用 → 要求工作树干净（仅容忍生成的 `preview-agent.js`）→ `git fetch upstream --tags` → `git rebase upstream/main` → 跑 `verify-personal.ps1` 全部功能校验 → 四处 `bun install` → 构建 sidecar / renderer / Electron → 打包到 `personal-next` → 再校验打包产物。
3. 有冲突按 `UPDATE_GUIDE.md` §二 的文件表处理；功能相关的冲突点见 §零 功能地图。
4. 构建成功后，用户手动退出旧个人版，启动 `personal-next\win-unpacked\Claude Code Haha.exe`（或更新快捷方式）。
5. 推送：`git push origin personal:personal-v<version>`；确认后 `git push --force-with-lease origin personal`。

## 验证矩阵

| 层 | 命令 | 期望 |
|---|---|---|
| 源文件标记 | `verify-personal.ps1 -SkipTests` | 23 项 PASS（带 BuildDir 时 28 项） |
| 桌面回归 | `bun run test -- --run src/theme/*.test.ts src/components/genui/GenuiRenderer.test.tsx src/components/markdown/MarkdownRenderer.test.tsx electron/services/appIdentity.test.ts` | 311 passed |
| 宿主注入 | `bun test -t "GenUI" src/server/__tests__/conversation-service.test.ts` | 2 passed |
| 打包产物 | `verify-personal.ps1 -SkipTests -BuildDir ...` | 28 项 PASS |

## 已知限制

- NSIS 全量安装包在本机受 Windows 符号链接权限限制；`win-unpacked` 可直接运行。
- GenUI 只在 `dsh-ui` 围栏 JSON 完整后挂载 UI；流式中途仍显示代码块。
- ECharts 使用默认配色，未完全跟随主题。
- GenUI 引擎资产（约 8 MB）由构建脚本复制，不进 git。
- 宿主注入只给主会话；team worker / subagent 不注入（其正文不渲染成聊天 UI）。

## 待办

- [x] 切换新包：已运行 `personal-genui-inject`（宿主注入生效）。
- [x] 删除全局 `~/.claude/CLAUDE.md` 的临时 GenUI 规则。
- [x] 提交宿主注入 + 校验/更新管线 + 文档，推送 `personal` / `personal-v0.7.7` 到 `b8672d7f`。
- [x] 清理旧构建（`electron`/`personal-aumid`/`personal-genui`，约 2.4 GB）。
- [x] 目录改名（2026-11-06 20:18）：`_cchaha_src_probe` → `CC-Haha_Personal`；junction、文档、memory、权限规则路径已自动更新。
- [x] 桌面脚本已归档到 `小试验/CC-Haha_GenUI增强/01_中间文件与脚本/`，桌面不再放脚本。
- [x] 迁移脚本产生的路径改动已提交 `67fbad89`，默认优先 UI 提示已提交 `7c2bdb86`；两个 commit 已推送到自己的 fork（`origin/personal` + `personal-v0.7.7`，未动 upstream）。
- [ ] 重启切换到 `personal-ui-default`（默认优先 UI）；桌面原 GenUI+Inject 快捷方式已指向新 junction。

## 自评

- 好：6 项功能都有源文件标记和回归测试；更新脚本把「fetch → rebase → 校验 → 构建 → 校验产物」串成一条命令；功能地图让冲突处理有据可查。
- 不好：工作台还没有渲染级测试。
- 下次：给工作台补一个 store 打桩的渲染测试。
