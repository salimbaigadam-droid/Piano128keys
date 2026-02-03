import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api/python': {
        target: 'http://localhost:8001',
        changeOrigin: true,
      },
      '/api/cpp': {
        target: 'http://localhost:8002',
        changeOrigin: true,
      },
      '/api/rust': {
        target: 'http://localhost:8003',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
})
