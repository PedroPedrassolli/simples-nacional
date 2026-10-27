# frozen_string_literal: true

require "test_helper"

describe SimplesNacional::Formato do
  subject { SimplesNacional::Formato }

  describe ".reais" do
    it "separa os milhares com ponto e os centavos com vírgula" do
      assert_equal "R$ 1.234.567,89", subject.reais(123_456_789)
    end

    it "mostra valores menores que um real" do
      assert_equal "R$ 0,05", subject.reais(5)
    end

    it "mostra zero" do
      assert_equal "R$ 0,00", subject.reais(0)
    end
  end

  describe ".percentual" do
    it "mostra a fração como percentual com duas casas" do
      assert_equal "7,30%", subject.percentual(Rational(73, 1000))
    end

    it "mostra quatro casas quando pedido" do
      assert_equal "9,9720%", subject.percentual(Rational(9972, 100_000), 4)
    end

    it "corta as casas a mais em vez de arredondar" do
      assert_equal "27,99%", subject.percentual(Rational(27_999, 100_000))
    end
  end
end
