import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import fs from "node:fs";

// A API é simulada com respostas reais guardadas em e2e/fixtures/ (o teste
// test/fixtures_da_pagina_test.rb confere que elas continuam iguais às da API).
const fixture = (nome) => JSON.parse(fs.readFileSync(new URL(`fixtures/${nome}`, import.meta.url)));
const ANEXO_3 = fixture("anexo-3.json");
const FATOR_R = fixture("fator-r.json");

// Guarda as URLs chamadas, para conferir os parâmetros que a página mandou.
async function simularApi(page, resposta = { status: 200 }) {
  const chamadas = [];
  await page.route("**/api/calcular?*", (route) => {
    const url = new URL(route.request().url());
    chamadas.push(url.searchParams);
    const corpo =
      resposta.corpo ?? (url.searchParams.get("anexo") === "fator_r" ? FATOR_R : ANEXO_3);
    return route.fulfill({ status: resposta.status, json: corpo });
  });
  return chamadas;
}

async function preencher(page, { rbt12, receita, anexo, folha }) {
  await page.getByLabel("Receita bruta dos 12 meses anteriores (RBT12)").fill(rbt12);
  await page.getByLabel("Receita bruta do mês").fill(receita);
  await page.getByLabel("Anexo da atividade").selectOption(anexo);
  if (folha) await page.getByLabel("Folha de salários dos 12 meses anteriores").fill(folha);
  await page.getByRole("button", { name: "Calcular" }).click();
}

// Verificação automática de acessibilidade com o axe (regras WCAG 2.1 A e AA).
// Falha só com problemas "serious" ou "critical" e lista cada um com o elemento afetado.
async function problemasGraves(page) {
  const resultado = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  return resultado.violations
    .filter((violacao) => ["serious", "critical"].includes(violacao.impact))
    .map((violacao) => {
      const alvos = violacao.nodes.map((node) => node.target.join(" ")).join(" | ");
      return `${violacao.id}: ${violacao.help} → ${alvos}`;
    });
}

test("calcula e mostra o DAS, o resumo e o passo a passo", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "500.000,00", receita: "40.000", anexo: "3" });

  const resultado = page.getByRole("heading", { name: "DAS estimado: R$ 3.988,80" });
  await expect(resultado).toBeFocused();
  await expect(page.getByText("9,9720%", { exact: true })).toBeVisible();

  await page.getByText("Ver a conta passo a passo").click();
  await expect(page.getByRole("heading", { level: 3 })).toHaveText([
    "Anexo",
    "Faixa",
    "Alíquota efetiva",
    "DAS estimado",
  ]);

  // A página converte o que foi digitado para o formato da API.
  expect(Object.fromEntries(chamadas[0])).toEqual({
    anexo: "3",
    rbt12: "500000.00",
    receita_mes: "40000.00",
  });
});

test("pede a folha e mostra o Fator R só quando o anexo depende dele", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await expect(page.getByLabel("Folha de salários dos 12 meses anteriores")).toHaveCount(0);

  await preencher(page, {
    rbt12: "500000",
    receita: "40000",
    anexo: "fator_r",
    folha: "139.999,99",
  });

  await expect(page.getByRole("heading", { name: "DAS estimado: R$ 7.008,00" })).toBeVisible();
  await expect(page.getByText("27,99%", { exact: true })).toBeVisible();
  expect(chamadas[0].get("folha12")).toBe("139999.99");
});

test("aponta o campo com problema sem chamar a API", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "abc", receita: "40000", anexo: "1" });

  const campo = page.getByLabel("Receita bruta dos 12 meses anteriores (RBT12)");
  await expect(campo).toHaveAttribute("aria-invalid", "true");
  await expect(campo).toHaveAccessibleDescription(/Use só números, como 500\.000,00\./);
  expect(chamadas).toHaveLength(0);
});

test("mostra a mensagem de erro da API", async ({ page }) => {
  const erro = "A receita bruta dos 12 meses anteriores (RBT12) precisa ser maior que zero.";
  await simularApi(page, { status: 400, corpo: { erro } });
  await page.goto("/");
  await preencher(page, { rbt12: "0", receita: "1", anexo: "1" });

  await expect(page.getByRole("alert")).toHaveText(erro);
});

test("mostra o aviso de estimativa educativa", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("não substitui o PGDAS-D nem um contador")).toBeVisible();
});

for (const tema of ["light", "dark"]) {
  test(`não tem problemas graves de acessibilidade (tema ${tema})`, async ({ page }) => {
    await simularApi(page);
    await page.emulateMedia({ colorScheme: tema });
    await page.goto("/");
    expect(await problemasGraves(page)).toEqual([]);

    // De novo com os erros dos campos e com o resultado e o passo a passo abertos.
    await page.getByRole("button", { name: "Calcular" }).click();
    expect(await problemasGraves(page)).toEqual([]);
    await preencher(page, { rbt12: "500000", receita: "40000", anexo: "3" });
    await page.getByText("Ver a conta passo a passo").click();
    expect(await problemasGraves(page)).toEqual([]);
  });
}

test.describe("num celular de 320 px", () => {
  test.use({ viewport: { width: 320, height: 640 } });

  test("não tem rolagem lateral, nem com o resultado aberto", async ({ page }) => {
    await simularApi(page);
    await page.goto("/");
    await preencher(page, { rbt12: "500000", receita: "40000", anexo: "3" });
    await page.getByText("Ver a conta passo a passo").click();
    await expect(page.getByRole("heading", { level: 3 }).first()).toBeVisible();

    const larguras = await page.evaluate(() => ({
      conteudo: document.documentElement.scrollWidth,
      tela: document.documentElement.clientWidth,
    }));
    expect(larguras.conteudo).toBeLessThanOrEqual(larguras.tela);
  });
});
