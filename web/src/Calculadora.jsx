import { useEffect, useId, useRef, useState } from "react";
import { calcular } from "./api.js";
import {
  conferir,
  MESES_DE_APURACAO,
  mesesDeInicio,
  nomeDoMes,
  textosDosCampos,
} from "./valores.js";
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

const PERIODOS = MESES_DE_APURACAO.map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) }));

const VAZIO = {
  periodo: "",
  inicio: "",
  rbt12: "",
  receita_mes: "",
  receita_ano: "",
  receita_ano_anterior: "",
  anexo: "",
  folha12: "",
};

export default function Calculadora() {
  const [valores, setValores] = useState(VAZIO);
  const [erros, setErros] = useState({});
  const [estado, setEstado] = useState({ carregando: false, resultado: null, erro: null });
  const tituloResultado = useRef(null);
  const textos = textosDosCampos(valores.periodo, valores.inicio);

  // Leva o foco para o resultado: quem usa leitor de tela ouve o DAS logo depois de
  // calcular, e no celular a página rola até ele.
  useEffect(() => {
    if (estado.resultado) tituloResultado.current?.focus();
  }, [estado.resultado]);

  function mudar(evento) {
    const { name, value } = evento.target;
    const novos = { ...valores, [name]: value };
    // Trocou o mês de apuração e o início escolhido ficou fora da lista: volta para "12 meses ou mais".
    if (name === "periodo" && !mesesDeInicio(value).includes(novos.inicio)) novos.inicio = "";
    setValores(novos);
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

  const inicios = [
    { valor: "", rotulo: "Há 12 meses ou mais" },
    ...mesesDeInicio(valores.periodo).map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) })),
  ];

  return (
    <>
      <form className="formulario" onSubmit={enviar} noValidate>
        <CampoLista
          nome="periodo"
          rotulo="Mês de apuração"
          dica="O mês do DAS que você quer calcular. Por enquanto, só meses de 2026."
          vazio="Escolha o mês"
          opcoes={PERIODOS}
          valor={valores.periodo}
          erro={erros.periodo}
          aoMudar={mudar}
        />
        <CampoLista
          nome="inicio"
          rotulo="Início das atividades"
          dica="Se a empresa começou há menos de 12 meses, escolha o mês em que ela começou. A lista aparece depois do mês de apuração."
          opcoes={inicios}
          valor={valores.inicio}
          aoMudar={mudar}
        />
        {textos.receita ? (
          <CampoReais
            nome="rbt12"
            rotulo={textos.receita}
            dica={textos.dicaReceita}
            valor={valores.rbt12}
            erro={erros.rbt12}
            aoMudar={mudar}
          />
        ) : (
          <p className="dica">
            No 1º mês de atividade, a receita dos 12 meses (RBT12) é a receita do mês × 12.
          </p>
        )}
        <CampoReais
          nome="receita_mes"
          rotulo="Receita bruta do mês"
          valor={valores.receita_mes}
          erro={erros.receita_mes}
          aoMudar={mudar}
        />
        {(textos.receitaAno || textos.receitaAnoAnterior) && (
          <fieldset className="grupo">
            <legend>Sublimite do ICMS e do ISS (opcional)</legend>
            <p className="dica">
              Acima de R$ 3.600.000,00 no ano, o ICMS e o ISS mudam de regra. Em branco, a conta
              considera que a empresa não passou desse valor; se faltar algum número, ela avisa.
            </p>
            {textos.receitaAno && (
              <CampoReais
                nome="receita_ano"
                rotulo={textos.receitaAno}
                valor={valores.receita_ano}
                erro={erros.receita_ano}
                aoMudar={mudar}
              />
            )}
            {textos.receitaAnoAnterior && (
              <CampoReais
                nome="receita_ano_anterior"
                rotulo={textos.receitaAnoAnterior}
                valor={valores.receita_ano_anterior}
                erro={erros.receita_ano_anterior}
                aoMudar={mudar}
              />
            )}
          </fieldset>
        )}
        <CampoLista
          nome="anexo"
          rotulo="Anexo da atividade"
          dica="Se a lei manda decidir entre o Anexo III e o V pela folha de salários, escolha a última opção."
          vazio="Escolha o anexo"
          opcoes={ANEXOS}
          valor={valores.anexo}
          erro={erros.anexo}
          aoMudar={mudar}
        />
        {valores.anexo === "fator_r" && (
          <CampoReais
            nome="folha12"
            rotulo={textos.folha}
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

// Lista de opções (mês, início, anexo). vazio: o texto da primeira opção, que não pode
// ser escolhida de volta; sem ele, a primeira opção da lista vale como padrão.
function CampoLista({ nome, rotulo, dica, vazio, opcoes, valor, erro, aoMudar }) {
  const id = useId();
  const descricao = [`${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ");

  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      <p id={`${id}-dica`} className="dica">
        {dica}
      </p>
      <select
        id={id}
        name={nome}
        value={valor}
        onChange={aoMudar}
        aria-invalid={erro ? "true" : undefined}
        aria-describedby={descricao}
      >
        {vazio && (
          <option value="" disabled>
            {vazio}
          </option>
        )}
        {opcoes.map((opcao) => (
          <option key={opcao.valor} value={opcao.valor}>
            {opcao.rotulo}
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
