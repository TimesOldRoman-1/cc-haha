# 上游更新后，怎么把「深潮」主题和工作台带过来

你的改动都在 `personal` 分支上，上游更新只是多了一些新提交。做法是：**把你的提交重新接到上游最新代码后面**（rebase），而不是重新改一遍。

## 零、快速更新清单（2026-11-06 实战）

> 当前 Agent 可能就跑在个人版里。**不要为了构建去关应用**；构建输出是 `personal-next`，和运行中的 `electron\win-unpacked` 是不同路径。只有最后切换才需要用户手动退出。

0. 环境：工作树 `C:\Users\26056\Desktop\小试验\_cchaha_src_probe`，分支 `personal`；上游 `NanmiCoder/cc-haha`（`upstream`），origin `TimesOldRoman-1/cc-haha`。
1. 看上游：`git fetch upstream --tags` → `git log --oneline -5 upstream/main` → `git show upstream/main:desktop/package.json | grep version`。
2. 清工作树：提交有意的文档改动；把构建会改写的 `desktop/src-tauri/resources/preview-agent.js` stash；本地测试产物已在 `.git/info/exclude`。
3. 跑更新（**必须用绝对路径**，bash 会把 `.\` 的反斜杠吃掉）：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\26056\Desktop\小试验\_cchaha_src_probe\update-personal.ps1" -Build
   ```
4. 冲突：目前只会卡 `desktop/src/components/layout/Sidebar.tsx` 的 lucide import。保留上游图标，再加回 `LayoutDashboard`；`git add` 后 `GIT_EDITOR=true git rebase --continue`。
5. 构建坑：
   - `cargo` 报错：v0.7.7+ 的 `agent-desktop` 需要 Rust。**不要装 Rust**；从官方 `C:\Claude Code Haha\resources\app.asar.unpacked\src-tauri\binaries\` 复制 `agent-desktop.exe` + `agent-desktop-manifest.json` + `agent-desktop-licenses/` 到 `desktop/src-tauri/binaries/`。manifest commit 与 pin 一致时脚本会跳过 cargo。
   - `electron-builder` 的 winCodeSign 符号链接报错：只要 `win-unpacked\Claude Code Haha.exe` 已生成就算成功。
   - `contrast.test.ts` 报 `Missing block: :root, [data-theme="white"]`：`globals.css` 被 CRLF 化；`.gitattributes` 已固定 LF，必要时手动转回 LF。
6. 测试：`cd desktop && bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts`（期望 234+ 全过）。
7. 无侵入验证：`python _verify_theme.py`；`python _verify_workbench.py`。后者用隔离 `APPDATA` + `CC_HAHA_ELECTRON_DISABLE_SINGLE_INSTANCE_LOCK=1` 启动 `personal-next`。**`electron/main.ts` 的 `app.setPath('userData')` 会覆盖 `--user-data-dir`，所以必须改 `APPDATA` 环境变量。**
8. 推送：先推新分支 `git push origin personal:personal-v<version>`；确认后再 `git push --force-with-lease origin personal`。
9. 切换：**Agent 不关宿主**。用户退出旧个人版 → 双击 `Claude Code Haha (Personal v<version>).lnk`（指向 ASCII junction `C:\Users\26056\cc-haha-personal`）→ 主题重选「深潮」。旧实例还在跑时，用 `Claude Code Haha (Personal Preview).cmd` 并排预览。

## 一、日常更新（一条命令）

**如果当前运行的是 `personal-next` 里的包，先关掉它**；如果运行的是旧 `electron\win-unpacked`（包括 Agent 自己跑在里面），不要关——构建输出是另一个目录，可以并排进行。然后：

```powershell
powershell -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
```

它做四件事：

1. 检查 `build-artifacts\personal-next` 没有被运行中的实例占用（被占用会直接提示并退出）
2. `git fetch upstream --tags` 拉上游新提交
3. `git rebase upstream/main` 把你的提交重放到最新代码上
4. 如果加了 `-Build`，清理旧输出并重新打包到  
   `desktop\build-artifacts\personal-next\win-unpacked\`

没冲突就直接结束；有冲突会停下来，列出冲突文件。打包阶段即使 `electron-builder` 在签名缓存处报错（本机符号链接权限），只要 exe 已经生成，脚本仍视为成功。

> 为什么输出到 `personal-next`：它是给下一版用的独立目录，避免覆盖你正在运行的旧包；脚本只检查 `personal-next` 是否被占用。只有确实要替换 `personal-next` 时才需要关应用。官方安装目录 `C:\Claude Code Haha` 永远不碰。

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

```bash
cd desktop
bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts
```

预期 224 项左右全过（上游加测试后数量会变）。然后再打包看实际界面。

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
| 后续 | 个人版独立 userData（主题不再被官方版覆盖） |

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
bun run build                  # 会自动复制引擎资产到 public/genui-assets
bun run build:electron
bunx electron-builder --dir --publish never --config.directories.output=build-artifacts/personal-genui
```

模型侧技能（rebase 不影响，换机/重装要重做）：

```powershell
# 从 npm 包装好的 SKILL.md 安装到 Claude Code 技能目录
Copy-Item "desktop/node_modules/@changfenhuang/dsh-genui/SKILL.md" "$env:USERPROFILE\.claude\skills\genui\SKILL.md" -Force
```

验证：

```bash
cd desktop
bun run test -- --run src/components/genui/GenuiRenderer.test.tsx src/components/markdown/MarkdownRenderer.test.tsx electron/services/appIdentity.test.ts
# 77 passed（含 dsh-ui fence → GenUI block、action 回传的组件测试）
```

视觉/打包环境验证：`genui-preview.html` + `scripts/genui-preview-main.cjs`（Electron file://，含 CSP），或在真实应用里让模型输出一个 ` ```dsh-ui ` 围栏。

**已知限制**：当前只在 JSON 完整后挂载 UI（流式中途仍显示代码块）；dsh-genui 官方的逐节点流式渲染没有接。需要时再引入其 partial parser。
