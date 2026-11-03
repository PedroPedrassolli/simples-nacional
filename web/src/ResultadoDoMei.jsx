import { Atraso } from "./Resultado.jsx";
import { semQuebra } from "./valores.js";

// O resultado do MEI, no mesmo formato de guia do Simples: o DAS fixo em destaque, os valores
// de cada tributo, o limite do ano (com a receita informada) e o atraso. A conta explicada
// fica em ContaPassoAPasso, como no Simples.
export default function ResultadoDoMei({ resultado, refTitulo, desatualizado }) {
  const { limite } = resultado;

  return (
    <section
      className={desatualizado ? "cartao guia desatualizado" : "cartao guia"}
      aria-labelledby="resultado-titulo"
    >
      <h2 id="resultado-titulo" ref={refTitulo} tabIndex={-1} className="das">
        <span className="das-rotulo">DAS do MEI</span>{" "}
        <span className="das-valor">{resultado.das}</span>
      </h2>
      <p className="das-mes">Referente a {resultado.periodo_nome}</p>

      {desatualizado && (
        <p className="nota nota-aviso">
          Você mudou os dados depois deste cálculo. Clique em Calcular para atualizar.
        </p>
      )}
      {limite.receita_ano && limite.situacao !== "dentro" && (
        <p className="nota nota-aviso">
          {semQuebra(
            `A receita de ${resultado.ano} (${limite.receita_ano}) passa do limite de ${limite.limite} em ${limite.excesso}. ` +
              (limite.diferenca
                ? `Diferença estimada sobre o excesso: ${limite.diferenca}. `
                : "") +
              "Veja o que acontece na conta passo a passo.",
          )}
        </p>
      )}

      <div className="picote" aria-hidden="true" />

      <dl className="resumo">
        <div>
          <dt>Atividade</dt>
          <dd>
            {resultado.atividade}
            {resultado.transportador && " (transportador de cargas)"}
          </dd>
        </div>
        <div>
          <dt>Limite do ano</dt>
          <dd>
            {limite.limite}
            {limite.situacao === "dentro" && " (a receita está dentro)"}
          </dd>
        </div>
      </dl>

      <table className="tabela tributos">
        <caption>Valores fixos do mês</caption>
        <thead>
          <tr>
            <th scope="col">Tributo</th>
            <th scope="col">Valor</th>
          </tr>
        </thead>
        <tbody>
          {resultado.tributos.map((tributo) => (
            <tr key={tributo.nome}>
              <th scope="row">{tributo.nome}</th>
              <td>{tributo.valor}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <th scope="row">DAS</th>
            <td>{resultado.das}</td>
          </tr>
        </tfoot>
      </table>
      {resultado.atraso && <Atraso atraso={resultado.atraso} das={resultado.das} />}

      <div className="acoes-resultado">
        <button type="button" className="botao secundario pequeno" onClick={() => window.print()}>
          Imprimir ou salvar a memória de cálculo
        </button>
      </div>
    </section>
  );
}
