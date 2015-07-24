# encoding: utf-8
require 'spec_helper'
require 'electric_slide/agent'

describe ElectricSlide::Agent do
  let(:options) { { id: 1, address: '123@foo.com', presence: :available} }

  class MyAgent < ElectricSlide::Agent
    on_connect do
      foo
    end

    def foo
      :bar
    end
  end

  subject {MyAgent.new options}

  it 'executes a connect callback' do
    expect(subject.callback(:connect)).to eql :bar
  end
end
