import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// A página é estática: o build vai para web/dist, que a Vercel publica
// (ver "outputDirectory" no vercel.json).
export default defineConfig({
  plugins: [react()],
  server: {
    // Em "npm run dev", as chamadas a /api vão para a API publicada (só leitura e com
    // cache). Para testar uma mudança no Ruby junto com a página, use "npx vercel dev".
    proxy: {
      "/api": { target: "https://simples-nacional-br.vercel.app", changeOrigin: true },
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
