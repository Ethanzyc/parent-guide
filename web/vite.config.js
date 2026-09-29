import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

// Single-file output: everything inlined into dist/render.html, openable
// by double-click (file://) with zero external references.
export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile()],
  build: {
    target: 'es2020',
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: { input: 'render.html' },  // output name: dist/render.html
  },
})
