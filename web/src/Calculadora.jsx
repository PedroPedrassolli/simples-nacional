import { useEffect, useRef, useState } from "react";
import { calcular } from "./api.js";
import Anteriores from "./Anteriores.jsx";
import { Caixa, CampoLista, Etapa } from "./campos.jsx";
import CamposForaDoDas from "./CamposForaDoDas.jsx";
import { conferir, EXEMPLO, resumoDasReceitas, VAZIO } from "./formulario.js";
import MemoriaDeCalculo from "./MemoriaDeCalculo.jsx";
import {
  ANOS,
  MESES_DE_APURACAO,
  mesesDeInicio,
  podePassarDoSublimite,
  regrasDoAno,
} from "./periodos.js";
import Receitas from "./Receitas.jsx";
import Resultado, { ContaPassoAPasso } from "./Resultado.jsx";
import { nomeDoMes } from "./valores.js";

const GRUPOS_DE_MESES = ANOS.map((ano) => ({
  rotulo: String(ano),
  opcoes: MESES_DE_APURACAO.filter((mes) => mes.startsWith(String(ano))).map((mes) => ({
    valor: mes,
    rotulo: nomeDoMes(mes),
  })),
}));

const SEM_RESULTADO = { carregando: false, resultado: null, erro: null, entradas: null };

// O formulário e, ao lado (abaixo, no celular), o resultado. Embaixo do formulário vai a
// consulta de CNPJ (consulta), e a conta passo a passo ocupa a largura toda. A memória de
// cálculo só aparece na impressão (e no PDF). A posição de cada parte fica no estilo.css.
export default function Calculadora({ consulta }) {
  const [valores, setValores] = useState(VAZIO);
  const [erros, setErros] = useState({});
  const [estado, setEstado] = useState(SEM_RESULTADO);
  // O resultado na tela foi calculado com outros valores: a pessoa mudou um campo depois.
  const [desatualizado, setDesatualizado] = useState(false);
  const [sublimiteAberto, setSublimiteAberto] = useState(false);
  const [foraAberto, setForaAberto] = useState(false);
  // Aumenta a cada tentativa com erro, para o efeito abaixo levar o foco ao primeiro campo.
  const [tentativasComErro, setTentativasComErro] = useState(0);
  // Número do último pedido à API: uma resposta atrasada de um pedido antigo é ignorada.
  const pedido = useRef(0);
  // Quantas vezes os campos mudaram: se a pessoa mexer enquanto a API responde, o
  // resultado que chega já foi calculado com os valores antigos e nasce desatualizado.
  const mudancas = useRef(0);
  const formulario = useRef(null);
  const tituloResultado = useRef(null);
  const regras = regrasDoAno(valores.periodo);
  const resumo = resumoDasReceitas(valores.receitas);

  // Leva o foco para o resultado: quem usa leitor de tela ouve o DAS logo depois de
  // calcular, e no celular a página rola até ele.
  useEffect(() => {
    if (estado.resultado) tituloResultado.current?.focus();
  }, [estado.resultado]);

  // Com erro, o foco vai para o primeiro campo com problema (o leitor de tela lê a mensagem).
  useEffect(() => {
    if (tentativasComErro > 0) formulario.current?.querySelector("[aria-invalid=true]")?.focus();
  }, [tentativasComErro]);

  // mudanca: os campos novos. como.formatacao: só mudou o jeito de mostrar ("500000" virou
  // "500.000,00"), então o resultado na tela continua valendo.
  function mudar(mudanca, como = {}) {
    const novos = { ...valores, ...mudanca };
    // Trocou o mês de apuração e o início escolhido ficou fora da lista: volta para "já tinha".
    if ("periodo" in mudanca && !mesesDeInicio(novos.periodo).includes(novos.inicio))
      novos.inicio = "";
    // Os valores acabaram de passar do sublimite: abre os campos opcionais dele.
    if (!podePassarDoSublimite(valores) && podePassarDoSublimite(novos)) setSublimiteAberto(true);
    if (!como.formatacao) {
      mudancas.current++;
      if (estado.resultado) setDesatualizado(true);
    }
    setValores(novos);
  }

  async function enviar(evento) {
    evento.preventDefault();
    const conferido = conferir(valores);
    setErros(conferido.erros);
    const chaves = Object.keys(conferido.erros);
    if (chaves.some((chave) => chave.startsWith("receita_ano")) || podePassarDoSublimite(valores)) {
      setSublimiteAberto(true);
    }
    if (chaves.some((chave) => chave.startsWith("fora."))) setForaAberto(true);
    if (chaves.length > 0) {
      setTentativasComErro((total) => total + 1);
      return;
    }

    const estePedido = ++pedido.current;
    const mudancasNoPedido = mudancas.current;
    setEstado({ ...SEM_RESULTADO, carregando: true });
    const { resultado, erro } = await calcular(conferido.parametros);
    // Enquanto esperava, a pessoa limpou o formulário ou pediu outro cálculo.
    if (estePedido !== pedido.current) return;
    setEstado({
      carregando: false,
      resultado: resultado ?? null,
      erro: erro ?? null,
      entradas: valores,
    });
    setDesatualizado(mudancas.current !== mudancasNoPedido);
    // Falta dado para estimar algo fora do DAS: abre a parte desses campos.
    if (resultado?.fora_do_das?.some((estimativa) => estimativa.falta)) setForaAberto(true);
  }

  function recomecar(novosValores) {
    pedido.current++;
    setValores(novosValores);
    setErros({});
    setEstado(SEM_RESULTADO);
    setDesatualizado(false);
    setSublimiteAberto(false);
    setForaAberto(false);
  }

  const inicios = [
    { valor: "", rotulo: regras.novas ? "Há 13 meses ou mais" : "Há 12 meses ou mais" },
    ...mesesDeInicio(valores.periodo).map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) })),
  ];

  return (
    <div className="layout">
      <form ref={formulario} className="formulario cartao" onSubmit={enviar} noValidate>
        <Etapa titulo="Mês e empresa">
          <CampoLista
            nome="periodo"
            rotulo="Mês de apuração"
            dica="O mês do DAS que você quer calcular (de 2026 a 2028)."
            vazio="Escolha o mês"
            grupos={GRUPOS_DE_MESES}
            valor={valores.periodo}
            erro={erros.periodo}
            aoMudar={(periodo) => mudar({ periodo })}
          />
          <CampoLista
            nome="inicio"
            rotulo="Início das atividades"
            dica="Se a empresa começou há pouco tempo, escolha o mês em que ela começou. A lista aparece depois do mês de apuração."
            opcoes={inicios}
            valor={valores.inicio}
            aoMudar={(inicio) => mudar({ inicio })}
          />
          {regras.novas && (
            <Caixa
              nome="ibs_cbs_fora"
              rotulo="A empresa optou por pagar o IBS e a CBS fora do DAS (regime regular)"
              dica="Opção de 2027 em diante (Res. CGSN 140/2018, art. 40-C): o DAS fica sem o IBS e a CBS, que são apurados à parte, com créditos."
              marcada={valores.ibs_cbs_fora}
              aoMudar={(ibs_cbs_fora) => mudar({ ibs_cbs_fora })}
            />
          )}
        </Etapa>

        <Etapa
          titulo="Receitas do mês"
          dica="Uma linha por atividade, como no PGDAS-D. Com uma atividade só, preencha só a primeira."
        >
          <Receitas
            receitas={valores.receitas}
            ano={regras.ano}
            erros={erros}
            aoMudar={(receitas, como) => mudar({ receitas }, como)}
          />
        </Etapa>

        <Etapa titulo="Meses anteriores">
          <Anteriores
            valores={valores}
            erros={erros}
            resumo={resumo}
            aoMudar={mudar}
            sublimiteAberto={sublimiteAberto}
            aoAlternarSublimite={setSublimiteAberto}
          />
        </Etapa>

        <CamposForaDoDas
          valores={valores}
          erros={erros}
          resumo={resumo}
          aoMudar={mudar}
          aberto={foraAberto}
          aoAlternar={setForaAberto}
        />

        <div className="acoes">
          <button type="submit" className="botao primario" disabled={estado.carregando}>
            {estado.carregando ? "Calculando…" : "Calcular"}
          </button>
          <button type="button" className="botao secundario" onClick={() => recomecar(EXEMPLO)}>
            Usar um exemplo
          </button>
          <button type="button" className="botao discreto" onClick={() => recomecar(VAZIO)}>
            Limpar
          </button>
        </div>

        {estado.erro && (
          <p className="erro" role="alert">
            {estado.erro}
          </p>
        )}
      </form>

      <div className="lateral">
        {estado.resultado ? (
          <Resultado
            resultado={estado.resultado}
            refTitulo={tituloResultado}
            desatualizado={desatualizado}
          />
        ) : (
          <ComoFunciona carregando={estado.carregando} />
        )}
      </div>

      {estado.resultado && <ContaPassoAPasso resultado={estado.resultado} />}
      {estado.resultado && (
        <MemoriaDeCalculo resultado={estado.resultado} entradas={estado.entradas} />
      )}

      <div className="consulta">{consulta}</div>
    </div>
  );
}

// A guia "em branco" antes do primeiro cálculo (e enquanto a API responde): diz onde o
// resultado vai aparecer e resume a conta.
function ComoFunciona({ carregando }) {
  return (
    <section className="cartao como" aria-labelledby="como-titulo" aria-busy={carregando}>
      <p className={carregando ? "como-estado carregando" : "como-estado"}>
        {carregando && <span className="girando" aria-hidden="true" />}
        {carregando
          ? "Calculando o DAS…"
          : "Preencha os dados e clique em Calcular: o DAS aparece aqui."}
      </p>
      <h2 id="como-titulo">Como a conta é feita</h2>
      <ol>
        <li>
          <strong>Faixa.</strong> A receita dos 12 meses (RBT12) diz em qual das 6 faixas do anexo a
          empresa está.
        </li>
        <li>
          <strong>Alíquota efetiva.</strong> (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12.
        </li>
        <li>
          <strong>Cada receita.</strong> Cada atividade usa o seu anexo e deixa de fora o que já foi
          pago (substituição tributária, ISS retido, exportação…).
        </li>
        <li>
          <strong>DAS.</strong> A soma das receitas × percentuais, dividida entre os tributos.
        </li>
      </ol>
      <p className="fonte">
        LC 123/2006, art. 18, §§ 1º a 4º-A; Res. CGSN 140/2018, arts. 21 a 25.
      </p>
    </section>
  );
}
