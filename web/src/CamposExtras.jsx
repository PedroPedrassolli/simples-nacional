import { CampoData, CampoReais, Revelar } from "./campos.jsx";

// ICMS ou ISS em valor fixo: o estado ou o município pode cobrar um valor por mês das ME com
// receita de até R$ 360.000,00 no ano anterior (LC 123/2006, art. 18, §§ 18 e 18-A; Res. CGSN
// 140/2018, art. 33). Com o valor informado, o imposto sai do percentual e o valor entra no DAS.
export function CamposDeValorFixo({ valores, erros, aoMudar, aberto, aoAlternar }) {
  const campo = (nome, rotulo) => (
    <CampoReais
      nome={nome}
      rotulo={rotulo}
      valor={valores[nome]}
      erro={erros[nome]}
      aoMudar={(valor, como) => aoMudar({ [nome]: valor }, como)}
    />
  );
  return (
    <Revelar
      className="opcional"
      titulo="ICMS ou ISS em valor fixo"
      selo="opcional"
      dica="Para ME com receita de até R$ 360.000,00, quando o estado ou o município adota"
      aberto={aberto}
      aoAlternar={aoAlternar}
    >
      <p className="dica">
        Informe o valor mensal que o estado ou o município cobra. A calculadora tira o imposto do
        percentual e soma o valor fixo ao DAS. Escritórios de contabilidade com ISS fixo também usam
        estes campos (LC 123/2006, art. 18, § 22-A).
      </p>
      <div className="grade">
        {campo("icms_fixo", "ICMS por mês")}
        {campo("iss_fixo", "ISS por mês")}
      </div>
    </Revelar>
  );
}

// A data do pagamento, para a multa e os juros do DAS pago depois do vencimento (Lei
// 9.430/1996, art. 61; Res. CGSN 140/2018, art. 40).
export function CampoDePagamento({ valores, erros, aoMudar, aberto, aoAlternar }) {
  return (
    <Revelar
      className="opcional"
      titulo="Pagamento em atraso"
      selo="opcional"
      dica="Multa e juros do DAS pago depois do vencimento"
      aberto={aberto}
      aoAlternar={aoAlternar}
    >
      <CampoData
        nome="pagamento"
        rotulo="Data do pagamento"
        dica="O DAS vence no dia 20 do mês seguinte (ou no dia útil depois). Pago depois, tem multa de 0,33% por dia (até 20%) e juros pela Selic."
        valor={valores.pagamento}
        erro={erros.pagamento}
        aoMudar={(pagamento) => aoMudar({ pagamento })}
      />
    </Revelar>
  );
}
