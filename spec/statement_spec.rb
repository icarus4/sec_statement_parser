# statement_spec.rb

require 'spec_helper'

describe SecStatementParser::Statement do

  describe '.initialize' do
    subject { stock }

    context 'with invalid stock symbol' do
      pending
    end

    context 'with valid stock symbol' do
      let(:stock) { SecStatementParser::Statement.new 'goog' }
      its(:symbol) { should match 'GOOG' }
    end
  end
end
