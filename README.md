# Calculadora do Simples Nacional

Estimativa educativa da alíquota efetiva e do DAS do Simples Nacional, com a conta
explicada passo a passo. Regra de negócio confusa em código claro.

**No ar:** [simples-nacional-br.vercel.app](https://simples-nacional-br.vercel.app)

## O que a calculadora faz

A pessoa informa a receita bruta dos últimos 12 meses (RBT12), a receita do mês e o
anexo da atividade, e vê:

- a **alíquota efetiva**: `(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12`
  (art. 18, § 1º-A, da Lei Complementar 123/2006);
- o **valor estimado do DAS**: receita do mês × alíquota efetiva;
- a conta **passo a passo**, com a faixa usada e de onde veio cada número.

Quando a atividade pode cair no Anexo III ou no V, a calculadora aplica o **Fator R**:
folha de salários dos últimos 12 meses ÷ RBT12. Com 28% ou mais, a atividade vai para o
Anexo III; abaixo disso, para o V (art. 18, §§ 5º-J, 5º-K e 5º-M).

Opcional: informe um CNPJ para ver a empresa, o CNAE principal e se ela consta como optante
pelo Simples (dados públicos da Receita Federal, pela BrasilAPI).

As tabelas dos Anexos I a V ficam em `data/anexos/`, cada arquivo com o link da fonte
oficial, a lei que deu a redação atual e a data de vigência. Um teste falha se um
arquivo não tiver a fonte ou a vigência.

### O que ela não faz

- Não substitui o PGDAS-D nem um contador: é uma estimativa para entender a conta.
- **IBS e CBS:** a partir de janeiro de 2027, a empresa do Simples pode optar por
  recolher o IBS e a CBS pelo regime regular, fora do DAS (Lei Complementar 214/2025,
  regulamentada pela Resolução CGSN nº 186/2026; os prazos da opção foram alterados
  pela Resolução CGSN nº 194/2026). A calculadora mostra o DAS do regime simplificado
  e não calcula o IBS e a CBS por fora.
- Ainda não trata: repartição do DAS por tributo, empresa com menos de 12 meses
  (RBT12 proporcional), sublimites estaduais e comparação entre anexos.

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

resultado = SimplesNacional.calcular(rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3)
resultado.das                # => 398880 (R$ 3.988,80)
resultado.passos.map(&:texto) # a conta explicada, com a base legal de cada passo

# Atividade do Anexo III ou V: o Fator R escolhe (folha de salários dos 12 meses anteriores)
SimplesNacional.calcular(rbt12: 50_000_000, receita_mes: 4_000_000, anexo: :fator_r, folha12: 15_000_000)
```

### A API

```
GET /api/calcular?rbt12=500000.00&receita_mes=40000.00&anexo=3
GET /api/calcular?rbt12=500000.00&receita_mes=40000.00&anexo=fator_r&folha12=150000.00
```

Valores em reais, com ponto e até duas casas. A resposta traz `anexo`, `faixa`, `fator_r`,
`aliquota_nominal`, `aliquota_efetiva`, `das` (já formatados), `das_centavos`, os `passos`
e a `tabela` usada (fonte, redação e vigência). Entrada inválida responde 400 com `erro`.

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
  limites (art. 3º), alíquota efetiva e Fator R (art. 18) e Anexos I a V (redação da
  Lei Complementar nº 155/2016, vigência desde 01/01/2018). Conferido em 27/10/2026.
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
npm test                     # funções do formulário
npm run build && npm run test:e2e   # navegador: acessibilidade, 320 px, API simulada
```

O fluxo de trabalho (cards, branches, PRs, merge automático) está no
[CONTRIBUTING.md](CONTRIBUTING.md).

## Planos gratuitos

- **GitHub Actions:** repositório público, minutos sem limite. Todo job tem tempo máximo.
- **Vercel Hobby:** só a `main` publica (prévias desligadas) e só quando muda algo que vai
  para o ar (`scripts/vercel-ignorar-build.sh`), porque o espaço de deploys é um só para a
  conta toda.
- **Jira Free:** sem regras de automação; os cards andam pelo `jira.yml`.

## Autor

[Pedro Pedrassolli](https://pedrassolli.vercel.app), dev full-stack Ruby on Rails. Usa a gem
[br_validators](https://rubygems.org/gems/br_validators), também dele, na consulta opcional
de CNPJ.

Licença MIT.
