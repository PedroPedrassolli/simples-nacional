// Os tipos de receita do formulário (a segregação do PGDAS-D) e as situações de cada um.
// Os códigos são os da API (lib/simples_nacional/atividades.rb); os textos resumem onde a lei
// põe cada atividade (LC 123/2006, art. 18, §§ 4º, 4º-A, 5º-B a 5º-M, 20 e 20-A; Res. CGSN
// 140/2018, arts. 25 e 35), conferidos no Planalto e no site da Receita em 03/11/2026. São
// exemplos, não a lista completa: quem decide o anexo é a atividade descrita na lei.
//
// Os nomes ficam curtos para caber na lista do celular; a dica embaixo do campo explica.

// Isenção ou redução dada pelo estado (ICMS) ou pelo município (ISS) às ME e EPP.
const DO_ESTADO = ["isencao_icms", "reducao_icms"];
const DO_MUNICIPIO = ["isencao_iss", "reducao_iss"];
const MERCADORIAS = ["st_icms", "monofasico", "exportacao", ...DO_ESTADO];
const SERVICOS = ["iss_retido", "exportacao", ...DO_MUNICIPIO];

// As reduções pedem o percentual (as outras situações são só marcar).
export const REDUCOES = { reducao_icms: "ICMS", reducao_iss: "ISS" };

// Isenção e redução do mesmo imposto não andam juntas: marcar uma desmarca a outra.
export const EXCLUSIVAS = {
  isencao_icms: "reducao_icms",
  reducao_icms: "isencao_icms",
  isencao_iss: "reducao_iss",
  reducao_iss: "isencao_iss",
};

export const TIPOS = [
  {
    valor: "revenda",
    rotulo: "Revenda de mercadorias",
    dica: "Anexo I. Comércio: venda de mercadorias compradas de terceiros (art. 18, § 4º, I).",
    opcoes: MERCADORIAS,
  },
  {
    valor: "industria",
    rotulo: "Produtos fabricados pela empresa",
    dica:
      "Indústria: Anexo II em 2026. A partir de 2027, Anexo I, menos o produto com IPI mantido " +
      "(Zona Franca de Manaus), que fica no Anexo II (Res. CGSN 140/2018, art. 25, § 1º, I e II).",
    opcoes: [...MERCADORIAS, "ipi_mantido"],
  },
  {
    valor: "industria_iss",
    rotulo: "Indústria com IPI e ISS",
    dica:
      "Industrialização sujeita ao IPI e ao ISS ao mesmo tempo: Anexo II sem o ICMS e com o ISS do " +
      "Anexo III (art. 18, § 4º, VI; Res. CGSN 140/2018, art. 25, § 1º, VII).",
    opcoes: SERVICOS,
  },
  {
    valor: "servicos_3",
    rotulo: "Serviços do Anexo III",
    dica:
      "Escolas e cursos, agência de viagem, autoescola, instalação, reparos e manutenção, " +
      "escritório de contabilidade e os serviços sem outro anexo na lei (art. 18, §§ 5º-B e 5º-F).",
    opcoes: SERVICOS,
  },
  {
    valor: "fator_r",
    rotulo: "Serviços com Fator R",
    dica:
      "Anexo III ou V. Medicina, odontologia, psicologia, fisioterapia, arquitetura, engenharia, " +
      "consultoria, auditoria, publicidade e desenvolvimento de programas: Anexo III se a folha de " +
      "salários for 28% ou mais da receita; abaixo disso, Anexo V (art. 18, §§ 5º-I, 5º-J e 5º-M).",
    opcoes: SERVICOS,
  },
  {
    valor: "servicos_4",
    rotulo: "Serviços do Anexo IV",
    dica:
      "Construção de imóveis e obras de engenharia, vigilância, limpeza ou conservação e " +
      "serviços advocatícios (art. 18, § 5º-C). A contribuição patronal (CPP) é paga fora do DAS.",
    opcoes: SERVICOS,
  },
  {
    valor: "servicos_5",
    rotulo: "Serviços do Anexo V",
    dica:
      "Para quem já sabe que a folha de salários fica abaixo de 28% da receita. Se não souber, " +
      "escolha Serviços com Fator R e informe a folha.",
    opcoes: SERVICOS,
  },
  {
    valor: "locacao",
    rotulo: "Locação de bens móveis",
    dica: "Aluguel de máquinas, equipamentos e veículos: Anexo III sem o ISS (art. 18, § 4º, V).",
    opcoes: [],
  },
  {
    valor: "transporte",
    rotulo: "Transporte ou comunicação",
    dica:
      "Transporte intermunicipal ou interestadual e comunicação: Anexo III sem o ISS e com o ICMS " +
      "do Anexo I (Res. CGSN 140/2018, art. 25, § 1º, IX). O transporte dentro do município é " +
      "serviço do Anexo III.",
    opcoes: ["st_icms", ...DO_ESTADO],
  },
];

// Nome e explicação de cada situação. O monofásico muda de nome em 2027 (CBS e IBS).
export function opcao(codigo, ano) {
  const novas = ano >= 2027;
  const isencaoOuReducao = "LC 123/2006, art. 18, §§ 20 e 20-A; Res. CGSN 140/2018, art. 35";
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
    isencao_icms: {
      rotulo: "Isenção do ICMS dada pelo estado",
      dica: `Tira o ICMS da conta (${isencaoOuReducao}, I).`,
    },
    reducao_icms: {
      rotulo: "Redução do ICMS dada pelo estado",
      dica: `Diminui o percentual do ICMS na mesma proporção (${isencaoOuReducao}, II).`,
    },
    isencao_iss: {
      rotulo: "Isenção do ISS dada pelo município",
      dica: `Tira o ISS da conta (${isencaoOuReducao}, I).`,
    },
    reducao_iss: {
      rotulo: "Redução do ISS dada pelo município",
      dica: `Diminui o percentual do ISS na mesma proporção (${isencaoOuReducao}, II).`,
    },
  }[codigo];
}

// As situações que valem para o tipo no ano (o IPI mantido só existe a partir de 2027).
export function opcoesDoTipo(tipo, ano) {
  const encontrado = TIPOS.find((item) => item.valor === tipo);
  if (!encontrado) return [];
  return encontrado.opcoes.filter((codigo) => codigo !== "ipi_mantido" || ano >= 2027);
}

// Marca ou desmarca uma situação; marcar a isenção desmarca a redução do mesmo imposto (e o
// contrário).
export function marcarOpcao(opcoes, codigo, marcada) {
  const sem = opcoes.filter((item) => item !== codigo && (!marcada || item !== EXCLUSIVAS[codigo]));
  return marcada ? [...sem, codigo] : sem;
}

export function dicaDoTipo(tipo) {
  const encontrado = TIPOS.find((item) => item.valor === tipo);
  return encontrado
    ? encontrado.dica
    : "Depende da atividade (LC 123/2006, art. 18). Com mais de uma atividade, informe cada receita separada.";
}
