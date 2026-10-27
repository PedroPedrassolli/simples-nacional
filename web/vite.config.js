import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// A página é estática: o build vai para web/dist, que a Vercel publica
// (ver "outputDirectory" no vercel.json).
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
