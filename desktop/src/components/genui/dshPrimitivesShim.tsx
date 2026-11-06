/**
 * Minimal stand-in for `@deepseek-ai/dsh-client-ui-primitives`.
 *
 * dsh-genui's embed entry only needs four primitives. CC-Haha has no DSH
 * runtime, so GenUI's `primitive-adapter.ts` is aliased here (Vite + tsconfig
 * paths). The visuals follow CC-Haha's own theme tokens instead of DSH's.
 */
import { useState } from 'react'

/** Chrome labels used by dsh-genui's diff node (mirrors the DSH primitive). */
export type DiffBlockLabels = {
  copy?: string
  copied?: string
  codeLabel?: string
  wrapLabel?: string
  unwrapLabel?: string
  collapseAria?: string
  expandAria?: (hidden: number) => string
  collapse?: string
  expand?: (hidden: number) => string
  files?: (count: number) => string
}

/** Chrome labels used by dsh-genui's JSON tree node (mirrors the DSH primitive). */
export type JsonTreeLabels = {
  copyValue?: string
  copyJson?: string
  copyPath?: string
  copyPrettyJson?: string
  copyCompactJson?: string
  copied?: string
  copyFailed?: string
  collapseNode?: string
  expandNode?: string
  copyButtonTitle?: (action: string) => string
}

export async function writeClipboard(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    return false
  }
}

function CopyButton({ text, label = '复制', copiedLabel = '已复制' }: { text: string; label?: string; copiedLabel?: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <button
      type="button"
      className="rounded px-2 py-0.5 text-[11px]"
      style={{
        color: 'var(--dsw-alias-label-secondary, var(--cc-t2))',
        background: 'var(--dsw-alias-bg-layer-1, var(--cc-s1))',
        border: '1px solid var(--dsw-alias-border-l1, var(--cc-bd))',
      }}
      onClick={() => {
        void writeClipboard(text).then((ok) => {
          if (!ok) return
          setCopied(true)
          window.setTimeout(() => setCopied(false), 1200)
        })
      }}
    >
      {copied ? copiedLabel : label}
    </button>
  )
}

export function CodeBlock({
  code,
  lang,
  copyLabel,
  copiedLabel,
}: {
  code: string
  lang?: string
  copyLabel?: string
  copiedLabel?: string
}) {
  return (
    <div
      className="my-2 overflow-hidden rounded-md"
      style={{ border: '1px solid var(--dsw-alias-border-l1, var(--cc-bd))' }}
    >
      <div
        className="flex items-center justify-between px-3 py-1.5 text-[11px]"
        style={{
          background: 'var(--dsw-alias-bg-layer-1, var(--cc-s1))',
          color: 'var(--dsw-alias-label-tertiary, var(--cc-t3))',
        }}
      >
        <span>{lang ?? 'text'}</span>
        <CopyButton text={code} label={copyLabel} copiedLabel={copiedLabel} />
      </div>
      <pre
        className="m-0 overflow-auto px-3 py-2 text-[12.5px] leading-relaxed"
        style={{
          background: 'var(--dsw-alias-markdown-code-block, var(--cc-code))',
          color: 'var(--dsw-alias-label-primary, var(--cc-t1))',
        }}
      >
        <code>{code}</code>
      </pre>
    </div>
  )
}

export function DiffBlock({
  diffs,
  labels,
}: {
  diffs: Array<{ path: string; oldText: string | null; newText: string }>
  labels?: DiffBlockLabels
}) {
  const copyLabel = typeof labels?.copy === 'string' ? labels.copy : undefined
  const copiedLabel = typeof labels?.copied === 'string' ? labels.copied : undefined
  return (
    <div className="my-2 flex flex-col gap-2">
      {diffs.map((diff, index) => (
        <div
          key={`${diff.path}-${index}`}
          className="overflow-hidden rounded-md"
          style={{ border: '1px solid var(--dsw-alias-border-l1, var(--cc-bd))' }}
        >
          <div
            className="flex items-center justify-between px-3 py-1.5 text-[11px]"
            style={{
              background: 'var(--dsw-alias-bg-layer-1, var(--cc-s1))',
              color: 'var(--dsw-alias-label-tertiary, var(--cc-t3))',
            }}
          >
            <span className="truncate">{diff.path}</span>
            <CopyButton text={diff.newText} label={copyLabel} copiedLabel={copiedLabel} />
          </div>
          <pre
            className="m-0 overflow-auto px-3 py-2 text-[12px] leading-relaxed"
            style={{ background: 'var(--dsw-alias-markdown-code-block, var(--cc-code))' }}
          >
            {diff.oldText !== null && diff.oldText.length > 0 && (
              <span style={{ color: 'var(--dsw-alias-state-error-secondary, var(--cc-er-ink))' }}>
                {diff.oldText.split('\n').map((line) => `- ${line}\n`)}
              </span>
            )}
            <span style={{ color: 'var(--dsw-alias-state-success-secondary, var(--cc-ok-ink))' }}>
              {diff.newText.split('\n').map((line) => `+ ${line}\n`)}
            </span>
          </pre>
        </div>
      ))}
    </div>
  )
}

export function JsonTree({
  data,
  label = 'JSON',
  labels,
  copyable = false,
}: {
  data: object | unknown[]
  label?: string
  labels?: JsonTreeLabels
  copyable?: boolean
}) {
  const text = JSON.stringify(data, null, 2)
  const copyLabel = typeof labels?.copyJson === 'string' ? labels.copyJson : undefined
  const copiedLabel = typeof labels?.copied === 'string' ? labels.copied : undefined
  return (
    <div
      className="my-2 overflow-hidden rounded-md"
      style={{ border: '1px solid var(--dsw-alias-border-l1, var(--cc-bd))' }}
    >
      <div
        className="flex items-center justify-between px-3 py-1.5 text-[11px]"
        style={{
          background: 'var(--dsw-alias-bg-layer-1, var(--cc-s1))',
          color: 'var(--dsw-alias-label-tertiary, var(--cc-t3))',
        }}
      >
        <span>{label}</span>
        {copyable && <CopyButton text={text} label={copyLabel} copiedLabel={copiedLabel} />}
      </div>
      <pre
        className="m-0 overflow-auto px-3 py-2 text-[12px] leading-relaxed"
        style={{
          background: 'var(--dsw-alias-markdown-code-block, var(--cc-code))',
          color: 'var(--dsw-alias-label-primary, var(--cc-t1))',
        }}
      >
        <code>{text}</code>
      </pre>
    </div>
  )
}
