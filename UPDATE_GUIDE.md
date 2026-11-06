# 上游更新后，怎么把「深潮」主题和工作台带过来

你的改动都在 `personal` 分支上，上游更新只是多了一些新提交。做法是：**把你的提交重新接到上游最新代码后面**（rebase），而不是重新改一遍。

## 零、快速更新清单（2026-11-06 现状）

> Agent 可能就跑在个人版里。**不要为了构建关应用**；默认暂存输出 `personal-next` 与运行中的 `personal-genui` 是不同目录。只有切换才需要用户手动退出。

0. 环境：工作树 `C:\Users\26056\Desktop\小试验\_cchaha_src_probe`，分支 `personal`；上游 `NanmiCoder/cc-haha`（`upstream`），origin `TimesOldRoman-1/cc-haha`。
1. 看上游：`git fetch upstream --tags` → `git log --oneline -5 upstream/main` → `git show upstream/main:desktop/package.json | grep version`。
2. 清工作树：提交个人改动（源码 + 文档 + `verify-personal.ps1` + `更新个人版.cmd`）。构建会改写的 `desktop/src-tauri/resources/preview-agent.js` 由更新脚本自动 stash，不需要手动处理。
3. 跑更新（**必须用绝对路径**，bash 会把 `.\` 的反斜杠吃掉），或双击 `更新个人版.cmd`：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\26056\Desktop\小试验\_cchaha_src_probe\update-personal.ps1" -Build
   ```
4. 脚本在 rebase 后自动跑 `verify-personal.ps1`；**任一功能标记或测试失败就停**，不会打包。
5. 冲突：常见仍是 `desktop/src/components/layout/Sidebar.tsx` 的 lucide import（保留上游图标 + `LayoutDashboard`）。按下面「功能地图」找对应文件；`git add` 后 `$env:GIT_EDITOR="true"; git rebase --continue`。
6. 构建坑：
   - `cargo` 报错：v0.7.7+ 的 `agent-desktop` 需要 Rust。**不要装 Rust**；从官方 `C:\Claude Code Haha\resources\app.asar.unpacked\src-tauri\binaries\` 复制 `agent-desktop.exe` + `agent-desktop-manifest.json` + `agent-desktop-licenses/` 到 `desktop/src-tauri/binaries/`。manifest commit 与 pin 一致时脚本会跳过 cargo。
   - `electron-builder` 的 winCodeSign 符号链接报错：只要 `win-unpacked\Claude Code Haha.exe` 已生成就算成功；脚本用 exe + 产物校验判定。
   - `contrast.test.ts` 报 `Missing block: :root, [data-theme="white"]`：`globals.css` 被 CRLF 化；`.gitattributes` 已固定 LF，必要时手动转回 LF。
7. 打包后脚本会再跑一次产物校验（exe / app.asar / sidecar / GenUI 资产）；通过后输出路径。
8. 无侵入视觉验证（可选）：`python _verify_theme.py`；`python _verify_workbench.py`。后者用隔离 `APPDATA` + `CC_HAHA_ELECTRON_DISABLE_SINGLE_INSTANCE_LOCK=1` 启动 `personal-next`。**`electron/main.ts` 的 `app.setPath('userData')` 会覆盖 `--user-data-dir`，所以必须改 `APPDATA` 环境变量。**
9. 推送：先推新分支 `git push origin personal:personal-v<version>`；确认后再 `git push --force-with-lease origin personal`。
10. 切换：**Agent 不关宿主**。用户退出旧个人版 → 启动 `personal-next\win-unpacked\Claude Code Haha.exe`（或更新快捷方式）。旧实例还在跑时，用 `Claude Code Haha (Personal Preview).cmd` 并排预览。

### 功能地图（rebase 冲突 / 回归失败时按这张表查）

| 功能 | 关键文件 | 回归测试 |
|---|---|---|
| 深潮主题 | `desktop/src/types/settings.ts`、`theme/systemAppearance.ts`、`theme/globals.css`、`index.html` | `globals.test.ts` + `bootstrapScript.test.ts` + `contrast.test.ts`（234） |
| 工作台 | `desktop/src/pages/WorkbenchHome.tsx`、`stores/tabStore.ts`、`layout/ContentRouter.tsx`、`layout/Sidebar.tsx` | 无单测；源标记 + tsc/Vite |
| userData 隔离 | `desktop/electron/main.ts` | 源标记 |
| AUMID | `desktop/electron/services/appIdentity.ts` | `appIdentity.test.ts`（8） |
| GenUI 渲染 | `desktop/src/components/genui/**`、`MarkdownRenderer.tsx`、`AssistantMessage.tsx`、`scripts/copy-genui-assets.ts`、`desktop/package.json` | `MarkdownRenderer.test.tsx`（65）+ `GenuiRenderer.test.tsx`（4） |
| GenUI 注入 | `src/server/services/genuiSystemPrompt.ts`、`conversationService.ts` | `bun test -t "GenUI" src/server/__tests__/conversation-service.test.ts`（2） |
| 构建依赖 | `desktop/src-tauri/binaries/agent-desktop.exe` + manifest | `verify-personal.ps1` 源检查 |

## 一、日常更新（一条命令）

**如果当前运行的是 `personal-next` 里的包，先关掉它**；如果运行的是其它个人版（包括 Agent 自己跑在里面），不要关——输出是另一个目录。然后双击 `更新个人版.cmd`，或：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
```

脚本顺序：

1. 检查目标输出目录是否被运行中的实例占用（占用则退出）
2. 检查工作树：只容忍生成的 `preview-agent.js` 并自动 stash，其它未提交改动会列出并退出
3. `git fetch upstream --tags` + `git rebase upstream/main`
4. 跑 `verify-personal.ps1`（源标记 + 311 项桌面测试 + 2 项注入测试）
5. 在 root / desktop / mobile / adapters 四处跑 `bun install`（上游改依赖时不会漏）
6. 构建 `build:sidecars` → `build`（含 GenUI 资产）→ `build:electron`
7. 打包到 `desktop\build-artifacts\personal-next\win-unpacked\`
8. 再跑 `verify-personal.ps1 -BuildDir ...` 校验打包产物

选项：`-SkipTests`（只查源标记/产物，测试失败时应急用）、`-SkipInstall`（依赖没变时跳过安装）、`-OutDir <dir>`（换暂存目录）。

> 为什么输出到 `personal-next`：它是给下一版用的独立目录，避免覆盖正在运行的旧包；官方安装目录 `C:\Claude Code Haha` 永远不碰。

## 二、有冲突怎么办

先看冲突在哪：

```bash
git status
```

你的改动集中在这些文件，冲突通常也只会出在这里：

| 文件 | 你的改动 | 冲突处理 |
|---|---|---|
| `desktop/src/theme/globals.css` | 新增 `[data-theme="deepseek"]` 块 + 9 组暗色选择器 | 保留上游对其它主题的修改，把你的 deepseek 块整段留下 |
| `desktop/src/types/settings.ts` | `THEME_MODES` / `DARK_THEME_MODES` 加 `deepseek` | 在上游的新列表里再补上 `deepseek` |
| `desktop/src/theme/systemAppearance.ts` | `THEME_BACKGROUNDS` 加 `deepseek: '#151517'` | 补一行 |
| `desktop/src/pages/settings/GeneralSettings.tsx` | 设置页主题选项 | 在上游数组末尾加 deepseek |
| `desktop/src/pages/settings/H5GeneralSettings.tsx` | H5 主题选项 | 同上 |
| `desktop/src/features/tokenUsage/ShareImageDialog.tsx` | 分享图主题映射 | 加一行 |
| `desktop/src/i18n/locales/*.ts` | `workbench.*` + `appearance.deepseek` 文案 | 补上缺失的 key（5 个语言都要） |
| `desktop/index.html` | `DARK` 数组、`BACKGROUND`、启动背景色 | 各补 `deepseek` / `#151517` |
| `desktop/src/pages/WorkbenchHome.tsx` | 整个工作台页面 | 新文件，一般只在 Sidebar/ContentRouter 冲突 |
| `desktop/src/stores/tabStore.ts` | `HOME_TAB_ID` + `home` 类型 | 与上游改动合并 |
| `desktop/src/components/layout/ContentRouter.tsx` | `home` 分支 | 与上游改动合并 |
| `desktop/src/components/layout/Sidebar.tsx` | 工作台入口 | 与上游改动合并 |
| `desktop/electron/services/appIdentity.ts` | Windows AUMID 改为 `com.claude-code-haha.desktop.personal` | 保留个人 AUMID；详见下文「八」 |
| `desktop/electron/services/appIdentity.test.ts` | 断言 AUMID = `${build.appId}.personal` | 保留个人断言 |
| `desktop/package.json` | `@changfenhuang/dsh-genui` 依赖 + `prepare:genui-assets` | 保留依赖与脚本；详见下文「九」 |
| `desktop/vite.config.ts` / `vitest.config.ts` | `@deepseek-ai/dsh-client-ui-primitives` alias | 保留 alias |
| `desktop/tsconfig.json` | 同上 paths 映射 | 保留 paths |
| `desktop/src/components/markdown/MarkdownRenderer.tsx` | `dsh-ui` 围栏分支 | 保留 `DSH_UI_LANGUAGE` 分支（在 mermaid 分支前） |
| `desktop/src/components/chat/AssistantMessage.tsx` | GenUI action 回传 | 保留 `handleGenuiAction` 与两个 props |
| `desktop/src/components/genui/**` | 渲染器 / 主题桥 / shim / 测试 | 新文件，一般无冲突 |
| `src/server/services/genuiSystemPrompt.ts` | 紧凑 GenUI 系统提示（约 1.1k 字符） | 新文件，保留；详见下文「九」 |
| `src/server/services/conversationService.ts` | `buildSessionCliArgs` 注入 `--append-system-prompt` | 保留 `appendSystemPrompt` 合并逻辑（团队 worker 不注入） |
| `src/server/__tests__/conversation-service.test.ts` | GenUI 注入的两条测试 | 保留；不要删「injects the compact GenUI system prompt」用例 |

**如果上游给 `--cc-*` 加了新变量**：要在 deepseek 块里补上，否则新组件在你的主题下会拿到未定义值。补完跑测试，`contrast.test.ts` 会告诉你哪个颜色不达标。

解决完一个文件：

```bash
git add <file>
git rebase --continue
```

想放弃这次更新、回到更新前：

```bash
git rebase --abort
```

## 三、更新后必须验证

一条命令（推荐）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1
```

它会检查 6 项功能的源文件标记，并跑：

```bash
cd desktop
bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts \
  src/components/genui/GenuiRenderer.test.tsx src/components/markdown/MarkdownRenderer.test.tsx \
  electron/services/appIdentity.test.ts
# 311 passed

cd ..
bun test -t "GenUI" src/server/__tests__/conversation-service.test.ts
# 2 passed
```

数量会随上游加测试变化；关键是 0 失败。打包后再用 `-BuildDir` 校验 exe / app.asar / sidecar / GenUI 资产。

## 四、冲突太多怎么办

可以不用 rebase，改成「拿上游最新代码 + 只挑你自己的提交」：

```bash
git checkout upstream/main
git checkout -b personal-new
git cherry-pick 85c135d   # 主题 + 工作台
git cherry-pick 0953e20   # publish 指向自己的 fork
git cherry-pick e688957   # 文档
```

冲突处理和上面一样。确认没问题后把 `personal` 指向新分支：

```bash
git branch -f personal personal-new
git checkout personal
```

## 五、你的提交清单

| commit | 内容 |
|---|---|
| `85c135d` | 深潮主题 + 工作台 |
| `0953e20` | 自动更新源指向自己的 fork |
| `e688957` | 项目复盘文档 |
| `3e198207` / `608a42d0` | 个人版独立 userData / ego-browser 技能说明 |
| `52e1e569` / `0c1f7b0c` / `f8fe610c` | v0.7.7 构建复用 / CSS LF / 更新文档 |
| `289792ef` | 个人版 AUMID 分离 |
| `87c5ef70` | GenUI 渲染器（`dsh-ui` 围栏） |
| 待提交 | GenUI 宿主注入 + 校验/更新脚本 + 文档整理 |

> 以 `git log --oneline upstream/main..personal` 为准；上表只用于冲突时快速识别。

`git log --oneline upstream/main..personal` 随时可看自己的提交。

## 六、跨客户端技能（.agents/skills）

本分支依赖上游的 `.agents/skills` 发现（`src/skills/skillRoots.ts`，基线 `59d7575`）。rebase 后先确认：

```bash
grep -n "AGENT_SKILLS_DIR" src/skills/skillRoots.ts
grep -n "agents" src/utils/skills/skillChangeDetector.ts
```

若上游改动这段，保留 `.agents` 根；否则 ego-browser 等跨客户端技能会消失。ego lite 升级后还要重指 `~/.local/share/ego/active_version_dir`，详见 `PERSONAL_BRANCH.md` 的「跨客户端技能与 ego-browser」一节。

## 七、v0.7.7+ 构建：agent-desktop 原生 sidecar

v0.7.7 起 `bun run build:sidecars` 会用 Rust 编译 `native/agent-desktop`（`cargo +stable`）。本机没有 cargo 时**不要装 Rust**：官方安装包 `C:\Claude Code Haha\resources\app.asar.unpacked\src-tauri\binaries\` 已带同 commit 的预编译二进制。

复制这三项到 `desktop/src-tauri/binaries/`：

- `agent-desktop.exe`
- `agent-desktop-manifest.json`
- `agent-desktop-licenses/`

`native-agent-desktop.ts` 会检查 manifest 的 `commit` 是否等于 `AGENT_DESKTOP_UPSTREAM_COMMIT`，一致就跳过 cargo；不一致（上游升级了 Rust pin）时，需要从新版官方安装包重新复制，或安装 Rust 后编译。

**CRLF 误报**：`contrast.test.ts` 如果报 `Missing block: :root, [data-theme="white"]`，是 `globals.css` 被转成 CRLF；`.gitattributes` 已固定 `desktop/src/theme/globals.css text eol=lf`，rebase 后确认这条规则还在。

**构建验证**：`personal-next\win-unpacked\Claude Code Haha.exe` 应显示 v0.7.7；`resources/app.asar.unpacked/src-tauri/binaries/` 下应有 `agent-desktop.exe` 和 `claude-sidecar-*.exe`。

## 八、Windows 通知身份（个人版 AUMID，2026-11-06）

个人版与官方版不能再共用 AppUserModelID，否则点击个人版的通知会启动官方 exe：

- 官方安装包开始菜单 `Claude Code Haha.lnk`：AUMID `com.claude-code-haha.desktop`，ToastActivatorCLSID → `C:\Claude Code Haha\Claude Code Haha.exe`
- 个人分支 `desktop/electron/services/appIdentity.ts` 使用 `com.claude-code-haha.desktop.personal`
- 个人版首次发通知时，Electron 自动创建/改写开始菜单 `Electron.lnk`（exe 版本资源 ProductName 是 Electron），AUMID 为个人值、CLSID 指向个人 exe；官方快捷方式不动

**rebase 时**：上游若改 `appIdentity.ts` / `appIdentity.test.ts`，保留个人 AUMID 与测试断言；不要把 `build.appId` 改成个人值（macOS bundle id 和 computer-use 签名标识都依赖它）。验证：

```powershell
# 两个 AUMID 必须各自唯一
$sh = New-Object -ComObject Shell.Application
$p = $sh.Namespace("$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Filter *.lnk |
  ForEach-Object { $i=$p.ParseName($_.Name); "$($_.Name) -> $($i.ExtendedProperty('System.AppUserModel.ID'))" }
```

预期：`Claude Code Haha.lnk -> com.claude-code-haha.desktop`，`Electron.lnk -> com.claude-code-haha.desktop.personal`。

**注意**：旧版个人包（共用官方 AUMID）如果还在磁盘上，运行它会把 `Electron.lnk` 改回旧 AUMID，通知又会跑到官方版。切到新版后不要再启动旧包；留作回退时先确认。

## 九、GenUI 增强（`dsh-ui` 围栏，2026-11-06）

个人版复用 `@changfenhuang/dsh-genui` 的 host-agnostic 渲染器，把回答里的 ` ```dsh-ui ` 围栏渲染成原生交互组件（指标卡、表格、Mermaid、ECharts、表单、测验等）。

rebase/更新后要保留：

- `desktop/package.json` 的 `@changfenhuang/dsh-genui` 依赖与 `prepare:genui-assets`
- `desktop/src/components/genui/`（渲染器、主题桥、primitive shim、测试）
- `MarkdownRenderer.tsx` 的 `dsh-ui` 分支与两个 props（`genuiStateNamespace` / `onGenuiAction`）
- `AssistantMessage.tsx` 的 action 回传
- Vite / Vitest alias 与 tsconfig paths 的 `@deepseek-ai/dsh-client-ui-primitives`

构建：

```bash
cd desktop
bun install                    # 首次/依赖变更后
bun run build:sidecars         # server 代码（含宿主注入）变了就必须重编
bun run build                  # 会自动复制引擎资产到 public/genui-assets
bun run build:electron
bunx electron-builder --dir --publish never --config.directories.output=build-artifacts/personal-next
```

模型侧技能（rebase 不影响，换机/重装要重做）：

```powershell
# 从 npm 包装好的 SKILL.md 安装到 Claude Code 技能目录
Copy-Item "desktop/node_modules/@changfenhuang/dsh-genui/SKILL.md" "$env:USERPROFILE\.claude\skills\genui\SKILL.md" -Force
```

宿主注入（2026-11-06 追加）：

- `src/server/services/genuiSystemPrompt.ts` 导出 `GENUI_SYSTEM_PROMPT`：**1,087 字符 / 1,703 字节 / 250 汉字 ≈ 400–600 tokens**，只含围栏语法、常用 type 与行为规则；完整字段仍指向 `genui` skill（约 54 KB ≈ 12k–13k tokens，按需加载）。
- `conversationService.ts` 的 `buildSessionCliArgs` 对主会话追加 `--append-system-prompt <GENUI + side boundary>`；**团队 worker / subagent 不注入**（它们的正文不渲染成聊天 UI）。
- 该提示进入 system prompt，不是每轮一条用户消息；命中 prompt cache 后每轮边际成本只有缓存读取。
- 验证：`bun test -t "GenUI" src/server/__tests__/conversation-service.test.ts` → 2 passed；重编 sidecar 后体积比旧包大 5,632 字节（新增提示）。
- 改了 server 代码必须重跑 `bun run build:sidecars`，再打包；`desktop/dist` 无需重建（前端未变）。

验证：

```bash
cd desktop
bun run test -- --run src/components/genui/GenuiRenderer.test.tsx src/components/markdown/MarkdownRenderer.test.tsx electron/services/appIdentity.test.ts
# 77 passed（含 dsh-ui fence → GenUI block、action 回传的组件测试）
```

视觉/打包环境验证：`genui-preview.html` + `scripts/genui-preview-main.cjs`（Electron file://，含 CSP），或在真实应用里让模型输出一个 ` ```dsh-ui ` 围栏。

**已知限制**：当前只在 JSON 完整后挂载 UI（流式中途仍显示代码块）；dsh-genui 官方的逐节点流式渲染没有接。需要时再引入其 partial parser。

## 十、切换、清理与目录命名（2026-11-06）

### 当前构建布局

| 目录 | 内容 | 状态 |
|---|---|---|
| `personal-genui` | GenUI 渲染，旧宿主提示靠全局 CLAUDE.md | 运行中（Agent 跑在里面） |
| `personal-genui-inject` | GenUI 渲染 + 宿主注入 | 已打包验证，待切换 |
| `personal-next` | 更新脚本默认暂存输出 | 下次更新重建 |
| `personal-aumid` / `electron` | 旧版本 | 仅回退 |

ASCII junction：`cc-haha-personal-genui` / `cc-haha-personal-genui-inject` / `cc-haha-personal`（→ `personal-next`）。

### 切换步骤（必须用户手动）

1. 退出当前 `personal-genui` 实例（Agent 会话会一起结束）。
2. 双击桌面 `Claude Code Haha (Personal v0.7.7 GenUI+Inject).lnk`，或运行 `C:\Users\26056\cc-haha-personal-genui-inject\Claude Code Haha.exe`。
3. 确认新会话不加载 `genui` skill 也能输出 `dsh-ui` 围栏（宿主注入生效）。
4. 删除全局 `~/.claude/CLAUDE.md` 里「## GenUI 结构化输出」整段（临时兜底，留着会让模型额外加载完整 skill）。
5. 新包稳定后，把日常快捷方式改指 `personal-next`（或下一次更新脚本的产物）。

### 可以清理的旧构建（确认后手动执行）

| 目录 | 大小 |
|---|---|
| `desktop\build-artifacts\electron` | 807 MB |
| `desktop\build-artifacts\personal-aumid` | 815 MB |
| `desktop\build-artifacts\personal-genui` | 840 MB（切换稳定后） |

合计约 2.4 GB。**删除前确认没有进程从这些目录运行**；不要按路径通配杀进程。

```powershell
# 先列出占用者，确认输出为空再删
Get-Process 'Claude Code Haha' -ErrorAction SilentlyContinue | Select-Object Id, Path
# Remove-Item -LiteralPath 'desktop\build-artifacts\electron' -Recurse -Force
```

### 目录命名

工作树仍叫临时名 `_cchaha_src_probe`。规范化需要先关闭所有个人版实例（运行中的 exe 锁住路径），然后：

1. 重命名目录 → 例如 `CC-Haha_Personal`。
2. 重指 junction `cc-haha-personal*` 的 Target。
3. 更新快捷方式 Target。
4. 同步改 `update-personal.ps1` 文档里的绝对路径、`SUMMARY.md`、`UPDATE_GUIDE.md` 与 memory。

未完成前，所有命令仍使用 `C:\Users\26056\Desktop\小试验\_cchaha_src_probe`。
