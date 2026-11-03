// O estado do formulário e a conferência antes de chamar a API (funções puras, testadas com
// node --test). A regra fica na API: aqui só se confere o formato e se monta a URL.
import { opcoesDoTipo } from "./atividades.js";
import { mesesDoHistorico, regrasDoAno, textosDosCampos } from "./periodos.js";
import { formatarReais, nomeDoMes, paraApi, paraPercentual } from "./valores.js";

export const FORA_VAZIO = {
  aliquota_iss: "",
  aliquota_icms: "",
  creditos_icms: "",
  aliquota_ibs: "",
  creditos_ibs: "",
  aliquota_cbs: "",
  creditos_cbs: "",
  folha_empregados: "",
  pro_labore: "",
  rat: "",
  fap: "",
};

// Os nomes dos campos de fora do DAS, no formulário e na memória de cálculo.
export const ROTULOS_DE_FORA = {
  aliquota_iss: "Alíquota do ISS do município",
  aliquota_icms: "Alíquota do ICMS",
  creditos_icms: "Créditos de ICMS do mês",
  aliquota_ibs: "Alíquota do IBS",
  creditos_ibs: "Créditos de IBS do mês",
  aliquota_cbs: "Alíquota da CBS",
  creditos_cbs: "Créditos de CBS do mês",
  folha_empregados: "Salários dos empregados no mês",
  pro_labore: "Pró-labore e autônomos no mês",
  rat: "RAT",
  fap: "FAP",
};

// id: só para o React saber qual linha é qual quando uma é removida.
export function novaReceita(id, tipo = "", valor = "") {
  return { id, tipo, valor, opcoes: [] };
}

export const VAZIO = {
  periodo: "",
  inicio: "",
  receitas: [novaReceita(1)],
  // "totais" (RBT12 e folha somadas) ou "meses" (mês a mês).
  modo: "totais",
  rbt12: "",
  rbt12_exportacao: "",
  folha12: "",
  receita_mes_anterior: "",
  receita_ano: "",
  receita_ano_anterior: "",
  // { "2025-03": { receita: "", exportacao: "", folha: "" } }
  meses: {},
  ibs_cbs_fora: false,
  fora: FORA_VAZIO,
};

// Números fictícios (uma prestadora de serviços do Anexo III), para ver a calculadora
// funcionando antes de juntar os números da empresa.
export const EXEMPLO = {
  ...VAZIO,
  periodo: "2026-03",
  receitas: [novaReceita(1, "servicos_3", "40.000,00")],
  rbt12: "500.000,00",
};

// O que muda os campos: há exportação, Fator R ou Anexo IV entre as receitas?
export function resumoDasReceitas(receitas) {
  return {
    exportacao: receitas.some((receita) => receita.opcoes.includes("exportacao")),
    fatorR: receitas.some((receita) => receita.tipo === "fator_r"),
    anexoIV: receitas.some((receita) => receita.tipo === "servicos_4"),
  };
}

const PREENCHA = "Preencha este campo.";
const SO_NUMEROS = "Use só números, como 500.000,00.";

// Confere o formulário. Devolve os parâmetros da URL e os erros por campo (vazio quando
// está tudo certo). Os nomes dos erros seguem o formulário: "rbt12", "receitas.0.valor",
// "meses.2025-03.receita", "fora.aliquota_iss".
export function conferir(valores) {
  const erros = {};
  const parametros = {};
  if (valores.periodo) parametros.periodo = valores.periodo;
  else erros.periodo = "Escolha o mês de apuração.";
  if (valores.inicio) parametros.inicio = valores.inicio;

  const ano = regrasDoAno(valores.periodo).ano;
  parametros.atividades = receitas(valores.receitas, ano, erros);
  const resumo = resumoDasReceitas(valores.receitas);
  if (valores.modo === "meses") Object.assign(parametros, meses(valores, resumo, erros));
  else Object.assign(parametros, totais(valores, resumo, erros));
  opcional(valores, "receita_ano_anterior", parametros, erros);
  if (valores.ibs_cbs_fora && regrasDoAno(valores.periodo).novas) parametros.ibs_cbs_fora = "1";
  Object.assign(parametros, foraDoDas(valores.fora, erros));
  return { parametros, erros };
}

// "revenda:30000.00:st_icms+monofasico;servicos_3:10000.00"
function receitas(lista, ano, erros) {
  return lista
    .map((receita, indice) => {
      if (!receita.tipo) erros[`receitas.${indice}.tipo`] = "Escolha o tipo da receita.";
      const valor = paraApi(receita.valor);
      if (valor === null || Number(valor) <= 0) {
        erros[`receitas.${indice}.valor`] =
          String(receita.valor).trim() === ""
            ? PREENCHA
            : "Use um valor maior que zero, como 40.000,00.";
      }
      const opcoes = receita.opcoes.filter((codigo) =>
        opcoesDoTipo(receita.tipo, ano).includes(codigo),
      );
      return [receita.tipo, valor, opcoes.join("+")].filter(Boolean).join(":");
    })
    .join(";");
}

// Os totais à mão: só os campos que aparecem na tela.
function totais(valores, resumo, erros) {
  const textos = textosDosCampos(valores.periodo, valores.inicio);
  const parametros = {};
  if (textos.receita) obrigatorio(valores, "rbt12", parametros, erros);
  if (textos.receita && resumo.exportacao)
    obrigatorio(valores, "rbt12_exportacao", parametros, erros);
  if (resumo.fatorR && textos.folha) obrigatorio(valores, "folha12", parametros, erros);
  if (textos.mesAnterior) obrigatorio(valores, "receita_mes_anterior", parametros, erros);
  if (textos.receitaAno) opcional(valores, "receita_ano", parametros, erros);
  return parametros;
}

// O mês a mês: um parâmetro por mês, "receita:exportação:folha" (exportação e folha em
// branco valem zero).
function meses(valores, resumo, erros) {
  const parametros = {};
  for (const mes of mesesDoHistorico(valores.periodo, valores.inicio)) {
    const linha = valores.meses[mes] ?? {};
    const receita = paraApi(linha.receita ?? "");
    if (receita === null) {
      erros[`meses.${mes}.receita`] =
        String(linha.receita ?? "").trim() === "" ? PREENCHA : SO_NUMEROS;
    }
    const partes = [receita];
    for (const [campo, usa] of [
      ["exportacao", resumo.exportacao],
      ["folha", resumo.fatorR],
    ]) {
      const texto = usa ? String(linha[campo] ?? "").trim() : "";
      const valor = texto === "" ? "0" : paraApi(texto);
      if (valor === null) erros[`meses.${mes}.${campo}`] = SO_NUMEROS;
      partes.push(valor);
    }
    parametros[`mes_${mes}`] = partes.join(":");
  }
  return parametros;
}

function obrigatorio(valores, nome, parametros, erros) {
  const valor = paraApi(valores[nome]);
  if (valor !== null) parametros[nome] = valor;
  else erros[nome] = String(valores[nome]).trim() === "" ? PREENCHA : SO_NUMEROS;
}

// Em branco, não vai para a API.
function opcional(valores, nome, parametros, erros) {
  if (String(valores[nome] ?? "").trim() === "") return;
  obrigatorio(valores, nome, parametros, erros);
}

// Tudo opcional: só vai o que foi preenchido.
function foraDoDas(fora, erros) {
  const parametros = {};
  for (const [nome, texto] of Object.entries(fora)) {
    if (String(texto).trim() === "") continue;
    const valor = converterFora(nome, texto);
    if (valor === null) erros[`fora.${nome}`] = mensagemFora(nome);
    else parametros[nome] = valor;
  }
  return parametros;
}

function converterFora(nome, texto) {
  if (nome.startsWith("aliquota_")) return paraPercentual(texto);
  if (nome === "rat") return /^[123]$/.test(texto) ? texto : null;
  if (nome === "fap") {
    const fap = String(texto).trim().replace(",", ".");
    return /^\d(\.\d{1,4})?$/.test(fap) ? fap : null;
  }
  return paraApi(texto);
}

function mensagemFora(nome) {
  if (nome.startsWith("aliquota_")) return "Use só números, como 3,5 (para 3,5%).";
  if (nome === "rat") return "Escolha 1%, 2% ou 3%.";
  if (nome === "fap") return "Use um número como 1,0000.";
  return SO_NUMEROS;
}

// Os dados que a pessoa informou, para a memória de cálculo: [[rótulo, valor], ...]. As
// receitas do mês e o mês a mês ficam de fora (a memória mostra os dois em tabelas).
export function linhasDaMemoria(valores) {
  const { novas } = regrasDoAno(valores.periodo);
  const textos = textosDosCampos(valores.periodo, valores.inicio);
  const resumo = resumoDasReceitas(valores.receitas);
  const linhas = [["Mês de apuração", nomeDoMes(valores.periodo)]];
  linhas.push([
    "Início das atividades",
    valores.inicio ? nomeDoMes(valores.inicio) : `há ${novas ? 13 : 12} meses ou mais`,
  ]);
  if (novas && valores.ibs_cbs_fora) linhas.push(["IBS e CBS", "fora do DAS (regime regular)"]);

  // Só os campos que aparecem na tela e foram preenchidos.
  const se = (mostra, rotulo, nome) => {
    const texto = String(valores[nome] ?? "").trim();
    if (mostra && texto !== "") linhas.push([rotulo, `R$ ${formatarReais(texto)}`]);
  };
  if (valores.modo === "meses") {
    linhas.push(["Meses anteriores", "informados mês a mês (tabela abaixo)"]);
  } else {
    se(textos.receita, textos.receita, "rbt12");
    se(
      textos.receita && resumo.exportacao,
      "Receita de exportação nos mesmos meses",
      "rbt12_exportacao",
    );
    se(resumo.fatorR && textos.folha, textos.folha, "folha12");
    se(textos.mesAnterior, textos.mesAnterior, "receita_mes_anterior");
    se(textos.receitaAno, textos.receitaAno, "receita_ano");
  }
  se(textos.receitaAnoAnterior, textos.receitaAnoAnterior, "receita_ano_anterior");

  for (const [nome, texto] of Object.entries(valores.fora)) {
    if (String(texto).trim() === "") continue;
    linhas.push([ROTULOS_DE_FORA[nome], valorDeFora(nome, String(texto).trim())]);
  }
  return linhas;
}

// "3,5" → "3,5%" (alíquotas e RAT), "1,5" → "1,5" (FAP), "8000" → "R$ 8.000,00" (o resto).
function valorDeFora(nome, texto) {
  if (nome.startsWith("aliquota_") || nome === "rat") return `${texto}%`;
  if (nome === "fap") return texto;
  return `R$ ${formatarReais(texto)}`;
}
