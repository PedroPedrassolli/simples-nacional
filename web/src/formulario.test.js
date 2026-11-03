import { test } from "node:test";
import assert from "node:assert/strict";
import {
  conferir,
  EXEMPLO,
  FORA_VAZIO,
  linhasDaMemoria,
  novaReceita,
  resumoDasReceitas,
  VAZIO,
} from "./formulario.js";

// Um formulário preenchido, com o que cada teste mudar por cima.
function formulario(mudancas = {}) {
  return {
    ...VAZIO,
    periodo: "2026-03",
    rbt12: "500.000,00",
    receitas: [novaReceita(1, "servicos_3", "40.000")],
    ...mudancas,
  };
}

test("monta os parâmetros da API do exemplo", () => {
  const { parametros, erros } = conferir(EXEMPLO);
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, {
    periodo: "2026-03",
    atividades: "servicos_3:40000.00",
    rbt12: "500000.00",
  });
});

test("junta várias receitas com as situações marcadas", () => {
  const receitas = [
    { ...novaReceita(1, "revenda", "30.000"), opcoes: ["st_icms", "monofasico"] },
    { ...novaReceita(2, "servicos_3", "10.000,50"), opcoes: ["iss_retido"] },
  ];
  const { parametros } = conferir(formulario({ receitas }));
  assert.equal(
    parametros.atividades,
    "revenda:30000.00:st_icms+monofasico;servicos_3:10000.50:iss_retido",
  );
});

test("ignora a situação que não vale para o tipo ou para o ano", () => {
  // Trocou o tipo depois de marcar; o IPI mantido só existe a partir de 2027.
  const receitas = [
    { ...novaReceita(1, "servicos_3", "1"), opcoes: ["st_icms"] },
    { ...novaReceita(2, "industria", "1"), opcoes: ["ipi_mantido"] },
  ];
  assert.equal(
    conferir(formulario({ receitas })).parametros.atividades,
    "servicos_3:1.00;industria:1.00",
  );
  const em2027 = conferir(formulario({ periodo: "2027-03", receitas })).parametros.atividades;
  assert.equal(em2027, "servicos_3:1.00;industria:1.00:ipi_mantido");
});

test("aponta o erro de cada campo", () => {
  const receitas = [
    novaReceita(1, "", " "),
    novaReceita(2, "revenda", "0"),
    novaReceita(3, "revenda", "abc"),
  ];
  const { erros } = conferir({ ...VAZIO, rbt12: "abc", receitas });
  assert.deepEqual(erros, {
    periodo: "Escolha o mês de apuração.",
    rbt12: "Use só números, como 500.000,00.",
    "receitas.0.tipo": "Escolha o tipo da receita.",
    "receitas.0.valor": "Preencha este campo.",
    "receitas.1.valor": "Use um valor maior que zero, como 40.000,00.",
    "receitas.2.valor": "Use um valor maior que zero, como 40.000,00.",
  });
});

test("pede a RBT12 quando o mês está escolhido", () => {
  assert.deepEqual(conferir(formulario({ rbt12: "abc" })).erros, {
    rbt12: "Use só números, como 500.000,00.",
  });
  assert.deepEqual(conferir(formulario({ rbt12: "" })).erros, { rbt12: "Preencha este campo." });
});

test("pede a folha só no Fator R e a RBT12 da exportação só com exportação", () => {
  const receitas = [{ ...novaReceita(1, "fator_r", "1"), opcoes: ["exportacao"] }];
  assert.deepEqual(conferir(formulario({ receitas })).erros, {
    rbt12_exportacao: "Preencha este campo.",
    folha12: "Preencha este campo.",
  });
});

test("no 1º mês de atividade, não pede a receita anterior e manda o início", () => {
  const { parametros, erros } = conferir(formulario({ inicio: "2026-03", rbt12: "" }));
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, {
    periodo: "2026-03",
    inicio: "2026-03",
    atividades: "servicos_3:40000.00",
  });
});

test("a partir de 2027, pede a receita do mês anterior e manda a opção do IBS e da CBS", () => {
  const valores = formulario({ periodo: "2027-03", ibs_cbs_fora: true });
  assert.deepEqual(conferir(valores).erros, { receita_mes_anterior: "Preencha este campo." });
  const { parametros } = conferir({ ...valores, receita_mes_anterior: "45.000" });
  assert.deepEqual([parametros.receita_mes_anterior, parametros.ibs_cbs_fora], ["45000.00", "1"]);
  // Em 2026 a opção não existe, mesmo marcada.
  assert.equal(conferir(formulario({ ibs_cbs_fora: true })).parametros.ibs_cbs_fora, undefined);
});

test("manda os campos do sublimite só quando preenchidos", () => {
  const base = formulario({ periodo: "2026-10", rbt12: "3.900.000" });
  assert.equal(conferir(base).parametros.receita_ano, undefined);
  const { parametros, erros } = conferir({ ...base, receita_ano: "3.300.000" });
  assert.deepEqual([erros, parametros.receita_ano], [{}, "3300000.00"]);
  assert.deepEqual(conferir({ ...base, receita_ano_anterior: "abc" }).erros, {
    receita_ano_anterior: "Use só números, como 500.000,00.",
  });
  // Em janeiro a receita do ano não vai, mesmo preenchida.
  assert.equal(
    conferir({ ...base, periodo: "2026-01", receita_ano: "1" }).parametros.receita_ano,
    undefined,
  );
});

test("no mês a mês, manda um parâmetro por mês com a exportação e a folha", () => {
  const receitas = [{ ...novaReceita(1, "fator_r", "1"), opcoes: ["exportacao"] }];
  const meses = { "2026-01": { receita: "10.000", exportacao: "", folha: "3.000" } };
  const valores = formulario({
    modo: "meses",
    periodo: "2026-03",
    inicio: "2026-01",
    receitas,
    meses,
  });
  const { parametros, erros } = conferir(valores);
  assert.deepEqual(erros, { "meses.2026-02.receita": "Preencha este campo." });
  assert.equal(parametros["mes_2026-01"], "10000.00:0:3000.00");
  assert.equal(parametros.rbt12, undefined);
});

test("no mês a mês, aponta o valor em formato errado", () => {
  const meses = { "2026-02": { receita: "abc", folha: "x" } };
  const valores = formulario({ modo: "meses", inicio: "2026-02", meses });
  // A folha não aparece sem Fator R: não confere.
  assert.deepEqual(conferir(valores).erros, {
    "meses.2026-02.receita": "Use só números, como 500.000,00.",
  });
});

test("manda só os dados de fora do DAS preenchidos, no formato da API", () => {
  const fora = {
    ...FORA_VAZIO,
    aliquota_iss: "3,5",
    creditos_icms: "1.000",
    rat: "2",
    fap: "1,25",
  };
  const { parametros, erros } = conferir(formulario({ fora }));
  assert.deepEqual(erros, {});
  assert.deepEqual(
    [
      parametros.aliquota_iss,
      parametros.creditos_icms,
      parametros.rat,
      parametros.fap,
      parametros.pro_labore,
    ],
    ["3.5", "1000.00", "2", "1.25", undefined],
  );
});

test("aponta o erro nos dados de fora do DAS", () => {
  const fora = { ...FORA_VAZIO, aliquota_icms: "abc", pro_labore: "-1", rat: "4", fap: "2,123456" };
  assert.deepEqual(conferir(formulario({ fora })).erros, {
    "fora.aliquota_icms": "Use só números, como 3,5 (para 3,5%).",
    "fora.pro_labore": "Use só números, como 500.000,00.",
    "fora.rat": "Escolha 1%, 2% ou 3%.",
    "fora.fap": "Use um número como 1,0000.",
  });
});

test("resume o que as receitas pedem nos outros campos", () => {
  const receitas = [
    { ...novaReceita(1, "fator_r", "1"), opcoes: ["exportacao"] },
    novaReceita(2, "servicos_4", "1"),
  ];
  assert.deepEqual(resumoDasReceitas(receitas), { exportacao: true, fatorR: true, anexoIV: true });
  assert.deepEqual(resumoDasReceitas(VAZIO.receitas), {
    exportacao: false,
    fatorR: false,
    anexoIV: false,
  });
});

test("lista os dados informados para a memória de cálculo", () => {
  const fora = {
    ...FORA_VAZIO,
    aliquota_iss: "3,5",
    folha_empregados: "8000",
    rat: "2",
    fap: "1,5",
  };
  const valores = formulario({
    periodo: "2027-03",
    receita_mes_anterior: "45.000",
    ibs_cbs_fora: true,
    fora,
  });
  assert.deepEqual(linhasDaMemoria(valores), [
    ["Mês de apuração", "março de 2027"],
    ["Início das atividades", "há 13 meses ou mais"],
    ["IBS e CBS", "fora do DAS (regime regular)"],
    ["Receita bruta dos 12 meses antes do mês anterior (RBT12)", "R$ 500.000,00"],
    ["Receita bruta de fevereiro de 2027", "R$ 45.000,00"],
    ["Alíquota do ISS do município", "3,5%"],
    ["Salários dos empregados no mês", "R$ 8.000,00"],
    ["RAT", "2%"],
    ["FAP", "1,5"],
  ]);
});

test("na memória, o mês a mês vira uma linha só e o início aparece pelo nome", () => {
  const valores = formulario({ modo: "meses", inicio: "2026-01", receita_ano_anterior: "" });
  assert.deepEqual(linhasDaMemoria(valores), [
    ["Mês de apuração", "março de 2026"],
    ["Início das atividades", "janeiro de 2026"],
    ["Meses anteriores", "informados mês a mês (tabela abaixo)"],
  ]);
});
