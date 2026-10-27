import { defineConfig, devices } from "@playwright/test";

// Testes no navegador de verdade (Chromium), contra o build de produção da página.
// Rode "npm run build" antes: o servidor abaixo só serve a pasta dist.
export default defineConfig({
  testDir: "./e2e",
  // Na CI: falhas viram anotações no GitHub, com arquivo e linha.
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  use: {
    baseURL: "http://localhost:4174",
    locale: "pt-BR",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "npm run preview -- --port 4174 --strictPort",
    url: "http://localhost:4174",
    reuseExistingServer: !process.env.CI,
  },
});
