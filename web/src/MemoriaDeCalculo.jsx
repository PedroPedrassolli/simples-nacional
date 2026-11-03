import { linhasDaMemoria, resumoDasReceitas } from "./formulario.js";
import { linhasDaMemoriaDoMei } from "./mei.js";
import { mesesDoHistorico, regrasDoAno } from "./periodos.js";
import { agrupar, Tributos } from "./Resultado.jsx";
import { formatarReais, mesCurto, semQuebra } from "./valores.js";

// A memória de cálculo: só aparece na impressão (o navegador salva em PDF pelo mesmo botão).
// Junta o que a pessoa informou, o resultado e a conta inteira, com a base legal, para
// guardar junto com a guia ou levar ao contador. A tela usa os componentes do resultado;
// aqui tudo fica aberto e em ordem, sem botões.
export default function MemoriaDeCalculo({ resultado, entradas }) {
  const hoje = new Date().toLocaleDateString("pt-BR");
  const doMei = resultado.regime === "mei";
  const { atraso } = resultado;

  return (
    <article className="memoria" aria-labelledby="memoria-titulo">
      <header>
        <h2 id="memoria-titulo">
          Memória de cálculo do DAS{doMei && " do MEI"} de {resultado.periodo_nome}
        </h2>
        <p>
          Gerada em {hoje} pela Calculadora do Simples Nacional (simples-nacional-br.vercel.app).
          Estimativa educativa: o valor a pagar é o da guia gerada no {doMei ? "PGMEI" : "PGDAS-D"}.
        </p>
      </header>

      <h3>Dados informados</h3>
      <dl className="memoria-dados">
        {(doMei ? linhasDaMemoriaDoMei(entradas) : linhasDaMemoria(entradas)).map(
          ([rotulo, valor]) => (
            <div key={rotulo}>
              <dt>{rotulo}</dt>
              <dd>{valor}</dd>
            </div>
          ),
        )}
      </dl>
      {!doMei && <ReceitasInformadas atividades={resultado.atividades} />}
      {!doMei && entradas.modo === "meses" && <MesAMes entradas={entradas} />}

      <h3>Resultado</h3>
      <dl className="memoria-dados">
        <div>
          <dt>DAS estimado</dt>
          <dd>{resultado.das}</dd>
        </div>
        {!doMei && (
          <div>
            <dt>Alíquota sobre a receita do mês</dt>
            <dd>{resultado.aliquota_efetiva}</dd>
          </div>
        )}
        {atraso && atraso.dias > 0 && (
          <>
            <div>
              <dt>
                Multa de mora ({atraso.multa_percentual}, {atraso.dias} dias)
              </dt>
              <dd>{atraso.multa}</dd>
            </div>
            <div>
              <dt>Juros de mora ({atraso.juros_percentual})</dt>
              <dd>{atraso.juros}</dd>
            </div>
            <div>
              <dt>Total a pagar em {atraso.pagamento}</dt>
              <dd>{atraso.total}</dd>
            </div>
          </>
        )}
        {resultado.fora_do_das?.length > 0 && (
          <div>
            <dt>Total estimado do mês (DAS + fora do DAS)</dt>
            <dd>{resultado.total_estimado}</dd>
          </div>
        )}
      </dl>
      {(resultado.avisos ?? []).map((aviso) => (
        <p key={aviso}>{semQuebra(aviso)}</p>
      ))}
      {doMei ? (
        <ValoresDoMei resultado={resultado} />
      ) : (
        <Tributos
          tributos={resultado.tributos}
          rodape={["DAS", resultado.aliquota_efetiva, resultado.das]}
        />
      )}
      {resultado.fora_do_das?.length > 0 && (
        <ul>
          {resultado.fora_do_das.map((estimativa) => (
            <li key={estimativa.tributo}>
              <strong>
                {estimativa.tributo} fora do DAS: {estimativa.valor ?? "não estimado"}.
              </strong>{" "}
              {semQuebra([estimativa.texto, estimativa.falta].filter(Boolean).join(" "))}
            </li>
          ))}
        </ul>
      )}

      <h3>Conta passo a passo</h3>
      {agrupar(resultado.passos).map(([grupo, passos]) => (
        <section key={grupo} className="memoria-grupo">
          <h4>{grupo}</h4>
          <ol>
            {passos.map((passo) => (
              <li key={passo.titulo}>
                <strong>{passo.titulo}.</strong> {semQuebra(passo.texto)}{" "}
                <span className="fonte">({semQuebra(passo.fonte)})</span>
              </li>
            ))}
          </ol>
        </section>
      ))}

      <footer>
        <p>
          {resultado.tabela && `Tabelas: ${resultado.tabela.fonte}. `}
          Confira os dados e o valor no {doMei ? "PGMEI" : "PGDAS-D"} antes de pagar; a calculadora
          não guarda nem envia nada além do que está na URL do cálculo.
        </p>
      </footer>
    </article>
  );
}

// Os valores fixos do DAS do MEI.
function ValoresDoMei({ resultado }) {
  return (
    <table className="tabela">
      <caption>Valores fixos do mês</caption>
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
  );
}

// As receitas do mês como foram informadas (o nome do tipo e as situações vêm da API).
function ReceitasInformadas({ atividades }) {
  return (
    <table className="tabela">
      <caption>Receitas do mês</caption>
      <thead>
        <tr>
          <th scope="col">Receita</th>
          <th scope="col">Situações</th>
          <th scope="col">Valor</th>
        </tr>
      </thead>
      <tbody>
        {atividades.map((atividade) => (
          <tr key={atividade.numero}>
            <th scope="row">
              {atividade.numero}. {atividade.nome}
            </th>
            <td>{atividade.opcoes.length > 0 ? atividade.opcoes.join("; ") : "nenhuma"}</td>
            <td>{atividade.receita}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// O mês a mês informado, uma linha por mês (exportação e folha só quando fazem diferença).
function MesAMes({ entradas }) {
  const meses = mesesDoHistorico(entradas.periodo, entradas.inicio);
  const resumo = resumoDasReceitas(entradas.receitas);
  const colunas = [["receita", "Receita"]];
  if (resumo.exportacao) colunas.push(["exportacao", "Exportação"]);
  if (resumo.fatorR) colunas.push(["folha", "Folha"]);
  const valor = (mes, campo) => {
    const texto = String(entradas.meses[mes]?.[campo] ?? "").trim();
    return texto === "" ? "R$ 0,00" : `R$ ${formatarReais(texto)}`;
  };

  return (
    <table className="tabela">
      <caption>
        Meses anteriores
        {regrasDoAno(entradas.periodo).novas && " (o mês anterior não entra na RBT12)"}
      </caption>
      <thead>
        <tr>
          <th scope="col">Mês</th>
          {colunas.map(([campo, rotulo]) => (
            <th key={campo} scope="col">
              {rotulo}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {meses.map((mes) => (
          <tr key={mes}>
            <th scope="row">{mesCurto(mes)}</th>
            {colunas.map(([campo]) => (
              <td key={campo}>{valor(mes, campo)}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
