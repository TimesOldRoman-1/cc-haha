# SUMMARY — CC-Haha 个人定制分支

日期：2026-11-01

## 这次做了什么

把 CC-Haha 的界面定制从「改安装目录的压缩 bundle」改成「fork 上游源码改 React/CSS」，并在源码层完成两件事：

1. 新增第七套深色主题「深潮」（`deepseek`），色值取自本机 DeepSeek Harness 的 token
2. 新增「工作台」首页（问候 + 快捷操作 + 最近会话 + 项目 + 统计）

分支已推送到 `https://github.com/TimesOldRoman-1/cc-haha`（`personal` 分支）。

## 材料与产物

| 类型 | 位置 |
|---|---|
| 上游源码工作树 | 本目录（`_cchaha_src_probe`，分支 `personal`） |
| 上游基线 | `59d7575`（2026-11-01） |
| 个人提交 | `85c135d` 主题+工作台；`0953e20` 更新源改指向 fork |
| 可运行成品 | `desktop/build-artifacts/electron/win-unpacked/Claude Code HaHa.exe` |
| 验证截图 | `_theme_shots/`（`final-workbench-deepseek.png` 为最终版） |
| 分支说明 | `PERSONAL_BRANCH.md` |
| 验证脚本 | `_verify_theme.py`（CSS 变量）、`_verify_workbench.py`（真实窗口截图） |
| 调研记录 | `_workbench_research.md`（LibreChat / Cherry Studio / Cline 对比） |

## 工作流程

1. clone 上游 → 建 `personal` 分支
2. 从本机 DSH asar 提取深色 token，映射到 CC-Haha 的 `--cc-*` 变量
3. 源码新增主题 + 工作台页面
4. tsc / Vite / 主题测试（224 项）通过
5. 打包 `electron:package:dir`
6. 用独立 profile + CDP 启动真实窗口截图验收
7. `git push` 到 fork

## 踩坑

| 坑 | 解决 |
|---|---|
| `build:sidecars` 报 grammy 等模块缺失 | 还要在 `adapters/` 跑 `bun install`（共 4 处依赖） |
| Electron 二进制没下载 | `ELECTRON_MIRROR=npmmirror` + `node node_modules/electron/install.js` |
| `electron:package` 符号链接权限失败 | 改用 `electron:package:dir`；免安装目录可直接运行 |
| `contrast.test.ts` 报 Missing block | Windows clone 把 CSS 转成 CRLF，测试不做归一化；把 `globals.css` 转回 LF |
| 新主题对比度不足 | `--cc-bd-strong` 提到 `#77797F`、`--cc-tab-sep` 提到 `#2A2A2C` |
| 项目名显示成 `c--Users-...` | `projectPath` 是编码 key，显示改用 `workDir/projectRoot` |
| 测试实例抢不到单实例锁 | 启动时加 `CC_HAHA_ELECTRON_DISABLE_SINGLE_INSTANCE_LOCK=1` + 独立 `--user-data-dir` |
| Playwright 静态加载 chunk 报 ERR_CONNECTION_REFUSED | 测试服务器改 `ThreadingHTTPServer` 并加大 backlog |

## 自评

- 好：改动全部源码级、可阅读、可 rebase；主题与工作台都经过真实窗口验收；密钥/本机配置未进仓库
- 不好：项目目录还是临时名 `_cchaha_src_probe`；NSIS 安装包受限于本机符号链接权限；工作台目前只读展示，没有加拖拽排序等交互
- 下次改进：目录规范化；若长期使用，把 `publish` 配置和构建脚本固化成一条命令
