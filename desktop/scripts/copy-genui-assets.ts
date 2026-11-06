/**
 * Stage the dsh-genui lazy engine bundles into public/genui-assets so the
 * renderer's asset loader can fetch them from the packaged app (file://) and
 * the dev server. Generated output, ignored by git.
 */
import { copyFileSync, existsSync, mkdirSync, statSync } from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'

const require = createRequire(import.meta.url)
const packageDir = path.dirname(require.resolve('@changfenhuang/dsh-genui/package.json'))
const sourceDir = path.join(packageDir, 'lib', 'assets')
const targetDir = path.join(process.cwd(), 'public', 'genui-assets')

const files = ['mermaid.js', 'three.js', 'echarts-core.js', 'echarts-full.js', 'icons.js', 'maplibre.js']
mkdirSync(targetDir, { recursive: true })

let copied = 0
for (const file of files) {
  const source = path.join(sourceDir, file)
  if (!existsSync(source)) {
    console.warn(`[genui-assets] missing ${file}; skip`)
    continue
  }
  const target = path.join(targetDir, file)
  copyFileSync(source, target)
  copied += 1
  console.log(`[genui-assets] ${file} (${(statSync(target).size / 1024 / 1024).toFixed(2)} MB)`)
}
console.log(`[genui-assets] ${copied}/${files.length} bundled into ${targetDir}`)
