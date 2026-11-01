# CC-Haha 个人定制分支（personal）

上游：https://github.com/NanmiCoder/cc-haha（MIT）
基线：`59d7575`（2026-11-01）
工作树：`desktop/`（Electron + React 18 + Tailwind v4），CLI 源码在仓库根 `src/`

> 个人分支说明，不包含任何 API key、provider 配置或本机路径。

## 这个分支做了什么

1. **新增第七套主题「深潮」**（id `deepseek`，深色）
   - 色值来自本机 DeepSeek Harness 的 token：底 `#151517`，层 `#1B1B1C/#232324/#2C2C2E`，文字 `#F9FAFB/#CFD3D6`，强调蓝 `#7AAAFF`
   - 改动位置：`types/settings.ts`、`theme/systemAppearance.ts`、`theme/globals.css`、`GeneralSettings.tsx`、`H5GeneralSettings.tsx`、`ShareImageDialog.tsx`、5 个 i18n locale、`index.html` 预水合脚本
2. **新增「工作台」首页**（侧边栏第一项）
   - 问候 + 快捷操作（新任务/定时/技能市场/设置）+ 最近会话 + 项目列表 + 统计（会话/项目/定时任务/消息）
   - 改动位置：`stores/tabStore.ts`（`home` tab 类型）、`components/layout/ContentRouter.tsx`、`components/layout/Sidebar.tsx`、`pages/WorkbenchHome.tsx`

## 构建

```bash
# 依赖（首次）
bun install                    # 仓库根
cd desktop && bun install
cd ../mobile && bun install
cd ../adapters && bun install

# 前端 + Electron 主进程
cd desktop && bun run build && bun run build:electron

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

```bash
cd desktop
bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts
# 224 passed（含新主题的 WCAG 对比度）
```

运行打包产物验证界面：

```bash
python _verify_workbench.py    # 用独立 profile + 关单实例锁，CDP 截图
```

截图在 `_theme_shots/`。

## ★ 更新跟进（上游发新版后）

先关掉个人版，然后一条命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
```

脚本会检查 `personal-next` 是否被占用、fetch + rebase、重新打包到 `build-artifacts/personal-next/`。冲突处理清单见 `UPDATE_GUIDE.md`。

远端已配好：

```bash
git remote -v
# origin   = https://github.com/TimesOldRoman-1/cc-haha.git
# upstream = https://github.com/NanmiCoder/cc-haha.git
```

## ★ 已知问题 / 待办

- **自动更新**：`build.publish` 已指向自己的 fork（`TimesOldRoman-1/cc-haha`）；`--dir` 包不生成 `app-update.yml`，实际不会自动更新。只有将来出 NSIS 安装包时才需要再确认。
- `electron:package`（NSIS）在本机因符号链接权限失败；用 `electron:package:dir` / `update-personal.ps1 -Build` 的免安装目录。
- Windows clone 会把 `globals.css` 转成 CRLF，导致 `contrast.test.ts` 误报；已将该文件转回 LF，后续编辑注意别引入 CRLF。
