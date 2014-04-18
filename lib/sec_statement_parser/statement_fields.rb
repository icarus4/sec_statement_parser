# statement_fields.rb

module SecStatementParser

  module SecStatementFields

    @@fields = {
      fields_parsed_by_xpath: {
        trading_symbol:             '//dei:TradingSymbol',
        fiscal_year:                '//dei:DocumentFiscalYearFocus',
        period:                     '//dei:DocumentFiscalPeriodFocus', # FY/Q1/Q2/Q3/Q4
        period_end_date:            '//dei:DocumentPeriodEndDate',
        cik:                        '//dei:EntityCentralIndexKey',
        amendment_flag:             '//dei:AmendmentFlag'              # usually be false, need to check when to be true
      },

      fields_parsed_by_parse_method_1: {
        revenue:            'us-gaap:Revenues',
        #cost_of_revenue:    'us-gaap:CostOfRevenue',
        operating_income:   'us-gaap:OperatingIncomeLoss', # operating profit
        net_income:         'us-gaap:NetIncomeLoss',
        eps_basic:          'us-gaap:EarningsPerShareBasic',
        eps_diluted:        'us-gaap:EarningsPerShareDiluted'
      }
    }

    def self.parse(xml)
      result = {}

      @@fields[:fields_parsed_by_xpath].each do |field, xpath|
        raise RuntimeError.new('Error xpath syntax') if !xpath.is_a? String
        result[field] = xml.xpath(xpath).text
      end

      @@fields[:fields_parsed_by_parse_method_1].each do |field, keyword|
        result[field] = _parse_method_1(xml, result, keyword)
      end

      return result
    end


    private

    def self._parse_method_1(xml, result, keyword)
      year = result[:fiscal_year]
      parse_result = 0
      match_count = 0

      node_set = xml.xpath("//#{keyword}[contains(@contextRef, '#{year}Q4YTD')]")

      node_set.each do |node|
        if !node.attribute('contextRef').value.include? '_'
          if node.text.include? '.'
            parse_result = node.text.to_f
          else
            parse_result = node.text.to_i
          end
          match_count += 1
        end
        raise ParseError.new("keyword=\"#{keyword}\" match_count=#{match_count}") if match_count != 1
      end

      return parse_result
    end
  end
end