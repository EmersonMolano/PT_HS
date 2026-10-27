import { defineConfig, loadEnv } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function figmaAssetResolver() {
  return {
    name: 'figma-asset-resolver',
    resolveId(id) {
      if (id.startsWith('figma:asset/')) {
        const filename = id.replace('figma:asset/', '');
        return path.resolve(__dirname, 'src/assets', filename);
      }
    },
  };
}

export default defineConfig(({ mode }) => {
  const viteEnv = loadEnv(mode, process.cwd(), 'VITE_');
  const apiUrl = viteEnv.VITE_API_URL?.trim();
  const isCloudflarePages = process.env.CF_PAGES === '1';

  if (mode === 'production') {
    if (!apiUrl) {
      throw new Error('VITE_API_URL es obligatorio para compilar el frontend en producción.');
    }

    if (isCloudflarePages && !apiUrl.startsWith('https://')) {
      throw new Error('En Cloudflare Pages, VITE_API_URL debe ser una URL HTTPS pública.');
    }

    if (!apiUrl.startsWith('/')) {
      let parsedApiUrl;
      try {
        parsedApiUrl = new URL(apiUrl);
      } catch {
        throw new Error('VITE_API_URL debe ser una URL absoluta o una ruta relativa que empiece por /.');
      }

      if (parsedApiUrl.protocol !== 'https:') {
        throw new Error('VITE_API_URL absoluta debe usar HTTPS en un build de producción.');
      }
    }
  }

  return {
    plugins: [figmaAssetResolver(), react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
        '@app': path.resolve(__dirname, './src/app'),
        '@features': path.resolve(__dirname, './src/features'),
        '@shared': path.resolve(__dirname, './src/shared'),
      },
    },
    server: {
      host: '0.0.0.0',
      port: 5173,
      strictPort: true,
      open: false,
    },
  };
});
