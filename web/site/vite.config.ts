import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      input: {
        portada: path.resolve(__dirname, 'index.html'),
        login: path.resolve(__dirname, 'login/index.html'),
        privado: path.resolve(__dirname, 'privado/index.html'),
      },
    },
  },
})
