import { useEffect, useId, useRef, useState } from "react";
import { calcular } from "./api.js";
import { conferir } from "./valores.js";
import Resultado from "./Resultado.jsx";

// Os nomes vêm dos títulos dos anexos na LC 123/2006 (iguais aos de data/anexos/).
const ANEXOS = [
  { valor: "1", rotulo: "Anexo I – Comércio" },
  { valor: "2", rotulo: "Anexo II – Indústria" },
  {
    valor: "3",
    rotulo: "Anexo III – Locação de bens móveis e serviços não relacionados no § 5º-C",
  },
  { valor: "4", rotulo: "Anexo IV – Serviços relacionados no § 5º-C" },
  { valor: "5", rotulo: "Anexo V – Serviços relacionados no § 5º-I" },
  { valor: "fator_r", rotulo: "Anexo III ou V, decidido pelo Fator R" },
];

const VAZIO = { rbt12: "", receita_mes: "", anexo: "", folha12: "" };

export default function Calculadora() {
  const [valores, setValores] = useState(VAZIO);
  const [erros, setErros] = useState({});
  const [estado, setEstado] = useState({ carregando: false, resultado: null, erro: null });
  const tituloResultado = useRef(null);

  // Leva o foco para o resultado: quem usa leitor de tela ouve o DAS logo depois de
  // calcular, e no celular a página rola até ele.
  useEffect(() => {
    if (estado.resultado) tituloResultado.current?.focus();
  }, [estado.resultado]);

  function mudar(evento) {
    setValores({ ...valores, [evento.target.name]: evento.target.value });
  }

  async function enviar(evento) {
    evento.preventDefault();
    const conferido = conferir(valores);
    setErros(conferido.erros);
    if (Object.keys(conferido.erros).length > 0) return;

    setEstado({ carregando: true, resultado: null, erro: null });
    const { resultado, erro } = await calcular(conferido.parametros);
    setEstado({ carregando: false, resultado: resultado ?? null, erro: erro ?? null });
  }

  return (
    <>
      <form className="formulario" onSubmit={enviar} noValidate>
        <CampoReais
          nome="rbt12"
          rotulo="Receita bruta dos 12 meses anteriores (RBT12)"
          dica="A soma do faturamento dos 12 meses antes do mês que você quer calcular."
          valor={valores.rbt12}
          erro={erros.rbt12}
          aoMudar={mudar}
        />
        <CampoReais
          nome="receita_mes"
          rotulo="Receita bruta do mês"
          valor={valores.receita_mes}
          erro={erros.receita_mes}
          aoMudar={mudar}
        />
        <CampoAnexo valor={valores.anexo} erro={erros.anexo} aoMudar={mudar} />
        {valores.anexo === "fator_r" && (
          <CampoReais
            nome="folha12"
            rotulo="Folha de salários dos 12 meses anteriores"
            dica="Com encargos: salários, pró-labore, contribuição patronal ao INSS e FGTS. Aluguéis e distribuição de lucros não entram (LC 123/2006, art. 18, §§ 24 e 26)."
            valor={valores.folha12}
            erro={erros.folha12}
            aoMudar={mudar}
          />
        )}
        <button type="submit" disabled={estado.carregando}>
          {estado.carregando ? "Calculando…" : "Calcular"}
        </button>
      </form>

      {estado.erro && (
        <p className="erro" role="alert">
          {estado.erro}
        </p>
      )}
      {estado.resultado && <Resultado resultado={estado.resultado} refTitulo={tituloResultado} />}
    </>
  );
}

// Campo de valor em reais, com dica e mensagem de erro ligadas ao campo (aria-describedby),
// para o leitor de tela ler as duas junto com o rótulo.
function CampoReais({ nome, rotulo, dica, valor, erro, aoMudar }) {
  const id = useId();
  const descricao = [dica && `${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ");

  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <div className="reais">
        <span aria-hidden="true">R$</span>
        <input
          id={id}
          name={nome}
          inputMode="decimal"
          autoComplete="off"
          placeholder="0,00"
          value={valor}
          onChange={aoMudar}
          aria-invalid={erro ? "true" : undefined}
          aria-describedby={descricao || undefined}
        />
      </div>
      {erro && (
        <p id={`${id}-erro`} className="erro-campo">
          {erro}
        </p>
      )}
    </div>
  );
}

function CampoAnexo({ valor, erro, aoMudar }) {
  const id = useId();
  const descricao = [`${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ");

  return (
    <div className="campo">
      <label htmlFor={id}>Anexo da atividade</label>
      <p id={`${id}-dica`} className="dica">
        Se a lei manda decidir entre o Anexo III e o V pela folha de salários, escolha a última
        opção.
      </p>
      <select
        id={id}
        name="anexo"
        value={valor}
        onChange={aoMudar}
        aria-invalid={erro ? "true" : undefined}
        aria-describedby={descricao}
      >
        <option value="" disabled>
          Escolha o anexo
        </option>
        {ANEXOS.map((anexo) => (
          <option key={anexo.valor} value={anexo.valor}>
            {anexo.rotulo}
          </option>
        ))}
      </select>
      {erro && (
        <p id={`${id}-erro`} className="erro-campo">
          {erro}
        </p>
      )}
    </div>
  );
}
