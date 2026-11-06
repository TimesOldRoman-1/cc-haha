/** Dev-only harness for visually checking the dsh-ui renderer in CC-Haha. */
import { createRoot } from 'react-dom/client'
import '../theme/globals.css'
import { GenuiRenderer } from '../components/genui/GenuiRenderer'

const theme = new URLSearchParams(window.location.search).get('theme') ?? 'white'
document.documentElement.setAttribute('data-theme', theme)

const dashboard = JSON.stringify({
  title: '2026 Q3 业务运行概览',
  gap: 14,
  items: [
    {
      type: 'row',
      items: [
        { type: 'stat', label: '总营收', value: '¥128,430', delta: '+12.4%', spark: [40, 55, 60, 85, 120] },
        { type: 'stat', label: '支付订单数', value: '1,024', delta: '-3.1%' },
        { type: 'progress', label: '季度目标完成率', value: 82, variant: 'ring' },
      ],
    },
    {
      type: 'table',
      columns: ['服务', '请求数', '成功率', '环比'],
      rows: [
        ['网关', 128430, '99.96%', '+12.4%'],
        ['检索', 86420, '99.82%', '+3.1%'],
        ['推理', 51230, '98.70%', '-1.8%'],
      ],
      total: true,
      export: true,
    },
    {
      type: 'callout',
      tone: 'info',
      title: '观察',
      content: '网关与检索稳定增长，推理服务的成功率需要关注。',
    },
    {
      type: 'row',
      items: [
        { type: 'button', label: '刷新数据', tone: 'primary', action: 'refresh-dashboard' },
        { type: 'button', label: '显示只读态', tone: 'ghost' },
      ],
    },
  ],
})

const engines = JSON.stringify({
  title: '引擎与排版',
  items: [
    {
      type: 'row',
      items: [
        { type: 'badge', label: 'Mermaid', tone: 'accent' },
        { type: 'badge', label: 'ECharts', tone: 'success' },
        { type: 'badge', label: 'KaTeX', tone: 'warn' },
      ],
    },
    {
      type: 'grid',
      cols: 2,
      items: [
        { type: 'mermaid', code: 'graph TD\n  A[输入] --> B[处理]\n  B --> C[输出]' },
        {
          type: 'echart',
          title: '月度营收',
          preset: 'bar',
          height: 220,
          data: [
            { label: '1月', value: 98 },
            { label: '2月', value: 112 },
            { label: '3月', value: 128 },
            { label: '4月', value: 145 },
            { label: '5月', value: 160 },
          ],
        },
      ],
    },
    {
      type: 'text',
      content: '行内公式 $E = mc^2$，块级公式：$$\\int_0^1 x^2\\,dx = \\frac{1}{3}$$',
    },
  ],
})

const actions: Array<{ action: string; payload: Record<string, unknown> }> = []
;(window as unknown as { __genuiActions: typeof actions }).__genuiActions = actions
const handleAction = (action: string, payload: Record<string, unknown>) => {
  actions.push({ action, payload })
}

createRoot(document.getElementById('root')!).render(
  <div className="mx-auto flex max-w-[980px] flex-col gap-6 p-6">
    <h1 className="text-lg font-semibold">GenUI preview · {theme}</h1>
    <GenuiRenderer code={dashboard} stateKey="preview-dashboard" onAction={handleAction} />
    <GenuiRenderer code={engines} stateKey="preview-engines" onAction={handleAction} />
  </div>,
)
