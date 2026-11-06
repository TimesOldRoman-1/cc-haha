import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { MarkdownRenderer } from '../markdown/MarkdownRenderer'
import { GenuiRenderer, parseGenuiFence } from './GenuiRenderer'

const METRIC_SPEC = JSON.stringify({
  title: '2026 Q3 业务运行概览',
  items: [
    {
      type: 'row',
      items: [
        { type: 'stat', label: '总营收', value: '¥128,430', delta: '+12.4%', spark: [40, 55, 60, 85, 120] },
        { type: 'stat', label: '支付订单数', value: '1,024', delta: '-3.1%' },
      ],
    },
  ],
})

describe('parseGenuiFence', () => {
  it('accepts a complete spec and rejects streaming halves', () => {
    expect(parseGenuiFence(METRIC_SPEC)).not.toBeNull()
    expect(parseGenuiFence('{"title":"half"')).toBeNull()
    expect(parseGenuiFence('')).toBeNull()
  })
})

describe('GenuiRenderer', () => {
  it('mounts the dsh-genui block tree for a complete fence', () => {
    const { container } = render(<GenuiRenderer code={METRIC_SPEC} />)
    expect(container.querySelector('[data-genui-block]')).not.toBeNull()
    expect(screen.getByText('2026 Q3 业务运行概览')).toBeTruthy()
    expect(screen.getByText('总营收')).toBeTruthy()
  })

  it('keeps the raw code block while the fence is incomplete', () => {
    const { container } = render(<GenuiRenderer code={'{"title":"half"'} />)
    expect(container.querySelector('[data-genui-block]')).toBeNull()
  })
})

describe('MarkdownRenderer dsh-ui fence', () => {
  it('turns a complete ```dsh-ui fence into a GenUI block', () => {
    const { container } = render(
      <MarkdownRenderer content={'```dsh-ui\n' + METRIC_SPEC + '\n```'} />,
    )
    expect(container.querySelector('[data-genui-block]')).not.toBeNull()
    expect(screen.getByText('2026 Q3 业务运行概览')).toBeTruthy()
  })
})
