// As opções do campo "Anexo da atividade". Os rótulos resumem os títulos dos anexos na
// LC 123/2006 (o título inteiro, de data/anexos/, aparece no resultado). As dicas resumem
// onde a lei põe cada atividade (art. 18, §§ 4º e 5º-B a 5º-M), conferidas no texto
// compilado do Planalto em 30/10/2026: https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm
// São exemplos, não a lista completa: quem decide o anexo é a atividade descrita na lei.
export const ANEXOS = [
  {
    valor: "1",
    rotulo: "Anexo I – Comércio",
    dica: "Revenda de mercadorias (art. 18, § 4º, I).",
  },
  {
    valor: "2",
    rotulo: "Anexo II – Indústria",
    dica: "Venda de mercadorias industrializadas pela própria empresa (art. 18, § 4º, II).",
  },
  {
    valor: "3",
    rotulo: "Anexo III – Serviços e locação de bens móveis",
    dica:
      "Serviços como escolas e cursos, agência de viagem, autoescola, instalação, reparos e " +
      "manutenção e escritório de contabilidade, e os serviços sem outro anexo na lei (art. 18, " +
      "§§ 5º-B e 5º-F). Medicina, odontologia, psicologia, fisioterapia, arquitetura e " +
      "desenvolvimento de programas dependem do Fator R: escolha a última opção.",
  },
  {
    valor: "4",
    rotulo: "Anexo IV – Serviços do § 5º-C (obras, limpeza, advocacia)",
    dica:
      "Construção de imóveis e obras de engenharia, vigilância, limpeza ou conservação e " +
      "serviços advocatícios (art. 18, § 5º-C). A contribuição patronal (CPP) é paga fora do DAS.",
  },
  {
    valor: "5",
    rotulo: "Anexo V – Serviços do § 5º-I",
    dica:
      "Para quem já sabe que a folha de salários fica abaixo de 28% da receita. Se não souber, " +
      "escolha a última opção e informe a folha.",
  },
  {
    valor: "fator_r",
    rotulo: "Anexo III ou V, pelo Fator R",
    dica:
      "Serviços como medicina, odontologia, psicologia, fisioterapia, arquitetura, engenharia, " +
      "consultoria, auditoria, publicidade e desenvolvimento de programas: Anexo III se a folha " +
      "de salários for 28% ou mais da receita; abaixo disso, Anexo V (art. 18, §§ 5º-I, 5º-J e 5º-M).",
  },
];

// A dica do anexo escolhido, ou a geral quando nenhum foi escolhido ainda.
export function dicaDoAnexo(valor) {
  const anexo = ANEXOS.find((opcao) => opcao.valor === valor);
  return anexo ? anexo.dica : "Depende da atividade da empresa (LC 123/2006, art. 18).";
}
