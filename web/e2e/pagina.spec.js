import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import fs from "node:fs";

// A API é simulada com respostas reais guardadas em e2e/fixtures/ (o teste
// test/fixtures_da_pagina_test.rb confere que elas continuam iguais às da API).
const fixture = (nome) => JSON.parse(fs.readFileSync(new URL(`fixtures/${nome}`, import.meta.url)));
const ANEXO_3 = fixture("anexo-3.json");
const FATOR_R = fixture("fator-r.json");
// Empresa fictícia; test/api_cnpj_test.rb confere que é a resposta atual de api/cnpj.rb.
const CNPJ = fixture("cnpj.json");

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

async function simularCnpj(page, resposta = { status: 200, corpo: CNPJ }) {
  const chamadas = [];
  await page.route("**/api/cnpj?*", (route) => {
    chamadas.push(new URL(route.request().url()).searchParams.get("cnpj"));
    return route.fulfill({ status: resposta.status, json: resposta.corpo });
  });
  return chamadas;
}

async function consultarCnpj(page, cnpj) {
  await page.getByText("Consultar um CNPJ (opcional)").click();
  await page.getByLabel("CNPJ", { exact: true }).fill(cnpj);
  await page.getByRole("button", { name: "Consultar", exact: true }).click();
}

async function preencher(page, { periodo = "2026-03", inicio, rbt12, receita, anexo, folha }) {
  await page.getByLabel("Mês de apuração").selectOption(periodo);
  if (inicio) await page.getByLabel("Início das atividades").selectOption(inicio);
  if (rbt12 !== undefined) await page.getByLabel(/^Receita bruta (dos 12|desde)/).fill(rbt12);
  await page.getByLabel("Receita bruta do mês").fill(receita);
  await page.getByLabel("Anexo da atividade").selectOption(anexo);
  if (folha) await page.getByLabel(/^Folha de salários/).fill(folha);
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

  // A divisão entre os tributos, numa tabela com cabeçalho de linha e de coluna.
  const tabela = page.getByRole("table", { name: "Divisão do DAS entre os tributos" });
  await expect(tabela.getByRole("row", { name: "ISS 3,2409% R$ 1.296,36" })).toBeVisible();
  await expect(tabela.getByRole("rowheader")).toHaveText([
    "IRPJ",
    "CSLL",
    "Cofins",
    "PIS/Pasep",
    "CPP",
    "ISS",
  ]);

  await page.getByText("Ver a conta passo a passo").click();
  await expect(page.getByRole("heading", { level: 3 })).toHaveText([
    "Anexo",
    "Faixa",
    "Alíquota efetiva",
    "Divisão entre os tributos",
    "DAS estimado",
  ]);

  // A página converte o que foi digitado para o formato da API.
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    anexo: "3",
    rbt12: "500000.00",
    receita_mes: "40000.00",
  });
  await expect(page.locator(".resumo")).toContainText("março de 2026");
});

test("no 1º mês de atividade, não pede a receita anterior e manda o início", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByLabel("Mês de apuração").selectOption("2026-03");
  await page.getByLabel("Início das atividades").selectOption("2026-03");
  await expect(page.getByLabel(/^Receita bruta (dos 12|desde)/)).toHaveCount(0);

  await preencher(page, { receita: "20.000", anexo: "1" });
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    inicio: "2026-03",
    anexo: "1",
    receita_mes: "20000.00",
  });
});

test("com poucos meses de atividade, pede a receita desde o início", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByLabel("Mês de apuração").selectOption("2026-03");
  await page.getByLabel("Início das atividades").selectOption("2025-11");

  const campo = page.getByLabel("Receita bruta desde o início das atividades");
  await expect(campo).toHaveAccessibleDescription(/A soma dos 4 meses antes de março de 2026/);
  await preencher(page, { rbt12: "100.000", receita: "30.000", anexo: "1" });
  expect(chamadas[0].get("inicio")).toBe("2025-11");
  expect(chamadas[0].get("rbt12")).toBe("100000.00");

  // Trocar o mês de apuração para um que deixa o início fora da lista volta para "12 meses ou mais".
  await page.getByLabel("Mês de apuração").selectOption("2026-12");
  await expect(page.getByLabel("Início das atividades")).toHaveValue("");
});

test("pede a folha e mostra o Fator R só quando o anexo depende dele", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await expect(page.getByLabel(/^Folha de salários/)).toHaveCount(0);

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

test("manda a receita do ano para o sublimite e mostra o aviso da API", async ({ page }) => {
  const aviso =
    "Parte da receita do mês passou do sublimite: o ICMS dessa parte segue outra regra.";
  const chamadas = await simularApi(page, { status: 200, corpo: { ...ANEXO_3, aviso } });
  await page.goto("/");
  await page.getByLabel("Mês de apuração").selectOption("2026-10");
  await page.getByLabel("Receita bruta de 2026 até o mês anterior").fill("3.300.000");
  await page.getByLabel("Receita bruta de 2025").fill("3.500.000");
  await preencher(page, { periodo: "2026-10", rbt12: "3.900.000", receita: "400.000", anexo: "1" });

  expect(chamadas[0].get("receita_ano")).toBe("3300000.00");
  expect(chamadas[0].get("receita_ano_anterior")).toBe("3500000.00");
  await expect(page.getByText(aviso)).toBeVisible();
});

test("esconde a receita do ano em janeiro", async ({ page }) => {
  await page.goto("/");
  await page.getByLabel("Mês de apuração").selectOption("2026-01");
  await expect(page.getByLabel("Receita bruta de 2026 até o mês anterior")).toHaveCount(0);
  await expect(page.getByLabel("Receita bruta de 2025")).toBeVisible();
});

test("mostra a mensagem de erro da API", async ({ page }) => {
  const erro = "A receita bruta dos 12 meses anteriores (RBT12) precisa ser maior que zero.";
  await simularApi(page, { status: 400, corpo: { erro } });
  await page.goto("/");
  await preencher(page, { rbt12: "0", receita: "1", anexo: "1" });

  await expect(page.getByRole("alert")).toHaveText(erro);
});

test("mostra uma mensagem quando a rede falha e libera o botão", async ({ page }) => {
  await page.route("**/api/calcular?*", (route) => route.abort("internetdisconnected"));
  await page.goto("/");
  await preencher(page, { rbt12: "500000", receita: "40000", anexo: "3" });

  await expect(page.getByRole("alert")).toHaveText(
    "Não deu para calcular agora. Tente de novo em instantes.",
  );
  await expect(page.getByRole("button", { name: "Calcular" })).toBeEnabled();
});

test("consulta o CNPJ e mostra a empresa, o CNAE e a situação no Simples", async ({ page }) => {
  const chamadas = await simularCnpj(page);
  await page.goto("/");
  await consultarCnpj(page, "11.222.333/0001-81");

  await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
  await expect(page.locator("[aria-live=polite]")).toContainText("EMPRESA FICTICIA LTDA");
  await expect(
    page.getByText("6201-5/01 – Desenvolvimento de programas de computador sob encomenda"),
  ).toBeVisible();
  await expect(page.getByText("Optante pelo Simples Nacional desde 01/01/2020.")).toBeVisible();
  expect(chamadas).toEqual(["11.222.333/0001-81"]);
});

test("mostra o erro da consulta de CNPJ", async ({ page }) => {
  await simularCnpj(page, { status: 400, corpo: { erro: "CNPJ inválido: confira os números." } });
  await page.goto("/");
  await consultarCnpj(page, "11.222.333/0001-80");

  await expect(page.getByRole("alert")).toHaveText("CNPJ inválido: confira os números.");
});

test("mostra uma mensagem quando a consulta de CNPJ não responde", async ({ page }) => {
  await page.route("**/api/cnpj?*", (route) => route.abort("timedout"));
  await page.goto("/");
  await consultarCnpj(page, "11.222.333/0001-81");

  await expect(page.getByRole("alert")).toHaveText(
    "Não deu para consultar o CNPJ agora. Tente de novo em instantes.",
  );
});

test("mostra o aviso de estimativa educativa", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("não substitui o PGDAS-D nem um contador")).toBeVisible();
});

for (const tema of ["light", "dark"]) {
  test(`não tem problemas graves de acessibilidade (tema ${tema})`, async ({ page }) => {
    await simularApi(page);
    await simularCnpj(page);
    await page.emulateMedia({ colorScheme: tema });
    await page.goto("/");
    expect(await problemasGraves(page)).toEqual([]);

    // De novo com os erros dos campos e com o resultado e o passo a passo abertos.
    await page.getByRole("button", { name: "Calcular" }).click();
    expect(await problemasGraves(page)).toEqual([]);
    await preencher(page, { rbt12: "500000", receita: "40000", anexo: "3" });
    await page.getByText("Ver a conta passo a passo").click();
    expect(await problemasGraves(page)).toEqual([]);

    // E com a consulta de CNPJ aberta e respondida.
    await consultarCnpj(page, "11.222.333/0001-81");
    await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
    expect(await problemasGraves(page)).toEqual([]);
  });
}

test.describe("num celular de 320 px", () => {
  test.use({ viewport: { width: 320, height: 640 } });

  test("não tem rolagem lateral, nem com o resultado e o CNPJ abertos", async ({ page }) => {
    await simularApi(page);
    await simularCnpj(page);
    await page.goto("/");
    await consultarCnpj(page, "11.222.333/0001-81");
    await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
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
