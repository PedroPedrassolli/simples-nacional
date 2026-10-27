# frozen_string_literal: true

source "https://rubygems.org"

# A Vercel lê a versão do Ruby daqui (a função da API roda no Ruby 3.3).
# A CI lê o .ruby-version e confere que os dois batem (.github/workflows/ci.yml).
ruby "~> 3.3.0"

# A biblioteca (lib/) não tem dependências: usa só a biblioteca padrão do Ruby.
# A consulta opcional de CNPJ (api/cnpj.rb) usa a gem br_validators: valida o CNPJ e
# consulta a BrasilAPI. A 0.2.1 é a primeira com a Consulta completa.
gem "br_validators", "~> 0.2", ">= 0.2.1"

# Estas gems são só para desenvolvimento e testes. A Vercel não instala nenhuma
# delas, porque o projeto tem BUNDLE_WITHOUT=development:test nas variáveis.
group :development, :test do
  gem "minitest"
  gem "rake"
  gem "rubocop", require: false
  gem "simplecov", require: false
end
