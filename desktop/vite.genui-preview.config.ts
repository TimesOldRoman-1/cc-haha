/** Builds genui-preview.html as a file:// bundle for the packaged-environment smoke test. */
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@deepseek-ai/dsh-client-ui-primitives': path.resolve(__dirname, 'src/components/genui/dshPrimitivesShim.tsx'),
    },
  },
  build: {
    outDir: 'build-artifacts/genui-preview',
    emptyOutDir: true,
    rollupOptions: {
      input: path.resolve(__dirname, 'genui-preview.html'),
    },
  },
})
