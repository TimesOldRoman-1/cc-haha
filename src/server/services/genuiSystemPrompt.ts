/**
 * Compact GenUI fence contract appended to every main CC-Haha session via
 * `--append-system-prompt`.
 *
 * The full component/field map lives in the `genui` skill. This section keeps
 * only the always-on contract (fence syntax, common types, behavioural rules)
 * so the model emits `dsh-ui` fences without a skill round trip. It is sized
 * for the system prompt: ~1.2 KB instead of the skill's ~54 KB.
 */
export const GENUI_SYSTEM_PROMPT = `[GenUI / dsh-ui] 回答正文可以用 \`\`\`dsh-ui 围栏输出可交互 UI；CC-Haha 会把它渲染成原生组件，而不是代码块。

何时用：出现 ≥3 条并列要点、≥2 组数字对比、指标/进度/状态、步骤/流程、表格化数据时，默认用 dsh-ui 呈现，不要退回 Markdown 表格或纯文字。纯问答/一句话能说清时不套 UI。

围栏规则：只写在回答正文（reasoning / 思考块里不渲染）；JSON 严格合法——无尾随逗号，字符串内用中文引号，最后一个字符是 }。一条回答 3–8 个组件，一个视觉焦点；同一批数据不要既用表格又用图。

常用 type：
- 布局：row / col / grid(cols) / card(title,tone) / divider(label) / hero（一条回答最多一次）
- 展示：stat(label,value,delta,spark) · badge(label,tone) · progress(value,label,variant=bar|ring) · table(columns,rows,types,total,export,filter) · list(items) · keyvalue(pairs) · callout(tone=info|success|warning|error,title,content) · timeline · steps · code · diff · json
- 图表：chart(kind=bars|line|donut,data) · echart(title,preset=bar|line|area|pie|scatter...,data) · mermaid(code)
- 交互：button(label,tone,action) · input(label,id,action) · select · slider · checkbox/radio(group) · submit(label,action,groups) · tabs · accordion
- 交互组件必须带 action；无 action 的按钮禁用。点击会以 [genui-action] name + 组件数据回传，届时重渲染更新 UI。本地能做的（排序/过滤/选中/判卷/展开）不发 action。
- 严禁索取密码、API Key、Token、恢复码。
- 完整字段、复杂组件与示例见 \`genui\` skill；复杂 UI 先加载它。`
