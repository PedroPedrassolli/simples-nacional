import { Caixa, CampoLista, CampoReais } from "./campos.jsx";
import { ATIVIDADES_DO_MEI, iniciosDoMei } from "./mei.js";
import { regrasDoAno } from "./periodos.js";
import { nomeDoMes } from "./valores.js";

// Os campos do MEI: a atividade (diz se paga ICMS, ISS ou os dois), o transportador de cargas,
// o início no próprio ano (o limite fica proporcional), a receita do ano (para conferir o
// limite) e o salário mínimo quando o decreto do ano ainda não está na calculadora.
export default function CamposDoMei({ valores, erros, aoMudar }) {
  const mei = valores.mei;
  const { ano } = regrasDoAno(valores.periodo);
  const mudar = (mudanca, como) => aoMudar({ mei: { ...mei, ...mudanca } }, como);
  const atividade = ATIVIDADES_DO_MEI.find((item) => item.valor === mei.atividade);
  const inicios = [
    { valor: "", rotulo: valores.periodo ? `Antes de ${ano}` : "Antes do ano de apuração" },
    ...iniciosDoMei(valores.periodo).map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) })),
  ];

  return (
    <>
      <CampoLista
        nome="mei.atividade"
        rotulo="Atividade do MEI"
        dica={
          atividade
            ? atividade.dica
            : "Comércio e indústria pagam ICMS; serviços pagam ISS (LC 123/2006, art. 18-A, § 3º, V)."
        }
        vazio="Escolha a atividade"
        opcoes={ATIVIDADES_DO_MEI}
        valor={mei.atividade}
        erro={erros["mei.atividade"]}
        aoMudar={(valor) => mudar({ atividade: valor })}
      />
      <Caixa
        nome="mei.transportador"
        rotulo="Transportador autônomo de cargas"
        dica="INSS de 12% do salário mínimo e limite maior (Res. CGSN 140/2018, arts. 100, § 1º-A, e 101, I)."
        marcada={mei.transportador}
        aoMudar={(transportador) => mudar({ transportador })}
      />
      <CampoLista
        nome="mei.inicio"
        rotulo="Início das atividades"
        dica="No ano de início, o limite é proporcional aos meses de atividade."
        opcoes={inicios}
        valor={iniciosDoMei(valores.periodo).includes(mei.inicio) ? mei.inicio : ""}
        aoMudar={(inicio) => mudar({ inicio })}
      />
      <CampoReais
        nome="mei.receita_ano"
        rotulo={`Receita bruta de ${valores.periodo ? ano : "todo o ano"}`}
        dica="Opcional: o que a empresa faturou (ou espera faturar) no ano, para conferir o limite do MEI."
        valor={mei.receita_ano}
        erro={erros["mei.receita_ano"]}
        aoMudar={(receita_ano, como) => mudar({ receita_ano }, como)}
      />
      {ano >= 2027 && (
        <CampoReais
          nome="mei.salario_minimo"
          rotulo={`Salário mínimo de ${ano}`}
          dica="O decreto sai em dezembro do ano anterior. Enquanto ele não estiver na calculadora, informe o valor; depois, vale o do decreto."
          valor={mei.salario_minimo}
          erro={erros["mei.salario_minimo"]}
          aoMudar={(salario_minimo, como) => mudar({ salario_minimo }, como)}
        />
      )}
    </>
  );
}
