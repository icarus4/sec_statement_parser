# statement_url_list_spec.rb

require 'spec_helper'

describe SecStatementParser::StatementUrlList do

  describe '.get' do

    context 'when input symbol is valid' do
      pending
    end
    context 'when input symbol is invalid' do
      subject { SecStatementParser::StatementUrlList.get('invalid symbol') }
      it { should be_nil }
    end
  end

  describe '._get_list' do

    context 'when input symbol is invalid' do
      subject { SecStatementParser::StatementUrlList._get_list('invalid symbol', '10-K') }
      it { should be_nil }
    end
    context 'when input type is not 10-K' do
      subject { SecStatementParser::StatementUrlList._get_list('fb', 'invalid type') }
      it { should be_nil }
    end
    context 'when input valid symbol and type' do
      subject { SecStatementParser::StatementUrlList._get_list('fb', '10-K') }
      it { should be_kind_of(Array) }
    end
  end

  describe '._get_xbrl_url_from_filing_detail_page' do
    let(:filing_detail_url) { 'http://www.sec.gov/Archives/edgar/data/1326801/000132680114000007/0001326801-14-000007-index.htm' }
    let(:statement_url) { 'http://www.sec.gov/Archives/edgar/data/1326801/000132680114000007/fb-20131231.xml' }

    context 'when input valid URL of filing detail page' do
      subject { SecStatementParser::StatementUrlList._get_xbrl_url_from_filing_detail_page(filing_detail_url) }
      it { should eq statement_url }
    end
    context 'when input invalid URL' do
      subject { SecStatementParser::StatementUrlList._get_xbrl_url_from_filing_detail_page('http://oops.com') }
      it { should be_nil }
    end
  end
end
