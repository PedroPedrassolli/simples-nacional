# Calculadora do Simples Nacional

Estimativa educativa da alíquota efetiva e do DAS do Simples Nacional, com a conta
explicada passo a passo. Regra de negócio confusa em código claro.

**No ar:** [simples-nacional-br.vercel.app](https://simples-nacional-br.vercel.app)

## O que a calculadora faz

A pessoa informa o mês de apuração (por enquanto, meses de 2026), a receita bruta dos
últimos 12 meses (RBT12), a receita do mês e o anexo da atividade, e vê:

- a **alíquota efetiva**: `(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12`
  (art. 18, § 1º-A, da Lei Complementar 123/2006);
- o **valor estimado do DAS**: receita do mês × alíquota efetiva;
- a **divisão do DAS entre os tributos** (IRPJ, CSLL, Cofins, PIS/Pasep, CPP, IPI, ICMS ou
  ISS), pelos percentuais de repartição de cada anexo, com o ISS limitado a 5% e, na 6ª faixa,
  o ICMS ou o ISS calculado com a 5ª faixa (Resolução CGSN nº 140/2018, art. 21, III);
- a conta **passo a passo**, com a faixa usada e de onde veio cada número.

**Empresa com menos de 12 meses de atividade:** informe o mês de início. No 1º mês, a RBT12
é a receita do mês × 12; até completar 12 meses, é a média dos meses anteriores × 12 (LC
123/2006, art. 18, § 2º; Resolução CGSN nº 140/2018, art. 22, §§ 2º a 4º). A folha do Fator R
segue a mesma regra (art. 26, § 4º). RBT12 zero vale R$ 1,00 só para achar a alíquota
(art. 21, parágrafo único), e RBT12 acima de R$ 4,8 milhões usa a última faixa (art. 22, § 5º).

**Sublimite do ICMS e do ISS:** em 2025 e 2026 é R$ 3.600.000,00 em todos os estados e no DF
(Portarias CGSN nº 49/2024 e nº 54/2025), por isso a calculadora não pergunta a UF. Com a receita
do ano até o mês anterior e a do ano passado, ela aplica as regras da LC 123/2006 (arts. 13-A,
19 e 20) e da Resolução CGSN nº 140/2018 (arts. 12 e 24): na 6ª faixa o ICMS ou o ISS vem da 5ª;
a parte da receita acima do sublimite usa a alíquota da 5ª faixa no valor do sublimite; com
excesso de mais de 20%, ou se a receita do ano passado já passou, o ICMS/ISS sai do DAS (a
calculadora avisa e não estima esse valor). No ano de início, o sublimite é proporcional
(R$ 300.000,00 por mês). Receita do ano acima de R$ 4.800.000,00 tira a empresa do Simples: a
calculadora explica e não calcula.

Quando a atividade pode cair no Anexo III ou no V, a calculadora aplica o **Fator R**:
folha de salários dos últimos 12 meses ÷ RBT12. Com 28% ou mais, a atividade vai para o
Anexo III; abaixo disso, para o V (art. 18, §§ 5º-J, 5º-K e 5º-M).

Opcional: informe um CNPJ para ver a empresa, o CNAE principal e se ela consta como optante
pelo Simples (dados públicos da Receita Federal, pela BrasilAPI).

**Na página:** o formulário vem em três etapas (mês e empresa, receitas, atividade). Cada anexo
mostra exemplos de atividades do art. 18 da LC 123/2006, os valores ficam no formato brasileiro
ao sair do campo e os campos do sublimite abrem sozinhos quando a receita pode passar dele.
"Usar um exemplo" preenche números fictícios. No computador, o resultado fica ao lado do
formulário, com o DAS em destaque e a parte de cada tributo; se um campo muda depois do
cálculo, a página avisa que o resultado ficou desatualizado.

As tabelas dos Anexos I a V ficam em `data/anexos/`, cada arquivo com o link da fonte
oficial, a lei que deu a redação atual e a data de vigência, as alíquotas e os percentuais de
repartição de cada faixa. Um teste falha se um arquivo não tiver a fonte ou a vigência, ou se a
repartição de uma faixa não somar 100%.

### O que ela não faz

- Não substitui o PGDAS-D nem um contador: é uma estimativa para entender a conta.
- **IBS e CBS:** a partir de janeiro de 2027, a empresa do Simples pode optar por
  recolher o IBS e a CBS pelo regime regular, fora do DAS (Lei Complementar 214/2025,
  regulamentada pela Resolução CGSN nº 186/2026; os prazos da opção foram alterados
  pela Resolução CGSN nº 194/2026). A calculadora mostra o DAS do regime simplificado
  e não calcula o IBS e a CBS por fora.
- **Só 2026:** a partir de 1º/1/2027 os Anexos I a V passam a ter a redação da LC 214/2025
  (art. 519), com a CBS e o IBS na divisão do DAS. A calculadora recusa meses de 2027 até ter
  essas tabelas.
- Ainda não trata: empresa que passou de R$ 4,8 milhões no ano (a parte acima do limite tem
  outra conta até a exclusão), receitas de mais de um anexo no mesmo mês, locação de bens
  móveis (Anexo III sem o ISS) e comparação entre anexos.

## Como funciona

```
lib/simples_nacional/   Ruby puro, sem dependências: tabelas, faixa, alíquota efetiva, Fator R, DAS
data/anexos/*.yml       tabelas dos Anexos I a V, com fonte oficial e vigência
api/calcular.rb         função Ruby da Vercel: recebe os números e devolve o resultado e os passos (JSON)
api/cnpj.rb             consulta opcional de CNPJ pela gem br_validators (BrasilAPI)
web/                    React + Vite, build estático e pré-renderizado (formulário, resultado, passo a passo)
test/                   Minitest, com 100% das linhas cobertas
```

- A regra fica num lugar só, em Ruby testável. A página só mostra o que a API devolve.
- A função da Vercel guarda só o código (sem imagem de container), e a resposta tem
  cache de CDN: o resultado depende só dos números enviados.
- A página é estática e roda com uma Content Security Policy sem `unsafe-inline`.

### A biblioteca

Dinheiro em centavos (Integer), para nenhuma conta passar por Float:

```ruby
require "simples_nacional"

resultado = SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3)
resultado.das                # => 398880 (R$ 3.988,80)
resultado.tributos.last      # => #<data SimplesNacional::Calculo::Tributo nome="ISS", percentual=(32409/1000000), valor=129636>
resultado.passos.map(&:texto) # a conta explicada, com a base legal de cada passo

# Atividade do Anexo III ou V: o Fator R escolhe (folha de salários dos 12 meses anteriores)
SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: :fator_r,
                         folha12: 15_000_000)

# Empresa que começou em novembro de 2025: rbt12 é a receita desde o início (4 meses)
SimplesNacional.calcular(periodo: "2026-03", inicio: "2025-11", rbt12: 10_000_000, receita_mes: 3_000_000, anexo: 1)
```

### A API

```
GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=3
GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=fator_r&folha12=150000.00
GET /api/calcular?periodo=2026-03&inicio=2025-11&rbt12=100000.00&receita_mes=30000.00&anexo=1
GET /api/calcular?periodo=2026-10&rbt12=3900000.00&receita_mes=400000.00&anexo=1&receita_ano=3300000.00&receita_ano_anterior=3500000.00
```

Valores em reais, com ponto e até duas casas; meses como `AAAA-MM`. Com `inicio`, `rbt12` é a
receita desde o início das atividades (no 1º mês, não vai). `receita_ano` (receita do ano até
o mês anterior) e `receita_ano_anterior` são opcionais: a API pede a primeira quando a RBT12
mais a receita do mês passa do sublimite. A resposta traz `periodo`,
`periodo_nome`, `rbt12` (a usada na conta), `anexo`, `faixa`, `fator_r`,
`aliquota_nominal`, `aliquota_efetiva`, `das` (já formatados), `das_centavos`, os `tributos`
(nome, percentual sobre a receita e valor de cada um), os `passos` e a `tabela` usada (fonte,
redação e vigência) e `aviso` (texto quando o ICMS/ISS sai do DAS ou muda de regra, senão
`null`). Entrada inválida responde 400 com `erro`.

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
  novos Anexos I a V a partir de 1º/1/2027 (art. 519; art. 544, III). Conferido em 27/10/2026.
- [Portal do Simples Nacional: opção pelo regime regular do IBS e da CBS para 2027](https://www8.receita.fazenda.gov.br/simplesnacional/noticias/NoticiaCompleta.aspx?id=c739e03c-8482-473f-8e82-f38ec3b13637).

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
npm run build && npm run test:e2e   # navegador: acessibilidade, 320 px, API simulada
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

- **GitHub Actions:** repositório público, minutos sem limite. Todo job tem tempo máximo.
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
