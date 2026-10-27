# frozen_string_literal: true

require "test_helper"

describe SimplesNacional do
  subject { SimplesNacional }

  it "carrega a biblioteca sem dependências" do
    assert_kind_of Module, subject
  end
end
