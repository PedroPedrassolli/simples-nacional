import { dataBrasileira } from "./valores.js";

const ROMANOS = { 1: "I", 2: "II", 3: "III", 4: "IV", 5: "V" };

// Mostra o que a API devolveu: o DAS, o resumo e a conta passo a passo (que abre e fecha).
export default function Resultado({ resultado, refTitulo }) {
  const { tabela } = resultado;

  return (
    <section className="resultado" aria-labelledby="resultado-titulo">
      <h2 id="resultado-titulo" ref={refTitulo} tabIndex={-1}>
        DAS estimado: {resultado.das}
      </h2>

      <dl className="resumo">
        <div>
          <dt>Mês de apuração</dt>
          <dd>{resultado.periodo_nome}</dd>
        </div>
        <div>
          <dt>RBT12</dt>
          <dd>{resultado.rbt12}</dd>
        </div>
        <div>
          <dt>Alíquota efetiva</dt>
          <dd>{resultado.aliquota_efetiva}</dd>
        </div>
        {resultado.fator_r && (
          <div>
            <dt>Fator R</dt>
            <dd>{resultado.fator_r}</dd>
          </div>
        )}
        <div>
          <dt>Anexo</dt>
          <dd>
            {ROMANOS[resultado.anexo]}: {resultado.anexo_nome}
          </dd>
        </div>
        <div>
          <dt>Faixa</dt>
          <dd>
            {resultado.faixa}ª, com alíquota nominal de {resultado.aliquota_nominal}
          </dd>
        </div>
      </dl>

      <Tributos tributos={resultado.tributos} />

      <details className="passos">
        <summary>Ver a conta passo a passo</summary>
        <ol>
          {resultado.passos.map((passo) => (
            <li key={passo.titulo}>
              <h3>{passo.titulo}</h3>
              <p>{passo.texto}</p>
              <p className="fonte">{passo.fonte}</p>
            </li>
          ))}
        </ol>
      </details>

      <p className="fonte">
        Tabela na redação da {tabela.redacao}, em vigor desde {dataBrasileira(tabela.vigencia)}.{" "}
        <a href={tabela.fonte}>Texto da LC 123/2006 no Planalto</a>.
      </p>
    </section>
  );
}

// A divisão do DAS: quanto vai para cada tributo. O percentual é sobre a receita do mês.
function Tributos({ tributos }) {
  return (
    <table className="tributos">
      <caption>Divisão do DAS entre os tributos</caption>
      <thead>
        <tr>
          <th scope="col">Tributo</th>
          <th scope="col">% da receita</th>
          <th scope="col">Valor</th>
        </tr>
      </thead>
      <tbody>
        {tributos.map((tributo) => (
          <tr key={tributo.nome}>
            <th scope="row">{tributo.nome}</th>
            <td>{tributo.percentual}</td>
            <td>{tributo.valor}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
