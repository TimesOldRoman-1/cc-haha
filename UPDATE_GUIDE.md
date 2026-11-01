# 上游更新后，怎么把「深潮」主题和工作台带过来

你的改动都在 `personal` 分支上，上游更新只是多了一些新提交。做法是：**把你的提交重新接到上游最新代码后面**（rebase），而不是重新改一遍。

## 一、日常更新（一条命令）

```powershell
powershell -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
```

它做三件事：

1. `git fetch upstream --tags` 拉上游新提交
2. `git rebase upstream/main` 把你的两个提交重放到最新代码上
3. 如果加了 `-Build`，重新打包出 `desktop\build-artifacts\electron\win-unpacked\`

没冲突就直接结束；有冲突会停下来，列出冲突文件。

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
