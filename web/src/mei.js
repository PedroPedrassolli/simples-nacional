// O formulário do MEI (funções puras, testadas com node --test). O DAS do MEI tem valor fixo
// por mês: a API (lib/simples_nacional/mei.rb) faz a conta; aqui só a conferência e a URL.
import { conferirMes, conferirPagamento, opcional } from "./formulario.js";
import { mesAntes } from "./periodos.js";
import { dataBrasileira, formatarReais, nomeDoMes } from "./valores.js";

// Os códigos são os da API (Mei::ATIVIDADES). O imposto local depende da atividade: ICMS para
// quem vende mercadoria, ISS para quem presta serviço (LC 123/2006, art. 18-A, § 3º, V).
export const ATIVIDADES_DO_MEI = [
  { valor: "comercio", rotulo: "Comércio", dica: "Paga o valor fixo de ICMS." },
  { valor: "industria", rotulo: "Indústria", dica: "Paga o valor fixo de ICMS." },
  { valor: "servicos", rotulo: "Serviços", dica: "Paga o valor fixo de ISS." },
  {
    valor: "comercio_servicos",
    rotulo: "Comércio e serviços",
    dica: "Paga os valores fixos de ICMS e de ISS.",
  },
];

// Os meses de início possíveis no ano de apuração, do mais novo ao mais antigo (janeiro é o
// último). Só o início no próprio ano muda alguma coisa: o limite fica proporcional.
export function iniciosDoMei(periodo) {
  if (!periodo) return [];
  const mes = Number(periodo.slice(5, 7));
  return Array.from({ length: mes }, (_, atras) => mesAntes(periodo, atras));
}

// Confere o formulário do MEI e monta os parâmetros (regime=mei).
export function conferirMei(valores) {
  const { erros, parametros } = conferirMes(valores);
  parametros.regime = "mei";
  const mei = valores.mei;
  if (mei.atividade) parametros.mei_atividade = mei.atividade;
  else erros["mei.atividade"] = "Escolha a atividade do MEI.";
  if (mei.transportador) parametros.transportador = "1";
  if (mei.inicio && iniciosDoMei(valores.periodo).includes(mei.inicio)) {
    parametros.inicio = mei.inicio;
  }
  opcional(mei, "receita_ano", parametros, erros, "mei.receita_ano");
  opcional(mei, "salario_minimo", parametros, erros, "mei.salario_minimo");
  conferirPagamento(valores, parametros, erros);
  return { parametros, erros };
}

// Os dados informados, para a memória de cálculo do MEI.
export function linhasDaMemoriaDoMei(valores) {
  const mei = valores.mei;
  const atividade = ATIVIDADES_DO_MEI.find((item) => item.valor === mei.atividade);
  const linhas = [
    ["Mês de apuração", nomeDoMes(valores.periodo)],
    ["Atividade", atividade ? atividade.rotulo : ""],
  ];
  if (mei.transportador) linhas.push(["Transportador autônomo de cargas", "sim"]);
  if (mei.inicio) linhas.push(["Início das atividades", nomeDoMes(mei.inicio)]);
  for (const [nome, rotulo] of [
    ["receita_ano", `Receita bruta de ${valores.periodo.slice(0, 4)}`],
    ["salario_minimo", "Salário mínimo informado"],
  ]) {
    const texto = String(mei[nome] ?? "").trim();
    if (texto !== "") linhas.push([rotulo, `R$ ${formatarReais(texto)}`]);
  }
  if (valores.pagamento) linhas.push(["Data do pagamento", dataBrasileira(valores.pagamento)]);
  return linhas;
}
