import { useId, useState } from "react";
import { consultarCnpj } from "./api.js";
import { textoSimples } from "./valores.js";

const LEI = "https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm";

// Consulta opcional: mostra a empresa, o CNAE principal e a situação no Simples.
// Não muda a conta; serve para ajudar a escolher o anexo.
export default function ConsultaCnpj() {
  const [cnpj, setCnpj] = useState("");
  const [estado, setEstado] = useState({ carregando: false, empresa: null, erro: null });
  const id = useId();

  async function consultar(evento) {
    evento.preventDefault();
    if (cnpj.trim() === "") {
      setEstado({ carregando: false, empresa: null, erro: "Digite o CNPJ." });
      return;
    }

    setEstado({ carregando: true, empresa: null, erro: null });
    const { empresa, erro } = await consultarCnpj(cnpj.trim());
    setEstado({ carregando: false, empresa: empresa ?? null, erro: erro ?? null });
  }

  return (
    <details className="cartao revelar cnpj">
      <summary>
        <span className="revelar-textos">
          <span className="revelar-titulo">
            Consultar um CNPJ <span className="selo">opcional</span>
          </span>
          <span className="revelar-dica">
            Mostra a atividade principal (CNAE), que ajuda a escolher o anexo
          </span>
        </span>
      </summary>
      <div className="revelar-corpo">
        <form onSubmit={consultar} noValidate>
          <label htmlFor={id}>CNPJ</label>
          <p id={`${id}-dica`} className="dica">
            Também mostra se a empresa consta como optante pelo Simples. A consulta não muda a
            conta.
          </p>
          <div className="linha">
            <input
              id={id}
              name="cnpj"
              autoComplete="off"
              // O CNPJ novo pode ter letras (Receita Federal, desde julho de 2026), por isso o
              // teclado é o de texto, em maiúsculas e sem corretor ortográfico.
              autoCapitalize="characters"
              spellCheck={false}
              placeholder="00.000.000/0000-00"
              value={cnpj}
              onChange={(evento) => setCnpj(evento.target.value)}
              aria-describedby={`${id}-dica`}
            />
            <button type="submit" className="botao secundario" disabled={estado.carregando}>
              {estado.carregando ? "Consultando…" : "Consultar"}
            </button>
          </div>
        </form>

        {estado.erro && (
          <p className="erro" role="alert">
            {estado.erro}
          </p>
        )}
        {/* A região fica sempre na página (vazia até a resposta) para o leitor de tela
          anunciar a empresa quando ela aparece. */}
        <div className="cnpj-resposta" aria-live="polite">
          {estado.empresa && <Empresa empresa={estado.empresa} />}
        </div>
      </div>
    </details>
  );
}

function Empresa({ empresa }) {
  const cnae = [empresa.cnae.codigo, empresa.cnae.descricao].filter(Boolean).join(" – ");

  return (
    <div className="empresa">
      <p>
        <strong>{empresa.razao_social}</strong>
      </p>
      <dl className="resumo">
        <div>
          <dt>CNPJ</dt>
          <dd>{empresa.cnpj}</dd>
        </div>
        <div>
          <dt>Situação</dt>
          <dd>{empresa.situacao}</dd>
        </div>
        <div className="largo">
          <dt>CNAE principal</dt>
          <dd>{cnae}</dd>
        </div>
        <div className="largo">
          <dt>Simples</dt>
          <dd>{textoSimples(empresa.simples)}</dd>
        </div>
      </dl>
      <p className="fonte">
        O CNAE sozinho não decide o anexo: a lei distribui as atividades entre os anexos no art. 18
        da LC 123/2006 (para os serviços, §§ 5º-B a 5º-I). <a href={LEI}>Ver a lei no Planalto</a>.
        Dados: {empresa.fonte}.
      </p>
    </div>
  );
}
