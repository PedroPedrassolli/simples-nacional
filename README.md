# Calculadora do Simples Nacional

Estimativa educativa da alíquota efetiva e do DAS do Simples Nacional (e do DAS do MEI),
com a conta explicada passo a passo. Regra de negócio confusa em código claro.

**No ar:** [simples-nacional-br.vercel.app](https://simples-nacional-br.vercel.app)

## O que a calculadora faz

Faz a mesma apuração do PGDAS-D para os casos mais comuns, mês a mês, de **janeiro de 2026 a
dezembro de 2028**, e mostra:

- o **DAS estimado**, com a **alíquota efetiva** de cada receita:
  `(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12` (LC 123/2006, art. 18, § 1º-A);
- a **divisão do DAS entre os tributos** (IRPJ, CSLL, Cofins, PIS/Pasep, CPP, IPI, ICMS, ISS e,
  a partir de 2027, CBS e IBS), com o ISS limitado a 5% e, na 6ª faixa, o ICMS/ISS/IBS da 5ª;
- o que é pago **fora do DAS**, estimado com as alíquotas que a pessoa informar, e o **total
  do mês** (DAS + fora do DAS);
- a **multa e os juros** do DAS pago em atraso;
- a conta **passo a passo**, com a base legal de cada passo, e a **memória de cálculo** para
  imprimir ou salvar em PDF.

**Receitas separadas por atividade (segregação):** até 10 receitas no mês, cada uma no seu
anexo: revenda (Anexo I), indústria (Anexo II em 2026; Anexo I a partir de 2027, menos o
produto com IPI mantido), serviços dos Anexos III, IV e V, serviços pelo Fator R, locação de
bens móveis (Anexo III sem o ISS) e transporte intermunicipal ou comunicação (Anexo III sem o
ISS e com o ICMS do Anexo I) e a industrialização com IPI e ISS ao mesmo tempo (Anexo II sem o
ICMS e com o ISS do Anexo III; LC 123/2006, art. 18, § 4º, VI). Em cada receita dá para marcar
ICMS por substituição tributária, PIS/Cofins monofásicos (IBS e CBS a partir de 2027), ISS
retido, exportação (com RBT12 própria, Res. CGSN 140/2018, art. 23) e a **isenção ou redução**
do ICMS ou do ISS dada pelo estado ou pelo município (a redução diminui o percentual do imposto
na mesma proporção; LC 123/2006, art. 18, §§ 20 e 20-A; Res. CGSN 140/2018, art. 35). Fonte de
cada tipo em `lib/simples_nacional/atividades.rb`.

**ICMS e ISS em valor fixo:** com o valor mensal informado, o imposto sai do percentual e o
valor entra no DAS (LC 123/2006, art. 18, §§ 18, 18-A e 22-A; Res. CGSN 140/2018, arts. 33 e
34). A calculadora avisa quando a empresa não se encaixa no art. 33 (receita acima de
R$ 360.000,00, ano de início) ou o valor passa do máximo da faixa.

**Meses anteriores:** a soma (RBT12, folha do Fator R) ou o **mês a mês**, como no PGDAS-D.
A partir de 2027 a RBT12 é dos 12 meses antes do mês anterior, e o mês anterior entra à parte,
só na receita do ano (Res. CGSN 140/2018, art. 21, II, a, na redação da Res. CGSN 190/2026).

**Início de atividade:** em 2026, no 1º mês a RBT12 é a receita do mês × 12; depois, a média
dos meses anteriores × 12 (LC 123/2006, art. 18, § 2º; Res. CGSN 140/2018, art. 22). A partir
de 2027, o 1º e o 2º mês usam a 1ª faixa, e o Fator R é 28% (arts. 22 e 26, redação da Res.
190/2026).

**Sublimite e limite:** R$ 3.600.000,00 em todos os estados (Portarias CGSN nº 49/2024 e
nº 54/2025; a partir de 2027, art. 9º da Res. 140 na redação da Res. 190/2026). Com a receita
do ano e a do ano anterior, a calculadora aplica os arts. 12 e 24 da Res. CGSN 140/2018: em
2026, a parte da receita acima do sublimite ou do limite paga pelo percentual maior; acima de
20%, o ICMS e o ISS (e o IBS, a partir de 2027) saem do DAS. Acima de R$ 4.800.000,00 ela
calcula o mês até a exclusão e diz quando a empresa sai do Simples. No ano de início, os dois
são proporcionais aos meses. A **exportação tem um limite extra**, de mais R$ 4.800.000,00 no
ano, com as mesmas regras (LC 123/2006, art. 3º, §§ 14 e 15; Res. CGSN 140/2018, art. 24, § 8º).

**Pagamento em atraso:** com a data do pagamento, a calculadora acha o vencimento (dia 20 do
mês seguinte ou o dia útil depois; Res. CGSN 140/2018, art. 40) e soma a multa de 0,33% por dia,
até 20%, e os juros pela Selic de cada mês mais 1% no mês do pagamento (Lei 9.430/1996, art. 61;
LC 123/2006, art. 35). A Selic fica em `data/selic.yml`, que o workflow `selic.yml` atualiza todo
mês com a série 4390 do Banco Central.

**ICMS por substituição tributária e diferencial de alíquota:** quem vende como substituta e
quem compra de outros estados para uso, consumo ou o ativo paga o ICMS fora do DAS, com as
regras das demais empresas (LC 123/2006, art. 13, § 1º, XIII, a, g e h, e § 5º; Convênio ICMS
142/2018). A calculadora estima os dois com a MVA e as alíquotas informadas.

**MEI:** o DAS fixo do mês (INSS de 5% do salário mínimo, 12% para o transportador autônomo de
cargas, mais o ICMS e o ISS fixos e, de 2027 em diante, a CBS e o IBS do Anexo VII da LC 123/2006)
e, com a receita do ano, o limite (R$ 81.000,00, proporcional no ano de início) e o que acontece
acima dele (LC 123/2006, art. 18-A; Res. CGSN 140/2018, arts. 100, 101 e 115). Os valores
ficam em `data/mei.yml`.

**IBS e CBS fora do DAS (2027 em diante):** a empresa que optar pelo regime regular paga o
IBS e a CBS à parte, com créditos (Res. CGSN 140/2018, arts. 22-A e 40-C, na redação da Res.
190/2026). A calculadora tira os dois do DAS e estima o valor com as alíquotas informadas.

Opcional: informe um CNPJ para ver a empresa, o CNAE principal e se ela consta como optante
pelo Simples (dados públicos da Receita Federal, pela BrasilAPI).

**Na página:** o visual segue o do [portfólio](https://pedrassolli.vercel.app) (tema escuro por
padrão, com botão para o claro). O formulário começa pela chave "Simples Nacional / MEI" e pelo
mês e ano em duas listas; depois vêm uma linha por receita, a chave "Somados / Mês a mês" e
partes opcionais (valor fixo, sublimite, tributos fora do DAS, pagamento em atraso) que abrem
sozinhas quando fazem diferença. Os valores ficam no formato brasileiro ao sair do campo, e "Usar um
exemplo" preenche números fictícios. Se um campo muda depois do cálculo, a página avisa que o
resultado ficou desatualizado.

As tabelas dos Anexos I a V ficam em `data/anexos/2026/` (LC 155/2016) e
`data/anexos/2027-2028/` (LC 214/2025), cada arquivo com o link da fonte oficial, a lei que deu
a redação, a vigência e a data da conferência. Um teste falha se faltar a fonte ou a vigência,
ou se a repartição de uma faixa não somar 100%.

### O que ela não faz

- **Não gera a guia:** é uma estimativa educativa. O valor a pagar é o do PGDAS-D, e a
  responsabilidade pelos dados é da empresa e do contador.
- Não transmite a declaração e não calcula a multa por atraso na entrega dela.
- Os tributos fora do DAS são estimativas simples (base × alíquota − créditos; ICMS-ST com a MVA
  informada; CPP do Anexo IV com RAT e FAP informados), sem as regras de cada estado ou
  município (MVA ajustada, fundos de combate à pobreza, benefícios).
- No MEI que passou do limite em mais de 20%, ela diz o que acontece, mas a apuração do ano como
  ME é feita no modo Simples, mês a mês.
- Aceita meses de 2026 a 2028 (em 2029 as tabelas mudam de novo, LC 214/2025).

## Como funciona

```
lib/simples_nacional/   Ruby puro, sem dependências: regras de cada ano, receitas, faixa, Fator R,
                        sublimite e limite, divisão do DAS, fora do DAS e os passos da conta
data/anexos/            tabelas dos Anexos I a V de 2026 e de 2027-2028, com fonte oficial e vigência
data/sublimite.yml      sublimite de cada ano, com o ato e o link
data/selic.yml          Selic de cada mês (juros do atraso), atualizada todo mês por um workflow
data/mei.yml            salário mínimo e valores fixos do MEI de cada ano, com a fonte
api/calcular.rb         função Ruby da Vercel: recebe os números e devolve o resultado e os passos (JSON)
api/cnpj.rb             consulta opcional de CNPJ pela gem br_validators (BrasilAPI)
web/                    React + Vite, build estático e pré-renderizado (formulário, resultado, memória)
test/                   Minitest, com 100% das linhas cobertas
```

- A regra fica num lugar só, em Ruby testável. A página só mostra o que a API devolve.
- A função da Vercel guarda só o código (sem imagem de container), e a resposta tem
  cache de CDN: o resultado depende só dos números enviados.
- A página é estática e roda com uma Content Security Policy sem `unsafe-inline`.

### A biblioteca

Dinheiro em centavos (Integer) e percentuais em `Rational`, para nenhuma conta passar por Float:

```ruby
require "simples_nacional"

# Duas receitas no mês: revenda com ICMS por substituição tributária e serviços do Anexo III
resultado = SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, atividades: [
  { tipo: "revenda", receita: 3_000_000, opcoes: ["st_icms"] },
  { tipo: "servicos_3", receita: 1_000_000 }
])
resultado.das                       # => 233944 (R$ 2.339,44)
resultado.atividades.map(&:valor)   # => [134224, 99720]
resultado.passos.map(&:texto)       # a conta explicada, com a base legal de cada passo

# Uma receita só, do jeito antigo (continua valendo)
SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3).das # => 398880

# 2027, com o IBS e a CBS fora do DAS e a CBS estimada a 8,8%
resultado = SimplesNacional.calcular(periodo: "2027-03", rbt12: 50_000_000, receita_mes_anterior: 4_000_000,
                                     atividades: [{ tipo: "servicos_3", receita: 4_000_000 }], ibs_cbs_fora: true,
                                     fora_do_das: { aliquota_cbs: Rational(88, 1000) })
resultado.fora_do_das.map { |estimativa| [estimativa.tributo, estimativa.valor] } # => [["IBS", nil], ["CBS", 352000]]

# Redução de 40% do ISS dada pelo município, pago em 15/07/2026 (vencimento em 20/04/2026)
resultado = SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, pagamento: "2026-07-15", atividades: [
  { tipo: "servicos_3", receita: 4_000_000, opcoes: ["reducao_iss=40"] }
])
[resultado.das, resultado.atraso.multa, resultado.atraso.juros] # => [347026, 69405, 11070]

# MEI de comércio em março de 2026, com R$ 90.000,00 de receita no ano
mei = SimplesNacional.calcular_mei(periodo: "2026-03", atividade: "comercio", receita_ano: 9_000_000)
[mei.das, mei.limite.situacao, mei.limite.diferenca] # => [8205, :ate_vinte_por_cento, 36000]
```

### A API

```
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=servicos_3:40000.00
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=revenda:30000.00:st_icms;servicos_3:10000.00
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=fator_r:40000.00&folha12=150000.00
GET /api/calcular?periodo=2026-03&atividades=servicos_4:40000.00&rbt12=500000.00&folha_empregados=30000.00&pro_labore=5000.00&rat=2&fap=1.5
GET /api/calcular?periodo=2027-03&rbt12=500000.00&receita_mes_anterior=40000.00&atividades=servicos_3:40000.00&ibs_cbs_fora=1&aliquota_cbs=8.8
GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=3
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=industria_iss:30000.00:reducao_iss=40&pagamento=2026-07-15
GET /api/calcular?regime=mei&periodo=2026-03&mei_atividade=comercio&receita_ano=90000.00
```

Valores em reais, com ponto e até duas casas; meses como `AAAA-MM`; alíquotas em % (`3.5`).

| Parâmetro | O que é |
| --- | --- |
| `periodo` | Mês de apuração, de `2026-01` a `2028-12` |
| `atividades` | Receitas do mês: `tipo:valor:opção+opção`, separadas por `;`. Tipos: `revenda`, `industria`, `industria_iss`, `servicos_3`, `servicos_4`, `servicos_5`, `fator_r`, `locacao`, `transporte`. Opções: `st_icms`, `monofasico`, `iss_retido`, `exportacao`, `ipi_mantido` (2027 em diante), `isencao_icms`, `isencao_iss`, `reducao_icms=40`, `reducao_iss=40` (o % da redução depois do `=`) |
| `anexo` e `receita_mes` | Jeito antigo, com uma receita só (`anexo` de 1 a 5 ou `fator_r`) |
| `rbt12`, `rbt12_exportacao`, `folha12` | Somas dos meses anteriores (com `inicio`, desde o início das atividades) |
| `mes_AAAA-MM` | Mês a mês, no lugar das somas: `receita:exportação:folha` (ex.: `mes_2025-03=41666.66:0:5000`) |
| `inicio` | Mês de início das atividades, para quem ainda não tem 12 meses (13 a partir de 2027) |
| `receita_mes_anterior` | A partir de 2027: receita do mês anterior (fica fora da RBT12) |
| `receita_ano`, `receita_ano_anterior` | Opcionais, para o sublimite e o limite (a API pede quando faz diferença) |
| `receita_ano_exportacao` | Opcional: receita de exportação do ano até o mês anterior, para o limite extra da exportação |
| `icms_fixo`, `iss_fixo` | Opcionais: ICMS ou ISS em valor fixo por mês |
| `pagamento` | Opcional: data do pagamento (`AAAA-MM-DD`), para a multa e os juros |
| `ibs_cbs_fora=1` | A partir de 2027: IBS e CBS no regime regular, fora do DAS |
| `aliquota_iss`, `aliquota_icms`, `creditos_icms`, `aliquota_ibs`, `creditos_ibs`, `aliquota_cbs`, `creditos_cbs` | Opcionais, para estimar o que fica fora do DAS |
| `folha_empregados`, `pro_labore`, `rat` (1, 2 ou 3), `fap` (0.5 a 2) | Opcionais, para a CPP do Anexo IV |
| `st_valor`, `st_ipi`, `st_mva`, `st_aliquota_interna`, `st_aliquota_propria` | Opcionais, para o ICMS por substituição tributária (a empresa é a substituta) |
| `difal_valor`, `difal_aliquota_interna`, `difal_aliquota_interestadual` | Opcionais, para o diferencial de alíquota do ICMS |
| `regime=mei` | MEI, com `mei_atividade` (`comercio`, `industria`, `servicos` ou `comercio_servicos`) e, se quiser, `transportador=1`, `inicio`, `receita_ano`, `salario_minimo` (quando o decreto do ano ainda não está em `data/mei.yml`) e `pagamento` |

A resposta traz `das` e `das_centavos`, `aliquota_efetiva` (média ponderada quando há mais de
uma receita), `rbt12`, `fator_r`, `tributos` (soma de todas as receitas), `atividades` (anexo,
faixa, percentual, valor e tributos de cada receita), `fora_do_das` (tributo, valor ou o dado
que `falta`, texto e fonte), `total_estimado`, `atraso` (vencimento, dias, multa, juros e
total, ou `null`), `avisos`, os `passos` (com o `grupo` de cada um) e a `tabela` usada. No MEI,
`regime: "mei"`, `das`, `tributos` (nome e valor), `limite` (limite, receita do ano, excesso,
diferença e situação), `atraso` e `passos`. Os campos de antes (`anexo`, `faixa`, `aliquota_nominal`, `aviso`)
continuam, com os dados da primeira receita. Entrada inválida responde 400 com `erro`.

```
GET /api/cnpj?cnpj=11.222.333/0001-81
```

Consulta opcional: valida o CNPJ com a gem [br_validators](https://rubygems.org/gems/br_validators)
(CNPJ inválido nem chega à internet) e busca na BrasilAPI a razão social, a situação, o CNAE
principal e a opção pelo Simples (`simples.optante`, `desde`, `excluida_em`). Não devolve o
quadro de sócios. O CNAE não escolhe o anexo sozinho: quem decide é a atividade, conforme o
art. 18 da LC 123/2006.

## Fontes oficiais

- [Lei Complementar nº 123/2006, texto compilado (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm):
  limites (art. 3º), alíquota efetiva e Fator R (art. 18) e Anexos I a V, com os percentuais
  de repartição (redação da Lei Complementar nº 155/2016, vigência desde 01/01/2018).
  Conferido em 27/10/2026.
- [Resolução CGSN nº 140/2018 (normas da Receita Federal)](https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278):
  percentual efetivo de cada tributo, teto de 5% do ISS e ICMS/ISS na 6ª faixa (art. 21, III),
  RBT12 no início de atividade (art. 22) e folha do Fator R (art. 26). Conferido em 27/10/2026.
- Sublimite: [Portal do Simples Nacional, 2026 (Portaria CGSN nº 54/2025)](https://www8.receita.fazenda.gov.br/SIMPLESNACIONAL/noticias/NoticiaCompleta.aspx?id=94c10cc2-7eb5-4ef0-bfb2-5479e72caff8)
  e [2025 (Portaria CGSN nº 49/2024)](https://www8.receita.fazenda.gov.br/SIMPLESNACIONAL/noticias/NoticiaCompleta.aspx?id=24d7bd11-494d-4ed4-8e28-bb59a8d480e7),
  em `data/sublimite.yml`. Conferido em 27/10/2026.
- [Lei Complementar nº 214/2025 (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm):
  Anexos I a V para 2027 e 2028 (Anexos XVIII a XXII, art. 519), em `data/anexos/2027-2028/`.
  Conferido em 02/11/2026.
- [Resolução CGSN nº 190/2026](https://normasinternet2.receita.fazenda.gov.br/#/consulta/externa/152832):
  nova redação da Res. CGSN 140/2018 a partir de 2027 (RBT12, início de atividade, sublimite,
  segregação, IBS e CBS fora do DAS). Conferido em 02/11/2026.
- [Portal do Simples Nacional: opção pelo regime regular do IBS e da CBS para 2027](https://www8.receita.fazenda.gov.br/simplesnacional/noticias/NoticiaCompleta.aspx?id=c739e03c-8482-473f-8e82-f38ec3b13637).
- [Lei nº 9.430/1996 (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/l9430.htm): multa e
  juros de mora (art. 61). Selic acumulada no mês: [série 4390 do Banco Central](https://api.bcb.gov.br/dados/serie/bcdata.sgs.4390/dados?formato=json&dataInicial=01/01/2026),
  em `data/selic.yml`. Conferido em 03/11/2026.
- [Convênio ICMS nº 142/2018 (Confaz)](https://www.confaz.fazenda.gov.br/legislacao/convenios/2018/CV142_18):
  MVA e ICMS próprio do remetente do Simples na substituição tributária. Conferido em 03/11/2026.
- [Decreto nº 12.797/2025 (Planalto)](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/decreto/d12797.htm):
  salário mínimo de 2026, base do INSS do MEI, em `data/mei.yml`. Conferido em 03/11/2026.

## Rodar na sua máquina

Ruby 3.3 e Node 24 (versões em `.ruby-version` e `web/.nvmrc`).

```bash
bundle install
bundle exec rake test        # testes do Ruby, com cobertura
bundle exec rubocop          # estilo

cd web
npm ci
npm run dev                  # página em http://localhost:5173 (usa a API publicada)
npm test                     # funções do formulário e das chamadas à API
npm run build && npm run test:e2e   # navegador: fluxos, acessibilidade, 320 px e imagens
```

O fluxo de trabalho (cards, branches, PRs, merge automático) está no
[CONTRIBUTING.md](CONTRIBUTING.md).

## Monitoramento

- **Uptime** (`.github/workflows/uptime.yml`): a cada 4 horas e depois de cada deploy de
  produção, confere com `curl` a página, uma conta conhecida em `/api/calcular`, os erros
  esperados das duas funções e os cabeçalhos de segurança. Problema abre uma issue com o
  rótulo `uptime`; deploy de produção com falha abre uma com o rótulo `deploy`. As duas
  fecham sozinhas quando tudo volta.
- **Resumo semanal** no Slack (`#simples`), toda segunda de manhã.
- Diagrama da arquitetura no [FigJam](https://www.figma.com/board/ENcSh8yoOVszzoQbkFY3jA)
  ("Calculadora do Simples Nacional: arquitetura (out/2026)").

## Planos gratuitos

- **GitHub Actions:** repositório público, minutos sem limite. Todo job tem tempo máximo. As
  imagens dos testes visuais só são geradas quando alguém pede (`visual-update.yml`).
- **Vercel Hobby:** só a `main` publica (prévias desligadas) e só quando muda algo que vai
  para o ar (`scripts/vercel-ignorar-build.sh`), porque o espaço de deploys é um só para a
  conta toda.
- **Jira Free:** sem regras de automação; os cards andam pelo `jira.yml`.
- **BrasilAPI:** gratuita e sem chave; as respostas de CNPJ ficam um dia no cache da Vercel.

## Autor

[Pedro Pedrassolli](https://pedrassolli.vercel.app), dev full-stack Ruby on Rails. Usa a gem
[br_validators](https://rubygems.org/gems/br_validators), também dele, na consulta opcional
de CNPJ.

Licença MIT.
