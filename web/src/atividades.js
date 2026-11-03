// Os tipos de receita do formulário (a segregação do PGDAS-D) e as situações de cada um.
// Os códigos são os da API (lib/simples_nacional/atividades.rb); os textos resumem onde a lei
// põe cada atividade (LC 123/2006, art. 18, §§ 4º, 4º-A e 5º-B a 5º-M; Res. CGSN 140/2018,
// art. 25), conferidos no Planalto e no site da Receita em 02/11/2026. São exemplos, não a lista
// completa: quem decide o anexo é a atividade descrita na lei.
export const TIPOS = [
  {
    valor: "revenda",
    rotulo: "Revenda de mercadorias (Anexo I)",
    dica: "Comércio: venda de mercadorias compradas de terceiros (art. 18, § 4º, I).",
    opcoes: ["st_icms", "monofasico", "exportacao"],
  },
  {
    valor: "industria",
    rotulo: "Venda de produtos fabricados pela empresa",
    dica:
      "Indústria: Anexo II em 2026. A partir de 2027, Anexo I, menos o produto com IPI mantido " +
      "(Zona Franca de Manaus), que fica no Anexo II (Res. CGSN 140/2018, art. 25, § 1º, I e II).",
    opcoes: ["st_icms", "monofasico", "exportacao", "ipi_mantido"],
  },
  {
    valor: "servicos_3",
    rotulo: "Serviços do Anexo III",
    dica:
      "Escolas e cursos, agência de viagem, autoescola, instalação, reparos e manutenção, " +
      "escritório de contabilidade e os serviços sem outro anexo na lei (art. 18, §§ 5º-B e 5º-F).",
    opcoes: ["iss_retido", "exportacao"],
  },
  {
    valor: "fator_r",
    rotulo: "Serviços do Anexo III ou V, pelo Fator R",
    dica:
      "Medicina, odontologia, psicologia, fisioterapia, arquitetura, engenharia, consultoria, " +
      "auditoria, publicidade e desenvolvimento de programas: Anexo III se a folha de salários for " +
      "28% ou mais da receita; abaixo disso, Anexo V (art. 18, §§ 5º-I, 5º-J e 5º-M).",
    opcoes: ["iss_retido", "exportacao"],
  },
  {
    valor: "servicos_4",
    rotulo: "Serviços do Anexo IV (obras, limpeza, vigilância, advocacia)",
    dica:
      "Construção de imóveis e obras de engenharia, vigilância, limpeza ou conservação e " +
      "serviços advocatícios (art. 18, § 5º-C). A contribuição patronal (CPP) é paga fora do DAS.",
    opcoes: ["iss_retido", "exportacao"],
  },
  {
    valor: "servicos_5",
    rotulo: "Serviços do Anexo V",
    dica:
      "Para quem já sabe que a folha de salários fica abaixo de 28% da receita. Se não souber, " +
      "escolha a opção do Fator R e informe a folha.",
    opcoes: ["iss_retido", "exportacao"],
  },
  {
    valor: "locacao",
    rotulo: "Locação de bens móveis",
    dica: "Aluguel de máquinas, equipamentos e veículos: Anexo III sem o ISS (art. 18, § 4º, V).",
    opcoes: [],
  },
  {
    valor: "transporte",
    rotulo: "Transporte intermunicipal ou interestadual, ou comunicação",
    dica:
      "Anexo III sem o ISS e com o ICMS do Anexo I (Res. CGSN 140/2018, art. 25, § 1º, IX). " +
      "O transporte dentro do município é serviço do Anexo III.",
    opcoes: ["st_icms"],
  },
];

// Nome e explicação de cada situação. O monofásico muda de nome em 2027 (CBS e IBS).
export function opcao(codigo, ano) {
  const novas = ano >= 2027;
  return {
    st_icms: {
      rotulo: "ICMS já pago por substituição tributária ou antecipação",
      dica: "Tira o ICMS da conta (art. 18, § 4º-A, I).",
    },
    monofasico: novas
      ? {
          rotulo: "IBS e CBS com tributação concentrada (monofásica)",
          dica: "Tira o IBS e a CBS da conta (Res. CGSN 140/2018, art. 25, § 6º).",
        }
      : {
          rotulo: "PIS/Pasep e Cofins monofásicos",
          dica: "Tira o PIS/Pasep e a Cofins da conta (art. 18, § 4º-A, I).",
        },
    iss_retido: {
      rotulo: "ISS retido pelo tomador",
      dica: "Tira o ISS da conta (art. 18, § 4º-A, II).",
    },
    exportacao: {
      rotulo: "Exportação",
      dica: "Usa a RBT12 da exportação e tira os tributos que a exportação não paga (art. 18, § 14).",
    },
    ipi_mantido: {
      rotulo: "Produto com IPI mantido (Zona Franca de Manaus)",
      dica: "A partir de 2027, fica no Anexo II.",
    },
  }[codigo];
}

// As situações que valem para o tipo no ano (o IPI mantido só existe a partir de 2027).
export function opcoesDoTipo(tipo, ano) {
  const encontrado = TIPOS.find((item) => item.valor === tipo);
  if (!encontrado) return [];
  return encontrado.opcoes.filter((codigo) => codigo !== "ipi_mantido" || ano >= 2027);
}

export function dicaDoTipo(tipo) {
  const encontrado = TIPOS.find((item) => item.valor === tipo);
  return encontrado
    ? encontrado.dica
    : "Depende da atividade (LC 123/2006, art. 18). Com mais de uma atividade, informe cada receita separada.";
}
