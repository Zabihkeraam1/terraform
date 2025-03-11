import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig(function (_a) {
    var mode = _a.mode;
    return {
        envDir: './environments',
        envPrefix: 'VITE_',
        plugins: [react()],
        build: {
            outDir: "dist/".concat(mode),
            emptyOutDir: true,
        },
        base: '/',
    };
});
