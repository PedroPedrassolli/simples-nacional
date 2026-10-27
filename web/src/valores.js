// Funções puras do formulário (sem React), testadas com node --test.

// Converte o valor digitado para o formato que a API espera ("500000.00").
// Aceita "R$ 500.000,00", "500000,5", "500.000" e "1234.56". Devolve null quando o
// texto não é um valor em reais.
export function paraApi(texto) {
  let limpo = String(texto).replace(/R\$/g, "").replace(/\s/g, "");

  if (limpo.includes(",")) {
    // Jeito brasileiro: ponto separa os milhares e vírgula separa os centavos.
    if (!/^(\d{1,3}(\.\d{3})+|\d+),\d{1,2}$/.test(limpo)) return null;
    limpo = limpo.replace(/\./g, "").replace(",", ".");
  } else if (/^\d{1,3}(\.\d{3})+$/.test(limpo)) {
    // "500.000": pontos só como separador de milhar.
    limpo = limpo.replace(/\./g, "");
  }

  if (!/^\d+(\.\d{1,2})?$/.test(limpo)) return null;

  const [reais, centavos = ""] = limpo.split(".");
  return `${reais.replace(/^0+(?=\d)/, "")}.${centavos.padEnd(2, "0")}`;
}

// Confere o formulário antes de chamar a API. Devolve os parâmetros da URL e os erros
// por campo (vazio quando está tudo certo). A folha só é pedida no Fator R.
export function conferir({ rbt12, receita_mes, anexo, folha12 }) {
  const erros = {};
  const parametros = { anexo };
  const campos = { rbt12, receita_mes, ...(anexo === "fator_r" ? { folha12 } : {}) };

  for (const [nome, texto] of Object.entries(campos)) {
    const valor = paraApi(texto);
    if (valor !== null) {
      parametros[nome] = valor;
    } else {
      erros[nome] =
        String(texto).trim() === "" ? "Preencha este campo." : "Use só números, como 500.000,00.";
    }
  }
  if (!anexo) erros.anexo = "Escolha o anexo.";

  return { parametros, erros };
}

// "2018-01-01" → "01/01/2018".
export function dataBrasileira(iso) {
  const [ano, mes, dia] = iso.split("-");
  return `${dia}/${mes}/${ano}`;
}

// Frase sobre o Simples na consulta de CNPJ, a partir do que a API devolveu.
export function textoSimples({ optante, desde, excluida_em }) {
  if (optante)
    return desde
      ? `Optante pelo Simples Nacional desde ${desde}.`
      : "Optante pelo Simples Nacional.";
  const exclusao = excluida_em ? ` (exclusão em ${excluida_em})` : "";
  return `Não consta como optante pelo Simples Nacional${exclusao}.`;
}
