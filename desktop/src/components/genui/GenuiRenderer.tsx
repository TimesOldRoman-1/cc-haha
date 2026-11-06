/**
 * Renders a ```dsh-ui fence as the real GenUI component tree.
 *
 * The upstream renderer (`@changfenhuang/dsh-genui/embed`) is host-agnostic;
 * this file only supplies what CC-Haha must provide: a JSON spec parser, the
 * DSH theme-token bridge, the lazy engine asset base, durable state keys, and
 * the action bridge back into the conversation.
 */
import { memo, useEffect, useMemo } from 'react'
import {
  ErrorBoundary,
  GenuiActionContext,
  GenuiBlock,
  isRenderableProcess,
  processGenuiSpec,
  setGenuiAssetBase,
} from '@changfenhuang/dsh-genui/embed'
import type { GenuiSpec } from '@changfenhuang/dsh-genui/embed'
import { CodeViewer } from '../chat/CodeViewer'
import 'katex/dist/katex.min.css'
import './genui-theme.css'

export type GenuiActionHandler = (action: string, payload: Record<string, unknown>) => void

/** Parse a fence body into a renderable spec, or null when it is still partial/invalid. */
export function parseGenuiFence(code: string): GenuiSpec | null {
  const text = code.trim()
  if (!text) return null
  let value: unknown
  try {
    value = JSON.parse(text)
  } catch {
    return null
  }
  try {
    const processed = processGenuiSpec(value)
    return isRenderableProcess(processed) ? processed.spec : null
  } catch {
    return null
  }
}

/** Deterministic per-message durable state key (session + content fingerprint). */
export function genuiStateKey(namespace: string, code: string): string {
  let hash = 0x811c9dc5
  for (let i = 0; i < code.length; i += 1) {
    hash ^= code.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193)
  }
  return `${namespace}:${(hash >>> 0).toString(36)}:${code.length.toString(36)}`
}

let assetBaseReady = false
function ensureGenuiAssets(): void {
  if (assetBaseReady) return
  assetBaseReady = true
  // Relative to the renderer's document (file://.../dist/index.html in the
  // packaged app, http://localhost:1420 in dev). The copy script stages the
  // engine bundles under public/genui-assets.
  setGenuiAssetBase('./genui-assets/')
}

const DARK_THEMES = new Set(['dark', 'ink-blue', 'deepseek'])
let themeSyncInstalled = false
function ensureDarkThemeSync(): void {
  if (themeSyncInstalled || typeof document === 'undefined') return
  themeSyncInstalled = true
  const root = document.documentElement
  const apply = () => {
    const theme = root.getAttribute('data-theme') ?? ''
    document.body.toggleAttribute('data-ds-dark-theme', DARK_THEMES.has(theme))
  }
  apply()
  new MutationObserver(apply).observe(root, { attributes: true, attributeFilter: ['data-theme'] })
}

export type GenuiRendererProps = {
  code: string
  streaming?: boolean
  stateKey?: string
  onAction?: GenuiActionHandler | undefined
}

export const GenuiRenderer = memo(function GenuiRenderer({ code, streaming, stateKey, onAction }: GenuiRendererProps) {
  const spec = useMemo(() => parseGenuiFence(code), [code])

  useEffect(() => {
    ensureGenuiAssets()
    ensureDarkThemeSync()
  }, [])

  if (spec === null) {
    // Partial during streaming, or genuinely malformed: keep the honest code
    // block instead of flashing an empty shell.
    return <CodeViewer code={code} language="dsh-ui" />
  }

  return (
    <div className="genui-host my-4" data-genui-block>
      <ErrorBoundary label="GenUI">
        <GenuiActionContext.Provider value={onAction}>
          <GenuiBlock spec={spec} stateKey={stateKey} animateEntrance={!streaming} />
        </GenuiActionContext.Provider>
      </ErrorBoundary>
    </div>
  )
})
