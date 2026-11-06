import { configDefaults, defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  esbuild: { jsx: 'automatic' },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@deepseek-ai/dsh-client-ui-primitives': path.resolve(__dirname, 'src/components/genui/dshPrimitivesShim.tsx'),
    },
  },
  test: {
    // Packaged source snapshots are generated output, not the active test suite.
    exclude: [...configDefaults.exclude, '**/build-artifacts/**', '**/artifacts/**'],
    environment: 'jsdom',
    globals: true,
    css: true,
    setupFiles: ['./src/test/webStorage.ts'],
    coverage: {
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.test.{ts,tsx}',
        'src/**/*.d.ts',
        'src/types/**',
        'src/mocks/**',
        'src/test/**',
        'src/vite-env.d.ts',
      ],
    },
  },
})
