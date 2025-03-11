import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {

  return {
    envDir: './environments',
    envPrefix: 'VITE_',
    plugins: [react()],
    build: {
      outDir: `dist/${mode}`,
      emptyOutDir: true,
    },
    base: '/',
  };
});