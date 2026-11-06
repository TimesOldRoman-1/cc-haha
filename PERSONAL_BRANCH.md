# CC-Haha 个人定制分支（personal）

上游：https://github.com/NanmiCoder/cc-haha（MIT）
当前基线：v0.7.7 / `fbbebdee`（2026-11-06）；最初基线 `59d7575`（2026-11-01）
工作树：`desktop/`（Electron + React 18 + Tailwind v4），CLI 源码在仓库根 `src/`

> 个人分支说明，不包含任何 API key、provider 配置或本机路径。

## 这个分支做了什么

1. **新增第七套主题「深潮」**（id `deepseek`，深色）
   - 色值来自本机 DeepSeek Harness 的 token：底 `#151517`，层 `#1B1B1C/#232324/#2C2C2E`，文字 `#F9FAFB/#CFD3D6`，强调蓝 `#7AAAFF`
   - 改动位置：`types/settings.ts`、`theme/systemAppearance.ts`、`theme/globals.css`、`GeneralSettings.tsx`、`H5GeneralSettings.tsx`、`ShareImageDialog.tsx`、5 个 i18n locale、`index.html` 预水合脚本
2. **新增「工作台」首页**（侧边栏第一项）
   - 问候 + 快捷操作（新任务/定时/技能市场/设置）+ 最近会话 + 项目列表 + 统计（会话/项目/定时任务/消息）
   - 改动位置：`stores/tabStore.ts`（`home` tab 类型）、`components/layout/ContentRouter.tsx`、`components/layout/Sidebar.tsx`、`pages/WorkbenchHome.tsx`
3. **GenUI：把 `dsh-ui` 围栏渲染成交互组件**（2026-11-06）
   - 依赖 `@changfenhuang/dsh-genui@0.15.0`（MIT），复用其 host-agnostic `./embed` 渲染器；CC-Haha 只补 JSON 解析、DSH 主题 token 桥接、引擎资产与 action 回传。
   - `MarkdownRenderer` 遇到 ` ```dsh-ui ` 围栏 → `components/genui/GenuiRenderer`；流式中途或 JSON 不合法时回退原代码块。
   - 组件 action（按钮/表单提交）通过 `useChatStore.sendMessage` 以 `[genui-action] ...` 消息回传给当前会话。
   - 模型侧：`src/server/services/genuiSystemPrompt.ts` 的紧凑提示（约 1.1k 字符 / 400–600 tokens）由 `conversationService.buildSessionCliArgs` 通过 `--append-system-prompt` 注入主会话；完整字段仍按需加载 `~/.claude/skills/genui/SKILL.md`。团队 worker 不注入。
   - mermaid / echarts / three / maplibre / icons 引擎由 `scripts/copy-genui-assets.ts` 从 node_modules 复制到 `public/genui-assets`，随构建进入 asar。
   - `@deepseek-ai/dsh-client-ui-primitives` 用 `components/genui/dshPrimitivesShim.tsx` 替代（Vite / Vitest alias + tsconfig paths）。
   - 视觉验证：`genui-preview.html` + `scripts/genui-preview-main.cjs` 在 file:// 下跑通浅色/深潮两套主题、Mermaid、ECharts、KaTeX 与按钮 action。

4. **Windows 通知身份与官方版分离**（2026-11-06）
   - 上游的 `WINDOWS_APP_USER_MODEL_ID` 与官方安装包共用 `com.claude-code-haha.desktop`。Windows 用开始菜单里该 AUMID 的快捷方式解析 toast 激活，而官方安装的 `Claude Code Haha.lnk` 指向官方 exe；点个人版发出的通知会启动官方版。
   - 个人版改为 `com.claude-code-haha.desktop.personal`（`electron/services/appIdentity.ts`；未改 `build.appId`，避免影响 macOS/computer-use 标识）。
   - Electron 在首次发通知时会自己创建/改写开始菜单的 `Electron.lnk`（名字来自 exe 的 ProductName 版本资源）并注册 `Electron Notification Activator` CLSID；官方 `Claude Code Haha.lnk` 保持不变。两者 AUMID 不再重叠，通知只会回到各自版本。

5. **GenUI 宿主强制注入**（2026-11-06）
   - `src/server/services/genuiSystemPrompt.ts` 的紧凑提示（1,070 字符 / 1,692 字节 ≈ 400–600 tokens）由 `conversationService.buildSessionCliArgs` 通过 `--append-system-prompt` 注入主会话；完整字段仍按需加载 `genui` skill（约 12k–13k tokens）。
   - **默认优先 UI**：除非回答只有一句话、寒暄或用户明确要纯文字，否则用 `dsh-ui`；多条目/对比/指标/步骤/表格/清单/结论汇总都必须用 UI（2026-11-06 20:28 去掉「≥3 条 / ≥2 组」阈值）。
   - 团队 worker / subagent 不注入（正文不渲染成聊天 UI）；side chat 同时保留 `SIDE_CHAT_BOUNDARY`。
   - 回归：`bun test -t "GenUI" src/server/__tests__/conversation-service.test.ts`（2 passed）。

一键功能校验：`verify-personal.ps1`（23 项源标记 + 311 项桌面测试 + 2 项注入测试；`-BuildDir` 追加产物校验）。

## 构建

```bash
# 依赖（首次）
bun install                    # 仓库根
cd desktop && bun install
cd ../mobile && bun install
cd ../adapters && bun install

# sidecar（server 代码含宿主注入）+ 前端 + Electron 主进程
cd desktop && bun run build:sidecars && bun run build && bun run build:electron

# 出免安装目录到个人版专用目录（不碰官方安装）
bunx electron-builder --dir --publish never --config.directories.output=build-artifacts/personal-next
# 产物：desktop/build-artifacts/personal-next/win-unpacked/
```

> 日常更新直接跑 `update-personal.ps1 -Build`，它会检查占用并输出到 `personal-next`。

## 数据目录隔离（解决官方版覆盖主题）

两版共用 `package.json` 的 `name`（`claude-code-desktop`），Electron 默认会给同一个 userData，localStorage 里的 `cc-haha-theme` 因此共享；官方版不认识 `deepseek`，启动时会重写它。个人版现在在 `electron/main.ts` 顶层：

```ts
app.setPath('userData', path.join(app.getPath('appData'), 'claude-code-desktop-personal'))
```

`~/.claude` 会话数据仍然共享。代价：个人版首次启动要重选一次主题；H5 token/窗口位置也是独立的。

完整 NSIS 安装包需要 Windows **开发者模式**或管理员权限（electron-builder 解压 winCodeSign 时要建符号链接）；当前机器未开启，`electron:package` 会在签名工具解压阶段退出，但 `win-unpacked/` 已经生成且可用。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1
# 23 项源标记 + 311 项桌面测试（主题 234 + Markdown 65 + GenUI 4 + AUMID 8）+ 2 项注入测试
```

只跑主题：

```bash
cd desktop
bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts
# 234 passed（含新主题的 WCAG 对比度）
```

运行打包产物验证界面：

```bash
python _verify_workbench.py    # 用独立 profile + 关单实例锁，CDP 截图
```

截图在 `_theme_shots/`。

## ★ 更新跟进（上游发新版后）

双击 `更新个人版.cmd`，或一条命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
```

脚本顺序：检查 `personal-next` 是否被占用 → 清工作树（自动 stash 生成的 `preview-agent.js`）→ fetch + rebase → **跑 `verify-personal.ps1` 校验 6 项功能** → 四处 `bun install` → 重新构建 sidecar / renderer / Electron → 打包到 `build-artifacts/personal-next/` → 再校验产物。

只有目标输出目录被运行中的实例占用时才需要关应用；当前运行的 `personal-genui-inject` 与 `personal-next` 是不同目录，可以并排构建。冲突处理清单见 `UPDATE_GUIDE.md`；切换/清理/改名见 §十。

远端已配好：

```bash
git remote -v
# origin   = https://github.com/TimesOldRoman-1/cc-haha.git
# upstream = https://github.com/NanmiCoder/cc-haha.git
```

## ★ 跨客户端技能（.agents/skills）与 ego-browser

本分支基线 `59d7575` 已包含跨客户端技能发现：`src/skills/skillRoots.ts` 会把 `~/.agents/skills` 作为技能根（默认开启）。因此 ego-browser 不需要改 fork 代码，只要保证三条链路不断：

1. `~/.agents/skills/ego-browser` → `~/.local/share/ego/ego-skills`
2. `~/.local/share/ego/ego-skills` → `~/.local/share/ego/active_version_dir/ego-skills/ego-browser`
3. `~/.local/share/ego/active_version_dir` → 当前 ego lite 安装版本目录（2026-11-03：`C:\Program Files\Citro Labs\ego lite\Application\0.6.2.7`）

**升级 ego lite 后必须重指第 3 条软链**，否则 `~/.local/bin/ego-browser` 和 CC-Haha 里的 `ego-browser` 技能会同时失效。验证：

```bash
ego-browser --version     # 期望 0.6.2.7 / chromium / node
ego-browser skill | head  # 期望 [ego-browser:skill] ...
```

**不要**在 `~/.claude/settings.json` 设 `disableAgentSkillsDirectory: true`，也不要设环境变量 `CLAUDE_CODE_DISABLE_AGENT_SKILLS_DIR=1`；这两条会直接关掉 `.agents/skills` 根。CC-Haha 重启或新会话后，技能列表里应出现 `ego-browser`。

**上游 rebase 时**：检查 `src/skills/skillRoots.ts` 仍包含 `AGENT_SKILLS_DIR`，且 `src/utils/skills/skillChangeDetector.ts` 仍监听 `.agents/skills`。若上游删改，按 `UPDATE_GUIDE.md` 的冲突流程保留这段。

## ★ 已知问题 / 待办

- **自动更新**：`build.publish` 已指向自己的 fork（`TimesOldRoman-1/cc-haha`）；`--dir` 包不生成 `app-update.yml`，实际不会自动更新。只有将来出 NSIS 安装包时才需要再确认。
- `electron:package`（NSIS）在本机因符号链接权限失败；用 `electron:package:dir` / `update-personal.ps1 -Build` 的免安装目录。
- Windows clone 会把 `globals.css` 转成 CRLF，导致 `contrast.test.ts` 误报；已将该文件转回 LF，后续编辑注意别引入 CRLF。
