/**
 * Type-only shims for DSH packages that dsh-genui's embed entry references.
 * The imports are erased at runtime; only `@deepseek-ai/dsh-client-ui-primitives`
 * has a runtime import, and Vite aliases that to ./components/genui/dshPrimitivesShim.
 */
declare module '@deepseek-ai/dsh-api-session-controller/client' {
  import type { SessionId } from '@deepseek-ai/dsh-session/types'
  export interface SessionListState {
    ids: SessionId[]
  }
}
