import { CampoReais, Revelar } from "./campos.jsx";
import { mesesDoHistorico, mesAntes, regrasDoAno, textosDosCampos } from "./periodos.js";
import { mesCurto, nomeDoMes, paraApi, reais } from "./valores.js";

const DICA_DA_FOLHA =
  "Com encargos: salários, pró-labore, contribuição patronal ao INSS e FGTS. Aluguéis e " +
  "distribuição de lucros não entram (LC 123/2006, art. 18, §§ 24 e 26).";

// Os meses antes do mês de apuração: as somas (RBT12, folha) ou o mês a mês, e os campos
// opcionais do sublimite.
export default function Anteriores(props) {
  const { valores, aoMudar, sublimiteAberto, aoAlternarSublimite } = props;
  const textos = textosDosCampos(valores.periodo, valores.inicio);
  const meses = valores.modo === "meses";

  return (
    <>
      <div className="alternar" role="radiogroup" aria-label="Como informar os meses anteriores">
        {[
          ["totais", "Somas dos 12 meses"],
          ["meses", "Mês a mês"],
        ].map(([modo, rotulo]) => (
          <label key={modo} className={valores.modo === modo ? "escolhido" : undefined}>
            <input
              type="radio"
              name="modo"
              value={modo}
              checked={valores.modo === modo}
              onChange={() => aoMudar({ modo })}
            />
            {rotulo}
          </label>
        ))}
      </div>
      {meses ? <MesAMes {...props} /> : <Totais {...props} textos={textos} />}

      {(textos.receitaAno || textos.receitaAnoAnterior) && (
        <Revelar
          className="opcional"
          titulo="Sublimite e limite do ano"
          selo="opcional"
          dica="Para quem pode passar de R$ 3.600.000,00 de receita no ano"
          aberto={sublimiteAberto}
          aoAlternar={aoAlternarSublimite}
        >
          <p className="dica">
            Acima de R$&nbsp;3.600.000,00 no ano, o ICMS e o ISS (e o IBS, a partir de 2027) mudam
            de regra; acima de R$&nbsp;4.800.000,00, a empresa sai do Simples. Em branco, a conta
            considera que a empresa não passou desses valores; se faltar algum número, ela avisa.
          </p>
          {textos.receitaAno && !meses && (
            <CampoReais
              nome="receita_ano"
              rotulo={textos.receitaAno}
              valor={valores.receita_ano}
              erro={props.erros.receita_ano}
              aoMudar={(valor, como) => aoMudar({ receita_ano: valor }, como)}
            />
          )}
          {textos.receitaAnoAnterior && (
            <CampoReais
              nome="receita_ano_anterior"
              rotulo={textos.receitaAnoAnterior}
              valor={valores.receita_ano_anterior}
              erro={props.erros.receita_ano_anterior}
              aoMudar={(valor, como) => aoMudar({ receita_ano_anterior: valor }, como)}
            />
          )}
        </Revelar>
      )}
    </>
  );
}

function Totais({ valores, erros, aoMudar, resumo, textos }) {
  const { novas } = regrasDoAno(valores.periodo);
  const campo = (nome, rotulo, dica) => (
    <CampoReais
      nome={nome}
      rotulo={rotulo}
      dica={dica}
      valor={valores[nome]}
      erro={erros[nome]}
      aoMudar={(valor, como) => aoMudar({ [nome]: valor }, como)}
    />
  );

  return (
    <>
      {textos.receita
        ? campo("rbt12", textos.receita, textos.dicaReceita)
        : valores.periodo && (
            <p className="nota">
              {novas
                ? "No 1º e no 2º mês de atividade, a conta usa as alíquotas da 1ª faixa, sem RBT12 (e o Fator R é 28%)."
                : "No 1º mês de atividade, a receita dos 12 meses (RBT12) é a receita do mês × 12."}
            </p>
          )}
      {textos.receita &&
        resumo.exportacao &&
        campo(
          "rbt12_exportacao",
          "Receita de exportação nos mesmos meses",
          "A exportação tem RBT12 própria (Res. CGSN 140/2018, art. 23). Use 0 se não houve.",
        )}
      {resumo.fatorR && textos.folha && campo("folha12", textos.folha, DICA_DA_FOLHA)}
      {textos.mesAnterior &&
        campo(
          "receita_mes_anterior",
          textos.mesAnterior,
          "A partir de 2027 a RBT12 não inclui o mês anterior: ele conta só para a receita do ano (sublimite e limite).",
        )}
    </>
  );
}

// Uma linha por mês, com a receita (e a exportação e a folha, quando fazem diferença). A
// soma aparece embaixo enquanto a pessoa digita.
function MesAMes({ valores, erros, aoMudar, resumo }) {
  if (!valores.periodo) return <p className="nota">Escolha o mês de apuração para ver os meses.</p>;
  const meses = mesesDoHistorico(valores.periodo, valores.inicio);
  if (meses.length === 0) {
    return <p className="nota">No 1º mês de atividade não há meses anteriores para informar.</p>;
  }

  const { novas } = regrasDoAno(valores.periodo);
  const colunas = [["receita", "Receita"]];
  if (resumo.exportacao) colunas.push(["exportacao", "Exportação"]);
  if (resumo.fatorR) colunas.push(["folha", "Folha"]);
  const mesAnterior = mesAntes(valores.periodo, 1);
  const naRbt12 = (mes) => !novas || mes !== mesAnterior;
  const somar = (filtro, campo = "receita") =>
    meses
      .filter(filtro)
      .reduce((total, mes) => total + Number(paraApi(valores.meses[mes]?.[campo] ?? "") ?? 0), 0);
  const ano = valores.periodo.slice(0, 4);

  function mudar(mes, campo, valor, como) {
    aoMudar(
      { meses: { ...valores.meses, [mes]: { ...valores.meses[mes], [campo]: valor } } },
      como,
    );
  }

  return (
    <div className={`meses colunas-${colunas.length}`}>
      <p className="dica">
        Informe cada mês (0 se não houve receita).
        {resumo.fatorR && " A folha é a do Fator R, com encargos."}
        {novas && " A partir de 2027, o mês anterior não entra na RBT12, só na receita do ano."}
      </p>
      <div className="meses-cabeca" aria-hidden="true">
        <span>Mês</span>
        {colunas.map(([campo, rotulo]) => (
          <span key={campo}>{rotulo}</span>
        ))}
      </div>
      {meses.map((mes) => (
        <div key={mes} className="mes" role="group" aria-label={nomeDoMes(mes)}>
          <span className="mes-nome">
            {mesCurto(mes)}
            {!naRbt12(mes) && <span className="mes-marca"> fora da RBT12</span>}
          </span>
          {colunas.map(([campo, rotulo]) => (
            <CampoReais
              key={campo}
              nome={`meses.${mes}.${campo}`}
              rotulo={`${rotulo} de ${nomeDoMes(mes)}`}
              rotuloOculto
              valor={valores.meses[mes]?.[campo] ?? ""}
              erro={erros[`meses.${mes}.${campo}`]}
              aoMudar={(valor, como) => mudar(mes, campo, valor, como)}
            />
          ))}
        </div>
      ))}
      <dl className="meses-somas" aria-live="polite">
        <div>
          <dt>{valores.inicio ? "Receita desde o início (soma)" : "RBT12 (soma)"}</dt>
          <dd>{reais(Math.round(somar(naRbt12) * 100))}</dd>
        </div>
        <div>
          <dt>Receita de {ano} até o mês anterior</dt>
          <dd>{reais(Math.round(somar((mes) => mes.startsWith(ano)) * 100))}</dd>
        </div>
        {resumo.fatorR && (
          <div>
            <dt>Folha (soma)</dt>
            <dd>{reais(Math.round(somar(naRbt12, "folha") * 100))}</dd>
          </div>
        )}
      </dl>
    </div>
  );
}
