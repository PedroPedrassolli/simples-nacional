import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import fs from "node:fs";

// A API é simulada com respostas reais guardadas em e2e/fixtures/ (o teste
// test/fixtures_da_pagina_test.rb confere que elas continuam iguais às da API).
const fixture = (nome) => JSON.parse(fs.readFileSync(new URL(`fixtures/${nome}`, import.meta.url)));
const ANEXO_3 = fixture("anexo-3.json");
const FATOR_R = fixture("fator-r.json");
const VARIAS = fixture("varias-receitas.json");
const ANEXO_4 = fixture("anexo-4.json");
const ANO_2027 = fixture("ano-2027.json");
const SUBLIMITE = fixture("sublimite.json");
const SITUACOES = fixture("situacoes.json");
const MEI = fixture("mei.json");
// Empresa fictícia; test/api_cnpj_test.rb confere que é a resposta atual de api/cnpj.rb.
const CNPJ = fixture("cnpj.json");

// A resposta guardada que combina com o que a página pediu.
function respostaPara(parametros) {
  const atividades = parametros.get("atividades") ?? "";
  if (parametros.get("regime") === "mei") return MEI;
  if (atividades.startsWith("industria_iss")) return SITUACOES;
  if (atividades.includes(";")) return VARIAS;
  if (atividades.startsWith("fator_r")) return FATOR_R;
  if (atividades.startsWith("servicos_4")) return ANEXO_4;
  if (parametros.get("periodo")?.startsWith("2027")) return ANO_2027;
  if (parametros.has("receita_ano_anterior")) return SUBLIMITE;
  return ANEXO_3;
}

// Guarda os parâmetros de cada chamada, para conferir o que a página mandou.
async function simularApi(page, resposta = { status: 200 }) {
  const chamadas = [];
  await page.route("**/api/calcular?*", (route) => {
    const parametros = new URL(route.request().url()).searchParams;
    chamadas.push(parametros);
    return route.fulfill({
      status: resposta.status,
      json: resposta.corpo ?? respostaPara(parametros),
    });
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
  await page.getByText("Consultar um CNPJ").click();
  await page.getByLabel("CNPJ", { exact: true }).fill(cnpj);
  await page.getByRole("button", { name: "Consultar", exact: true }).click();
}

// O mês e o ano ficam em duas listas: "2026-03" escolhe março e 2026.
async function escolherMes(page, periodo) {
  const [ano, mes] = periodo.split("-");
  await page.getByLabel("Mês de apuração").selectOption(mes);
  await page.getByLabel("Ano de apuração").selectOption(ano);
}

// Uma receita só: o caso mais comum.
async function preencher(
  page,
  { periodo = "2026-03", inicio, tipo = "servicos_3", valor = "40.000", rbt12, folha },
) {
  await escolherMes(page, periodo);
  if (inicio) await page.getByLabel("Início das atividades").selectOption(inicio);
  await page.getByLabel("Tipo da receita", { exact: true }).selectOption(tipo);
  await page.getByLabel("Valor no mês", { exact: true }).fill(valor);
  if (rbt12 !== undefined) await page.getByLabel(/^Receita bruta (dos 12|desde)/).fill(rbt12);
  if (folha) await page.getByLabel(/^Folha de salários/).fill(folha);
}

const calcular = (page) => page.getByRole("button", { name: "Calcular" }).click();
const das = (page, valor = "") =>
  page.getByRole("heading", { name: new RegExp(`DAS estimado\\s*${valor}`) });

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

test("calcula uma receita e mostra o DAS, a divisão e o passo a passo", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "500.000,00" });
  await calcular(page);

  await expect(das(page, "R\\$ 3\\.988,80")).toBeFocused();
  await expect(page.getByText("Referente a março de 2026")).toBeVisible();
  await expect(page.locator(".resumo").getByText("9,9720%", { exact: true })).toBeVisible();
  await expect(page.locator(".resumo").getByText(/^III – Locação de bens móveis/)).toBeVisible();

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
    "DAS",
  ]);
  // Uma receita só: sem a tabela das receitas e sem o "fora do DAS".
  await expect(page.getByRole("heading", { name: "DAS de cada receita" })).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Fora do DAS" })).toHaveCount(0);

  await page.getByText("Ver a conta passo a passo").click();
  const conta = page.locator(".secao-passos");
  await expect(conta.getByRole("heading", { level: 3 })).toHaveText([
    "Receita do mês",
    "Total do mês",
  ]);
  await expect(conta.getByRole("heading", { level: 4 })).toHaveText([
    "Anexo",
    "Faixa",
    "Alíquota efetiva",
    "Divisão entre os tributos",
    "DAS estimado",
  ]);

  // A página converte o que foi digitado para o formato da API.
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    atividades: "servicos_3:40000.00",
    rbt12: "500000.00",
  });
});

test("separa as receitas por atividade, como no PGDAS-D", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { tipo: "revenda", valor: "30.000", rbt12: "500.000" });
  await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();

  // Com duas receitas, cada campo ganha o número da linha, e aparece a soma do mês.
  await page.getByLabel("Tipo da receita 2").selectOption("servicos_3");
  await page.getByLabel("Valor no mês 2").fill("10.000");
  await expect(page.getByText("Receita do mês: R$ 40.000,00")).toBeVisible();
  await page.locator("summary", { hasText: "Situações especiais 1" }).click();
  await page.getByLabel("ICMS já pago por substituição tributária ou antecipação").check();
  await expect(page.locator("summary", { hasText: "Situações especiais 1" })).toContainText(
    "1 marcada",
  );
  await calcular(page);

  await expect(das(page, "R\\$ 2\\.339,44")).toBeVisible();
  const receitas = page.locator(".receitas-resultado li");
  await expect(receitas).toHaveCount(2);
  await expect(receitas.first()).toContainText("Revenda de mercadorias");
  await expect(receitas.first()).toContainText("R$ 1.342,24");
  await expect(page.locator(".resumo")).toContainText("Alíquota média");
  expect(chamadas[0].get("atividades")).toBe("revenda:30000.00:st_icms;servicos_3:10000.00");

  // Remover a 2ª volta para uma receita só, sem número nos campos.
  await page.getByRole("button", { name: "Remover a receita 2" }).click();
  await expect(page.getByLabel("Valor no mês", { exact: true })).toHaveValue("30.000,00");
  await expect(page.getByText("Receita do mês: R$")).toHaveCount(0);
});

test("mostra só as situações especiais que valem para o tipo e o ano", async ({ page }) => {
  await page.goto("/");
  await escolherMes(page, "2026-03");
  const tipo = page.getByLabel("Tipo da receita", { exact: true });
  await tipo.selectOption("industria");
  await page.locator("summary", { hasText: "Situações especiais" }).click();
  await expect(page.getByLabel("PIS/Pasep e Cofins monofásicos")).toBeVisible();
  await expect(page.getByLabel("Produto com IPI mantido (Zona Franca de Manaus)")).toHaveCount(0);

  // Em 2027 o monofásico muda de nome e aparece o IPI mantido.
  await escolherMes(page, "2027-03");
  await expect(page.getByLabel("IBS e CBS com tributação concentrada (monofásica)")).toBeVisible();
  await expect(page.getByLabel("Produto com IPI mantido (Zona Franca de Manaus)")).toBeVisible();

  // A locação não tem situações especiais; a dica explica o tipo.
  await tipo.selectOption("locacao");
  await expect(page.locator("summary", { hasText: "Situações especiais" })).toHaveCount(0);
  await expect(tipo).toHaveAccessibleDescription(/Anexo III sem o ISS/);
});

test("no 1º mês de atividade, não pede a RBT12 e manda o início", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await escolherMes(page, "2026-03");
  await page.getByLabel("Início das atividades").selectOption("2026-03");
  await expect(page.getByLabel(/^Receita bruta (dos 12|desde)/)).toHaveCount(0);
  await expect(
    page.getByText("a receita dos 12 meses (RBT12) é a receita do mês × 12"),
  ).toBeVisible();

  await preencher(page, { tipo: "revenda", valor: "20.000" });
  await calcular(page);
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    inicio: "2026-03",
    atividades: "revenda:20000.00",
  });
});

test("com poucos meses de atividade, pede a receita desde o início", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await escolherMes(page, "2026-03");
  await page.getByLabel("Início das atividades").selectOption("2025-11");

  const campo = page.getByLabel("Receita bruta desde o início das atividades");
  await expect(campo).toHaveAccessibleDescription(/A soma dos 4 meses antes de março de 2026/);
  await preencher(page, { rbt12: "100.000" });
  await calcular(page);
  expect(chamadas[0].get("inicio")).toBe("2025-11");
  expect(chamadas[0].get("rbt12")).toBe("100000.00");

  // Trocar o mês de apuração para um que deixa o início fora da lista volta para "12 meses ou mais".
  await escolherMes(page, "2026-12");
  await expect(page.getByLabel("Início das atividades")).toHaveValue("");
});

test("em 2027, pede o mês anterior à parte e estima o IBS e a CBS fora do DAS", async ({
  page,
}) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { periodo: "2027-03", rbt12: "500.000" });
  await expect(
    page.getByLabel(/^Receita bruta dos 12 meses antes do mês anterior/),
  ).toHaveAccessibleDescription(/de fevereiro de 2026 a janeiro de 2027/);
  await page.getByLabel("Receita bruta de fevereiro de 2027").fill("40.000");
  await page.getByLabel(/optou por pagar o IBS e a CBS fora do DAS/).check();
  await page.getByText("Tributos pagos fora do DAS").click();
  await page.getByLabel("Alíquota da CBS").fill("8,8");
  await page.getByLabel("Créditos de CBS").fill("1.000");
  await calcular(page);

  await expect(das(page, "R\\$ 3\\.326,66")).toBeVisible();
  const fora = page.locator(".fora");
  await expect(fora.getByRole("listitem").filter({ hasText: "CBS" })).toContainText("R$ 2.520,00");
  await expect(fora.getByRole("listitem").filter({ hasText: "IBS" })).toContainText("a estimar");
  await expect(fora.getByText("Informe a alíquota do IBS para estimar.")).toBeVisible();
  await expect(fora.getByText("R$ 5.846,66")).toBeVisible();

  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2027-03",
    atividades: "servicos_3:40000.00",
    rbt12: "500000.00",
    receita_mes_anterior: "40000.00",
    ibs_cbs_fora: "1",
    aliquota_cbs: "8.8",
    creditos_cbs: "1000.00",
  });
});

test("no 1º e no 2º mês de 2027, usa a 1ª faixa sem pedir a RBT12", async ({ page }) => {
  await page.goto("/");
  await escolherMes(page, "2027-03");
  await page.getByLabel("Início das atividades").selectOption("2027-02");
  await expect(page.getByLabel(/^Receita bruta (dos 12|desde)/)).toHaveCount(0);
  await expect(
    page.getByText("No 1º e no 2º mês de atividade, a conta usa as alíquotas da 1ª faixa"),
  ).toBeVisible();
  await expect(page.getByLabel("Receita bruta de fevereiro de 2027")).toBeVisible();
});

test("aceita os meses anteriores mês a mês e mostra as somas", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await escolherMes(page, "2026-03");
  await page.getByLabel("Tipo da receita", { exact: true }).selectOption("servicos_3");
  await page.getByLabel("Valor no mês", { exact: true }).fill("40.000");
  await page.getByLabel("Mês a mês", { exact: true }).check();
  await expect(page.getByLabel(/^Receita bruta dos 12/)).toHaveCount(0);

  // Um mês em branco: a página aponta o mês, sem chamar a API.
  await calcular(page);
  const marco = page.getByLabel("Receita de março de 2025");
  await expect(marco).toBeFocused();
  await expect(marco).toHaveAccessibleDescription("Preencha este campo.");
  expect(chamadas).toHaveLength(0);

  const meses = page.locator(".mes");
  await expect(meses).toHaveCount(12);
  for (let indice = 0; indice < 12; indice++) {
    await meses
      .nth(indice)
      .getByRole("textbox")
      .fill(indice < 10 ? "40.000" : "50.000");
  }
  await expect(page.locator(".meses-somas")).toContainText("RBT12 (soma)R$ 500.000,00");
  await expect(page.locator(".meses-somas")).toContainText("Receita de 2026 até o mês anterior");
  await calcular(page);
  await expect(das(page)).toBeVisible();
  expect(chamadas[0].get("mes_2025-03")).toBe("40000.00:0:0");
  expect(chamadas[0].get("mes_2026-02")).toBe("50000.00:0:0");
  expect(chamadas[0].has("rbt12")).toBe(false);
});

test("pede a folha e mostra o Fator R só quando a receita depende dele", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await escolherMes(page, "2026-03");
  await expect(page.getByLabel(/^Folha de salários/)).toHaveCount(0);

  await preencher(page, { tipo: "fator_r", valor: "40000", rbt12: "500000", folha: "139.999,99" });
  await calcular(page);

  await expect(das(page, "R\\$ 7\\.008,00")).toBeVisible();
  await expect(page.getByText("27,99%", { exact: true })).toBeVisible();
  expect(chamadas[0].get("folha12")).toBe("139999.99");
});

test("no Anexo IV, estima a CPP paga fora do DAS", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByText("Tributos pagos fora do DAS").click();
  // Os campos da CPP só aparecem com uma receita do Anexo IV.
  await expect(page.getByLabel("Salários dos empregados")).toHaveCount(0);
  await preencher(page, { tipo: "servicos_4", rbt12: "500.000" });
  await page.getByLabel("Salários dos empregados").fill("30.000");
  await page.getByLabel("Pró-labore e autônomos").fill("5.000");
  await page.getByLabel("RAT", { exact: true }).selectOption("2");
  await page.getByLabel("FAP", { exact: true }).fill("1,5");
  await calcular(page);

  await expect(das(page, "R\\$ 3\\.086,40")).toBeVisible();
  await expect(page.locator(".fora")).toContainText("R$ 7.900,00");
  await expect(page.locator(".fora-total")).toContainText("R$ 10.986,40");
  expect([chamadas[0].get("rat"), chamadas[0].get("fap"), chamadas[0].get("pro_labore")]).toEqual([
    "2",
    "1.5",
    "5000.00",
  ]);
});

test("abre os campos do sublimite sozinho e mostra o ICMS fora do DAS", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, {
    periodo: "2026-10",
    tipo: "revenda",
    valor: "400.000",
    rbt12: "3.900.000",
  });
  // A receita pode passar do sublimite: os campos opcionais abrem sozinhos.
  await expect(page.getByLabel("Receita bruta de 2026 até o mês anterior")).toBeVisible();
  await page.getByLabel("Receita bruta de 2026 até o mês anterior").fill("3.300.000");
  await page.getByLabel("Receita bruta de 2025").fill("3.700.000");
  await page.getByText("Tributos pagos fora do DAS").click();
  await page.getByLabel("Alíquota do ICMS").fill("18");
  await page.getByLabel("Créditos de ICMS").fill("20.000");
  await calcular(page);

  expect([chamadas[0].get("receita_ano"), chamadas[0].get("receita_ano_anterior")]).toEqual([
    "3300000.00",
    "3700000.00",
  ]);
  await expect(page.locator(".guia").getByText("O ICMS deste mês não entra no DAS")).toBeVisible();
  await expect(page.locator(".fora")).toContainText("R$ 52.000,00");
});

test("esconde a receita do ano em janeiro", async ({ page }) => {
  await page.goto("/");
  await escolherMes(page, "2026-01");
  await page.getByText("Sublimite e limite do ano").click();
  await expect(page.getByLabel("Receita bruta de 2026 até o mês anterior")).toHaveCount(0);
  await expect(page.getByLabel("Receita bruta de 2025")).toBeVisible();
});

test("aponta o campo com problema sem chamar a API", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "abc" });
  await calcular(page);

  const campo = page.getByLabel("Receita bruta dos 12 meses anteriores (RBT12)");
  await expect(campo).toHaveAttribute("aria-invalid", "true");
  await expect(campo).toHaveAccessibleDescription(/Use só números, como 500\.000,00\./);
  // O foco vai para o campo com problema, e o leitor de tela lê a mensagem.
  await expect(campo).toBeFocused();
  expect(chamadas).toHaveLength(0);
});

test("aponta o primeiro campo com problema num formulário vazio", async ({ page }) => {
  await page.goto("/");
  await calcular(page);
  await expect(page.getByLabel("Mês de apuração")).toBeFocused();
  await expect(page.getByLabel("Tipo da receita", { exact: true })).toHaveAccessibleDescription(
    /Escolha o tipo da receita\./,
  );
});

test("preenche o exemplo, calcula e limpa", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByRole("button", { name: "Usar um exemplo" }).click();
  await expect(page.getByLabel("Valor no mês", { exact: true })).toHaveValue("40.000,00");
  await calcular(page);
  await expect(das(page)).toBeVisible();
  expect(chamadas[0].get("rbt12")).toBe("500000.00");

  await page.getByRole("button", { name: "Limpar" }).click();
  await expect(page.getByLabel("Valor no mês", { exact: true })).toHaveValue("");
  await expect(das(page)).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Como a conta é feita" })).toBeVisible();
});

test("formata o valor em reais ao sair do campo", async ({ page }) => {
  await page.goto("/");
  const campo = page.getByLabel("Valor no mês", { exact: true });
  await campo.fill("40000,5");
  await campo.press("Tab");
  await expect(campo).toHaveValue("40.000,50");
});

test("mostra a dica do tipo escolhido", async ({ page }) => {
  await page.goto("/");
  const campo = page.getByLabel("Tipo da receita", { exact: true });
  await expect(campo).toHaveAccessibleDescription(/Depende da atividade/);
  await campo.selectOption("servicos_4");
  await expect(campo).toHaveAccessibleDescription(/serviços advocatícios/);
});

test("avisa quando os dados mudam depois do cálculo", async ({ page }) => {
  await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "500000" });
  await calcular(page);
  await expect(das(page)).toBeVisible();
  await expect(page.getByText("Você mudou os dados")).toHaveCount(0);

  // Só formatar ("41000" → "41.000,00") não conta como mudança; mudar o valor conta.
  await page.getByLabel("Valor no mês", { exact: true }).fill("41000");
  await expect(page.getByText("Você mudou os dados depois deste cálculo")).toBeVisible();
});

test("avisa também quando os dados mudam enquanto a conta é feita", async ({ page }) => {
  // A API demora; a pessoa muda a receita antes da resposta chegar.
  await page.route("**/api/calcular?*", async (route) => {
    await new Promise((pronto) => setTimeout(pronto, 500));
    await route.fulfill({ status: 200, json: ANEXO_3 });
  });
  await page.goto("/");
  await preencher(page, { rbt12: "500000" });
  await calcular(page);
  await page.getByLabel("Valor no mês", { exact: true }).fill("41000");

  await expect(das(page)).toBeVisible();
  await expect(page.getByText("Você mudou os dados depois deste cálculo")).toBeVisible();
});

test("ignora a resposta que chega depois de limpar o formulário", async ({ page }) => {
  await page.route("**/api/calcular?*", async (route) => {
    await new Promise((pronto) => setTimeout(pronto, 500));
    await route.fulfill({ status: 200, json: ANEXO_3 });
  });
  await page.goto("/");
  await preencher(page, { rbt12: "500000" });
  await calcular(page);
  await page.getByRole("button", { name: "Limpar" }).click();

  await page.waitForResponse("**/api/calcular?*");
  await expect(das(page)).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Calcular" })).toBeEnabled();
});

test("mostra a mensagem de erro da API", async ({ page }) => {
  const erro = "A receita bruta dos 12 meses anteriores (RBT12) precisa ser maior que zero.";
  await simularApi(page, { status: 400, corpo: { erro } });
  await page.goto("/");
  await preencher(page, { rbt12: "0" });
  await calcular(page);

  await expect(page.getByRole("alert")).toHaveText(erro);
});

test("mostra uma mensagem quando a rede falha e libera o botão", async ({ page }) => {
  await page.route("**/api/calcular?*", (route) => route.abort("internetdisconnected"));
  await page.goto("/");
  await preencher(page, { rbt12: "500000" });
  await calcular(page);

  await expect(page.getByRole("alert")).toHaveText(
    "Não deu para calcular agora. Tente de novo em instantes.",
  );
  await expect(page.getByRole("button", { name: "Calcular" })).toBeEnabled();
});

test("imprime a memória de cálculo com os dados, o resultado e a conta", async ({ page }) => {
  await simularApi(page);
  // window.print abriria a janela de impressão: aqui só conta as chamadas.
  await page.addInitScript(() => {
    window.impressoes = 0;
    window.print = () => window.impressoes++;
  });
  await page.goto("/");
  await preencher(page, { tipo: "revenda", valor: "30.000", rbt12: "500.000" });
  await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();
  await page.getByLabel("Tipo da receita 2").selectOption("servicos_3");
  await page.getByLabel("Valor no mês 2").fill("10.000");
  await calcular(page);
  await page.getByRole("button", { name: "Imprimir ou salvar a memória de cálculo" }).click();
  expect(await page.evaluate(() => window.impressoes)).toBe(1);

  // Na tela a memória fica escondida; na impressão, só ela aparece.
  const memoria = page.locator(".memoria");
  await expect(memoria).toBeHidden();
  await page.emulateMedia({ media: "print" });
  await expect(memoria).toBeVisible();
  await expect(page.locator(".formulario")).toBeHidden();
  await expect(memoria.getByRole("heading", { level: 2 })).toHaveText(
    "Memória de cálculo do DAS de março de 2026",
  );
  await expect(memoria.getByText("Receita bruta dos 12 meses anteriores (RBT12)")).toBeVisible();
  await expect(
    memoria.getByRole("table", { name: "Receitas do mês" }).getByRole("row"),
  ).toHaveCount(3);
  await expect(memoria.getByRole("heading", { level: 4 })).toHaveText([
    "Receita 1: Revenda de mercadorias",
    "Receita 2: Serviços do Anexo III",
    "Total do mês",
  ]);
  await expect(memoria).toContainText("o valor a pagar é o da guia gerada no PGDAS-D");
});

test("consulta o CNPJ e mostra a empresa, o CNAE e a situação no Simples", async ({ page }) => {
  const chamadas = await simularCnpj(page);
  await page.goto("/");
  await consultarCnpj(page, "11.222.333/0001-81");

  await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
  await expect(page.locator(".cnpj [aria-live=polite]")).toContainText("EMPRESA FICTICIA LTDA");
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

test("escolhe o mês e o ano em duas listas e pede os dois", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByLabel("Mês de apuração").selectOption("10");
  await page.getByLabel("Tipo da receita", { exact: true }).selectOption("servicos_3");
  await page.getByLabel("Valor no mês", { exact: true }).fill("40.000");
  await calcular(page);

  // Falta o ano: o foco vai para ele, com a mensagem; o mês escolhido não fica marcado.
  const ano = page.getByLabel("Ano de apuração");
  await expect(ano).toBeFocused();
  await expect(ano).toHaveAccessibleDescription(/Escolha o mês e o ano de apuração\./);
  await expect(page.getByLabel("Mês de apuração")).not.toHaveAttribute("aria-invalid", "true");

  // Com os dois, o resto do formulário passa a seguir o mês escolhido.
  await ano.selectOption("2026");
  await expect(
    page.getByLabel("Início das atividades").locator("option", { hasText: "outubro de 2026" }),
  ).toHaveCount(1);
  await page.getByLabel(/^Receita bruta dos 12/).fill("500.000");
  await calcular(page);
  await expect(das(page)).toBeVisible();
  expect(chamadas[0].get("periodo")).toBe("2026-10");
});

test("calcula o DAS do MEI, com o limite do ano e o atraso", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await page.getByLabel("MEI", { exact: true }).check();
  // O MEI paga valores fixos: sem receitas do mês, meses anteriores ou fora do DAS.
  await expect(page.getByLabel("Tipo da receita", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Tributos pagos fora do DAS")).toHaveCount(0);
  await escolherMes(page, "2026-03");
  await page.getByLabel("Atividade do MEI").selectOption("comercio_servicos");
  await expect(page.getByText("Paga os valores fixos de ICMS e de ISS.")).toBeVisible();
  await page.getByLabel("Receita bruta de 2026", { exact: true }).fill("90.000");
  await page.locator("summary", { hasText: "Pagamento em atraso" }).click();
  await page.getByLabel("Data do pagamento").fill("2026-05-04");
  await calcular(page);

  await expect(page.getByRole("heading", { name: /DAS do MEI\s*R\$ 87,05/ })).toBeFocused();
  const tabela = page.getByRole("table", { name: "Valores fixos do mês" });
  await expect(tabela.getByRole("rowheader")).toHaveText(["INSS", "ICMS", "ISS", "DAS"]);
  await expect(page.locator(".guia")).toContainText(
    "passa do limite de R$ 81.000,00 em R$ 9.000,00",
  );
  await expect(page.locator(".atraso")).toContainText("Pago em 04/05/2026");
  await expect(page.locator(".atraso-total")).toContainText("R$ 91,94");
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    regime: "mei",
    mei_atividade: "comercio_servicos",
    receita_ano: "90000.00",
    pagamento: "2026-05-04",
  });

  await page.getByText("Ver a conta passo a passo").click();
  await expect(page.locator(".secao-passos h3")).toHaveText(["DAS do MEI"]);
  await expect(page.locator(".secao-passos h4").last()).toHaveText("Multa e juros");

  // A memória de cálculo também é a do MEI.
  await page.emulateMedia({ media: "print" });
  const memoria = page.locator(".memoria");
  await expect(memoria.getByRole("heading", { level: 2 })).toHaveText(
    "Memória de cálculo do DAS do MEI de março de 2026",
  );
  await expect(memoria).toContainText("Atividade");
  await expect(memoria).toContainText("PGMEI");
});

test("aplica a redução e a isenção, estima o ICMS-ST e o DIFAL e calcula o atraso", async ({
  page,
}) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { tipo: "industria_iss", valor: "30.000", rbt12: "500.000" });
  await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();
  await page.getByLabel("Tipo da receita 2").selectOption("revenda");
  await page.getByLabel("Valor no mês 2").fill("10.000");

  // O percentual aparece embaixo da caixa marcada; a isenção desmarca a redução (e o contrário).
  await page.locator("summary", { hasText: "Situações especiais 1" }).click();
  const reducao = page.getByLabel("Redução do ISS dada pelo município");
  const isencao = page.getByLabel("Isenção do ISS dada pelo município");
  await reducao.check();
  await page.getByLabel("Redução do ISS 1", { exact: true }).fill("40");
  await isencao.check();
  await expect(reducao).not.toBeChecked();
  await expect(page.getByLabel("Redução do ISS 1", { exact: true })).toHaveCount(0);
  await reducao.check();
  await expect(isencao).not.toBeChecked();
  await expect(page.getByLabel("Redução do ISS 1", { exact: true })).toHaveValue("40");
  await page.locator("summary", { hasText: "Situações especiais 2" }).click();
  await page.getByLabel("Isenção do ICMS dada pelo estado").check();

  // Cada tributo de fora do DAS é um grupo, com nomes curtos nos campos.
  await page.getByText("Tributos pagos fora do DAS").click();
  const st = page.getByRole("group", { name: "ICMS por substituição tributária" });
  await st.getByLabel("Valor da venda").fill("100");
  await st.getByLabel("MVA").fill("40");
  await st.getByLabel("Alíquota no destino").fill("18");
  await st.getByLabel("Alíquota própria").fill("12");
  const difal = page.getByRole("group", { name: "Diferencial de alíquota (DIFAL)" });
  await difal.getByLabel("Compras do mês").fill("100");
  await difal.getByLabel("Alíquota interna").fill("17,5");
  await difal.getByLabel("Alíquota interestadual").fill("12");
  await page.locator("summary", { hasText: "Pagamento em atraso" }).click();
  await page.getByLabel("Data do pagamento").fill("2026-07-15");
  await calcular(page);

  await expect(das(page, "R\\$ 2\\.505,28")).toBeVisible();
  const fora = page.locator(".fora-lista");
  await expect(fora.getByRole("listitem").filter({ hasText: "ICMS-ST" })).toContainText("R$ 13,20");
  await expect(fora.getByRole("listitem").filter({ hasText: "DIFAL" })).toContainText("R$ 5,50");
  await expect(page.locator(".atraso")).toContainText("Pago em 15/07/2026");
  await expect(page.locator(".atraso-total")).toContainText("R$ 3.086,26");
  expect(Object.fromEntries(chamadas[0])).toEqual({
    periodo: "2026-03",
    atividades: "industria_iss:30000.00:reducao_iss=40;revenda:10000.00:isencao_icms",
    rbt12: "500000.00",
    st_valor: "100.00",
    st_mva: "40",
    st_aliquota_interna: "18",
    st_aliquota_propria: "12",
    difal_valor: "100.00",
    difal_aliquota_interna: "17.5",
    difal_aliquota_interestadual: "12",
    pagamento: "2026-07-15",
  });
});

test("pede o percentual da redução e os valores fixos em reais", async ({ page }) => {
  const chamadas = await simularApi(page);
  await page.goto("/");
  await preencher(page, { rbt12: "200.000" });
  await page.locator("summary", { hasText: "Situações especiais" }).click();
  await page.getByLabel("Redução do ISS dada pelo município").check();
  await page.locator("summary", { hasText: "ICMS ou ISS em valor fixo" }).click();
  await page.getByLabel("ISS por mês").fill("abc");
  await calcular(page);

  // O valor fixo vem antes das receitas: o foco vai para ele primeiro.
  await expect(page.getByLabel("ISS por mês")).toBeFocused();
  await expect(page.getByLabel("ISS por mês")).toHaveAccessibleDescription(/Use só números/);
  const campo = page.getByLabel("Redução do ISS", { exact: true });
  await expect(campo).toHaveAccessibleDescription(/Informe a redução em %, como 40\./);
  expect(chamadas).toHaveLength(0);

  await campo.fill("40");
  await page.getByLabel("ISS por mês").fill("400");
  await calcular(page);
  await expect(das(page)).toBeVisible();
  expect(chamadas[0].get("atividades")).toBe("servicos_3:40000.00:reducao_iss=40");
  expect(chamadas[0].get("iss_fixo")).toBe("400.00");
});

test("troca o tema pelo botão e lembra a escolha", async ({ page }) => {
  await page.goto("/");
  // Escuro por padrão, como no portfólio.
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.getByRole("button", { name: "Usar tema claro" }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await expect(page.getByRole("button", { name: "Usar tema escuro" })).toBeVisible();
});

test("diz o que a calculadora faz e o que ela não faz", async ({ page }) => {
  await page.goto("/");
  const aviso = page.locator(".aviso");

  await expect(aviso.getByRole("heading")).toHaveText(["O que ela faz", "O que ela não faz"]);
  await expect(aviso.getByText("a guia oficial sai do PGDAS-D")).toBeVisible();
});

for (const tema of ["light", "dark"]) {
  test(`não tem problemas graves de acessibilidade (tema ${tema})`, async ({ page }) => {
    await simularApi(page);
    await simularCnpj(page);
    // O tema é o do botão (salvo no localStorage), como no portfólio, e não o do sistema.
    await page.addInitScript((escolhido) => localStorage.setItem("theme", escolhido), tema);
    await page.goto("/");
    await expect(page.locator("html")).toHaveAttribute("data-theme", tema);
    expect(await problemasGraves(page)).toEqual([]);

    // Com os erros dos campos.
    await calcular(page);
    expect(await problemasGraves(page)).toEqual([]);

    // Com duas receitas, situações marcadas, mês a mês e os opcionais abertos.
    await preencher(page, { tipo: "revenda", valor: "30.000" });
    await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();
    await page.getByLabel("Tipo da receita 2").selectOption("fator_r");
    await page.getByLabel("Valor no mês 2").fill("10.000");
    await page.locator("summary", { hasText: "Situações especiais 1" }).click();
    await page.getByLabel("Exportação", { exact: true }).first().check();
    await page.getByLabel("Mês a mês", { exact: true }).check();
    await page.getByText("Sublimite e limite do ano").click();
    await page.getByText("Tributos pagos fora do DAS").click();
    expect(await problemasGraves(page)).toEqual([]);

    // Com o resultado (várias receitas) e o passo a passo abertos, e desatualizado.
    await page.getByLabel("Somados", { exact: true }).check();
    await page.getByLabel(/^Receita bruta dos 12/).fill("500.000");
    await page.getByLabel("Receita de exportação nos mesmos meses").fill("0");
    await page.getByLabel(/^Folha de salários/).fill("140.000");
    await calcular(page);
    await expect(das(page)).toBeVisible();
    await page.getByText("Ver a conta passo a passo").click();
    await page.getByLabel("Valor no mês 1").fill("31.000");
    await expect(page.getByText("Você mudou os dados depois deste cálculo")).toBeVisible();
    expect(await problemasGraves(page)).toEqual([]);

    // Com o "fora do DAS" no resultado.
    await page.getByRole("button", { name: "Usar um exemplo" }).click();
    await escolherMes(page, "2027-03");
    await page.getByLabel("Receita bruta de fevereiro de 2027").fill("40.000");
    await calcular(page);
    await expect(page.locator(".fora")).toBeVisible();
    expect(await problemasGraves(page)).toEqual([]);

    // Com a consulta de CNPJ aberta e respondida.
    await consultarCnpj(page, "11.222.333/0001-81");
    await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
    expect(await problemasGraves(page)).toEqual([]);

    // E com o MEI: o formulário, o atraso aberto e o resultado.
    await page.getByLabel("MEI", { exact: true }).check();
    await page.getByLabel("Atividade do MEI").selectOption("comercio");
    await page.locator("summary", { hasText: "Pagamento em atraso" }).click();
    await page.getByLabel("Data do pagamento").fill("2026-05-04");
    await calcular(page);
    await expect(page.getByRole("heading", { name: /DAS do MEI/ })).toBeVisible();
    expect(await problemasGraves(page)).toEqual([]);
  });
}

test.describe("num celular de 320 px", () => {
  test.use({ viewport: { width: 320, height: 640 } });

  async function semRolagemLateral(page) {
    const larguras = await page.evaluate(() => ({
      conteudo: document.documentElement.scrollWidth,
      tela: document.documentElement.clientWidth,
    }));
    expect(larguras.conteudo).toBeLessThanOrEqual(larguras.tela);
  }

  test("não tem rolagem lateral com o mês a mês de 3 colunas e os opcionais abertos", async ({
    page,
  }) => {
    await page.goto("/");
    await preencher(page, { tipo: "fator_r", valor: "40.000" });
    await page.locator("summary", { hasText: "Situações especiais" }).click();
    await page.getByLabel("Exportação", { exact: true }).check();
    await page.getByLabel("Mês a mês", { exact: true }).check();
    await expect(page.locator(".meses.colunas-3")).toBeVisible();
    await page.getByLabel("Receita de março de 2025").fill("4.800.000,00");
    await page.getByText("Sublimite e limite do ano").click();
    await page.getByText("Tributos pagos fora do DAS").click();
    await semRolagemLateral(page);
  });

  test("não tem rolagem lateral com o resultado, a conta e o CNPJ abertos", async ({ page }) => {
    await simularApi(page);
    await simularCnpj(page);
    await page.goto("/");
    await consultarCnpj(page, "11.222.333/0001-81");
    await expect(page.getByText("EMPRESA FICTICIA LTDA")).toBeVisible();
    await preencher(page, { tipo: "revenda", valor: "30.000", rbt12: "500000" });
    await page.getByRole("button", { name: "+ Adicionar outra receita" }).click();
    await page.getByLabel("Tipo da receita 2").selectOption("servicos_3");
    await page.getByLabel("Valor no mês 2").fill("10.000");
    await calcular(page);
    await page.getByText("Ver a conta passo a passo").click();
    await expect(page.locator(".secao-passos h4").first()).toBeVisible();
    await semRolagemLateral(page);

    // E com o "fora do DAS" (Anexo IV).
    await page.getByRole("button", { name: "Remover a receita 2" }).click();
    await page.getByLabel("Tipo da receita", { exact: true }).selectOption("servicos_4");
    await calcular(page);
    await expect(page.locator(".fora")).toBeVisible();
    await semRolagemLateral(page);
  });

  test("os campos de fora do DAS ficam alinhados, com o % dentro da caixa", async ({ page }) => {
    await page.goto("/");
    await preencher(page, { periodo: "2027-03", tipo: "servicos_4" });
    await page.getByLabel("A empresa optou por pagar o IBS e a CBS fora do DAS").check();
    await page.getByText("Tributos pagos fora do DAS").click();
    await semRolagemLateral(page);
    // Em cada grupo, as caixas da mesma linha começam na mesma altura, e o "%" fica dentro
    // da borda da caixa.
    const problemas = await page.locator(".grupo-fora .grade").evaluateAll((grades) =>
      grades.flatMap((grade) => {
        const caixas = [
          ...grade.querySelectorAll(":scope > .campo > .reais, :scope > .campo > select"),
        ];
        const linhas = new Map();
        const erros = [];
        for (const caixa of caixas) {
          const { top, left } = caixa.getBoundingClientRect();
          const linha = [...linhas.keys()].find((chave) => Math.abs(chave - top) < 40) ?? top;
          linhas.set(linha, [...(linhas.get(linha) ?? []), Math.round(top)]);
          const sufixo = caixa.querySelector("span:last-child");
          if (sufixo && caixa.classList.contains("percentual")) {
            // A posição do texto "%" (e não da caixa do span, que inclui o espaço interno).
            const texto = document.createRange();
            texto.selectNodeContents(sufixo);
            const fora =
              texto.getBoundingClientRect().right > caixa.getBoundingClientRect().right - 8;
            if (fora) erros.push(`% colado na borda em x=${Math.round(left)}`);
          }
        }
        for (const tops of linhas.values())
          if (new Set(tops).size > 1) erros.push(`desalinhado: ${tops.join(", ")}`);
        return erros;
      }),
    );
    expect(problemas).toEqual([]);
  });

  test("não tem rolagem lateral no MEI e nas situações com atraso", async ({ page }) => {
    await simularApi(page);
    await page.goto("/");
    await page.getByLabel("MEI", { exact: true }).check();
    await escolherMes(page, "2026-03");
    await page.getByLabel("Atividade do MEI").selectOption("comercio_servicos");
    await page.getByLabel("Transportador autônomo de cargas").check();
    await calcular(page);
    await expect(page.locator(".atraso")).toBeVisible();
    await page.getByText("Ver a conta passo a passo").click();
    await semRolagemLateral(page);

    await page.getByLabel("Simples Nacional", { exact: true }).check();
    await page.getByLabel("Tipo da receita", { exact: true }).selectOption("industria_iss");
    await page.getByLabel("Valor no mês", { exact: true }).fill("30.000");
    await page.getByLabel(/^Receita bruta dos 12/).fill("500.000");
    await page.locator("summary", { hasText: "Situações especiais" }).click();
    await page.getByLabel("Redução do ISS dada pelo município").check();
    await page.getByLabel("Redução do ISS", { exact: true }).fill("40");
    await calcular(page);
    await expect(page.locator(".receitas-resultado")).toBeVisible();
    await semRolagemLateral(page);
  });
});
