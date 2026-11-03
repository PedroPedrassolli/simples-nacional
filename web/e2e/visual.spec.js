import { test, expect } from "@playwright/test";
import fs from "node:fs";

// Testes visuais: comparam a página com as imagens em e2e/visual.spec.js-snapshots/. As
// imagens dependem do sistema e do navegador, então são geradas na CI (Linux) pelo workflow
// visual-update.yml. Mudou o visual de propósito? Rode o workflow no PR e confira as imagens.
const fixture = (nome) => JSON.parse(fs.readFileSync(new URL(`fixtures/${nome}`, import.meta.url)));
const VARIAS = fixture("varias-receitas.json");
const ANEXO_4 = fixture("anexo-4.json");

const OPCOES = {
  fullPage: true,
  animations: "disabled",
  maxDiffPixelRatio: 0.01,
  stylePath: new URL("visual.css", import.meta.url).pathname,
};

// Abre a página no tema pedido, com a data fixa (a memória de cálculo mostra o dia) e a
// fonte já carregada: com font-display: optional, a 1ª visita pode desenhar a fonte reserva.
async function abrir(page, tema, resposta) {
  await page.clock.setFixedTime(new Date("2026-11-02T12:00:00-03:00"));
  await page.addInitScript((escolhido) => localStorage.setItem("theme", escolhido), tema);
  if (resposta) await page.route("**/api/calcular?*", (route) => route.fulfill({ json: resposta }));
  await page.goto("/");
  await page.evaluate(() => document.fonts.ready);
  await page.reload();
  await page.evaluate(() => document.fonts.ready);
}

async function duasReceitas(page) {
  await page.getByLabel("Mês de apuração").selectOption("2026-03");
  await page.getByLabel("Tipo da receita", { exact: true }).selectOption("revenda");
  await page.getByLabel("Valor no mês", { exact: true }).fill("30.000,00");
  await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();
  await page.getByLabel("Tipo da receita 2").selectOption("servicos_3");
  await page.getByLabel("Valor no mês 2").fill("10.000,00");
  await page.locator("summary", { hasText: "Situações especiais 1" }).click();
  await page.getByLabel("ICMS já pago por substituição tributária ou antecipação").check();
  await page.getByLabel(/^Receita bruta dos 12/).fill("500.000,00");
}

for (const tema of ["dark", "light"]) {
  test(`página inicial (tema ${tema})`, async ({ page }) => {
    await abrir(page, tema);
    await expect(page).toHaveScreenshot(`inicio-${tema}.png`, OPCOES);
  });

  test(`resultado com duas receitas e a conta aberta (tema ${tema})`, async ({ page }) => {
    await abrir(page, tema, VARIAS);
    await duasReceitas(page);
    await page.getByRole("button", { name: "Calcular" }).click();
    await page.getByText("Ver a conta passo a passo").click();
    await expect(page.locator("#calculadora")).toHaveScreenshot(`resultado-${tema}.png`, OPCOES);
  });
}

test.describe("no celular", () => {
  test.use({ viewport: { width: 360, height: 780 } });

  test("mês a mês com receita, exportação e folha", async ({ page }) => {
    await abrir(page, "dark");
    await page.getByLabel("Mês de apuração").selectOption("2026-03");
    await page.getByLabel("Tipo da receita", { exact: true }).selectOption("fator_r");
    await page.locator("summary", { hasText: "Situações especiais" }).click();
    await page.getByLabel("Exportação", { exact: true }).check();
    await page.getByLabel("Mês a mês", { exact: true }).check();
    await page.getByLabel("Receita de março de 2025").fill("41.666,66");
    await expect(page.locator(".formulario")).toHaveScreenshot("mes-a-mes-celular.png", OPCOES);
  });

  test("resultado com a CPP fora do DAS", async ({ page }) => {
    await abrir(page, "light", ANEXO_4);
    await page.getByLabel("Mês de apuração").selectOption("2026-03");
    await page.getByLabel("Tipo da receita", { exact: true }).selectOption("servicos_4");
    await page.getByLabel("Valor no mês", { exact: true }).fill("40.000,00");
    await page.getByLabel(/^Receita bruta dos 12/).fill("500.000,00");
    await page.getByRole("button", { name: "Calcular" }).click();
    await expect(page.locator(".guia")).toHaveScreenshot("fora-do-das-celular.png", OPCOES);
  });
});

test("memória de cálculo impressa", async ({ page }) => {
  await abrir(page, "dark", VARIAS);
  await duasReceitas(page);
  await page.getByRole("button", { name: "Calcular" }).click();
  await expect(page.getByRole("heading", { name: /DAS estimado/ })).toBeVisible();
  await page.emulateMedia({ media: "print" });
  await expect(page).toHaveScreenshot("memoria-impressa.png", OPCOES);
});
