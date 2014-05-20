# statement_fields.rb

module SecStatementParser

  module SecStatementFields

    @@single_mapping_fields = {
      document_type:              { keywords: ['DocumentType'], should_presence: true },
      fiscal_year:                { keywords: ['DocumentFiscalYearFocus'], should_presence: true },   # This should be parsed first
      fiscal_period:              { keywords: ['DocumentFiscalPeriodFocus'], should_presence: true }, # FY/Q1/Q2/Q3/Q4
      amendment_flag:             { keywords: ['AmendmentFlag'], should_presence: true },             # usually be false, need to check when to be true
      registrant_name:            { keywords: ['EntityRegistrantName'], should_presence: true },
      period_end_date:            { keywords: ['DocumentPeriodEndDate'], should_presence: true },
      cik:                        { keywords: ['EntityCentralIndexKey'], should_presence: true },
      trading_symbol:             { keywords: ['TradingSymbol'], should_presence: false }
    }

    # FD2013Q4YTD / D2013Q3 / FD2013Q2QTD / ...
    REGEX_STR_TYPE1 = '^[FD]+[0-9]{4}Q[1-4][QYTD]{0,3}'

    @@multi_mapping_fields = {

      # 營收
      revenue:                    { keywords: ['Revenues',
                                               'SalesRevenueNet',
                                               'SalesRevenueServicesNet'],
                                    regex_str: REGEX_STR_TYPE1, should_presence: true },
      # 毛利
      gross_profit:               { keywords: ['GrossProfit'],
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # 營業利益
      operating_income:           { keywords: ['OperatingIncomeLoss',
                                               'OperatingExpenses'], # HD
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # 稅前淨利
      net_income_beforoe_tax:     { keywords: ['IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest',
                                               'IncomeLossFromContinuingOperationsBeforeIncomeTaxesMinorityInterestAndIncomeLossFromEquityMethodInvestments', # HD
                                               'IncomeLossFromContinuingOperationsBeforeIncomeTaxesAndMinorityInterest', # V
                                               'IncomeLossFromContinuingOperationsBeforeEquityMethodInvestmentsIncomeTaxesExtraordinaryItems'], # PCLN
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # 稅後淨利
      net_income_after_tax:       { keywords: ['NetIncomeLoss',
                                               'ProfitLoss'], # V
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # 營業成本 / 銷貨成本
      cost_of_revenue:            { keywords: ['CostOfRevenue',
                                               'CostOfGoodsSold', # NKE
                                               'CostOfGoodsAndServicesSold'], # PCLN
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # 總營業支出 (總營業支出 + 營業利益 = 營收) (operating_expense + operating_income = revenue)
      total_operating_expense:    { keywords: ['OperatingExpenses', # HD
                                               'CostsAndExpenses'],
                                    regex_str: REGEX_STR_TYPE1, should_presence: false },
      # EPS
      eps_basic:                  { keywords: ['EarningsPerShareBasic'],
                                    regex_str: REGEX_STR_TYPE1, should_presence: true },
      # EPS diluted
      eps_diluted:                { keywords: ['EarningsPerShareDiluted'],
                                    regex_str: REGEX_STR_TYPE1, should_presence: true }
    }

    def self.parse(input)
      statement = {}

      xml = _open_xml(input); return nil if xml.nil?

      # Remove all namespaces to simplify statement parsing
      xml.remove_namespaces!

      @@single_mapping_fields.each do |field, patterns|
        statement[field.to_sym] = _parse_field(xml, statement, patterns)
      end

      @@multi_mapping_fields.each do |field, patterns|
        result = _parse_multiple_mapping_field(xml, statement, field, patterns)
        if result.nil?
          puts "0 result found, keywords: #{field}".warning_color
          statement[field] = nil
          next
        end

        result.each do |k,v|
          statement[k] = v
        end
      end

      return statement
    end


    private

    def self._parse_field(xml, statement, patterns)
      # patterns is a hash like: { keywords: ['DocumentFiscalYearFocus'], mode: :single, should_presence: true }
      keywords        = patterns[:keywords]
      should_presence = patterns[:should_presence]
      result          = nil

      result = _search_single_quantity(xml, keywords, should_presence)

      return result
    end

    def self._search_single_quantity(xml, keywords, should_presence)
      result = []

      keywords.each do |keyword|
        nodes = xml.xpath("//#{keyword}")

        case nodes.length
        when 0
          next
        when 1
          result.concat nodes.text_to_array
          next
        else
          nodes = _remove_node_if_attr_contains(nodes, 'contextRef', '_')
          result.concat nodes.text_to_array
        end
      end

      if result.length == 0
        if should_presence
          puts "0 result found, please check. keywords: #{keywords}".error_color
          raise "0 result found, please check. keywords: #{keywords}"
        else
          puts "0 result found. keywords: #{keywords}".warning_color
          return nil
        end
      end

      # if multiple results found and they are identical, it should be valid.
      # result.uniq.length is check whether results are identical or not.
      if result.length > 1 && result.uniq.length > 1
        puts "#{result.length} results found, please check. keywords: #{keywords}\nresult: #{result}".error_color
        raise "#{result.length} results found, please check. keywords: #{keywords}\nresult: #{result}"
      end

      return result[0].chomp
    end

    def self._parse_multiple_mapping_field(xml, statement, field, patterns)
      result = {}
      should_presence = patterns[:should_presence]

      # For each keywords, search by contextRef with valid format.
      # Valid contextRef format are as follows:
      # FD2013Q1Y / D2013Q2QTD / D2013Q4YTD / ...
      using_regex_set = 1
      patterns[:keywords].each_with_index do |keyword, index|
        nodes = xml.xpath("//#{keyword}")
        next if nodes.nil?

        fiscal_year = statement[:fiscal_year]
        nodes.each do |node|

          contextRef = node.attr('contextRef')
          case using_regex_set
          # 1st regex set
          when 1
            case contextRef
            when /^[FD]+#{fiscal_year}Q1YTD$/ # ex: FD2013Q1YTD => xxx_q1
                eval "result[:#{field}_q1] = node.text.chomp"
            when /^[FD]+#{fiscal_year}Q[2-3]YTD$/ # ex: FD2013Q2YTD => xxx_q2ytd
                eval "result[:#{field}_q#{contextRef[-4]}ytd] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q4YTD$/ # ex: FD2013Q4YTD => xxx_fy
                eval "result[:#{field}_fy] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q[1-4]$/ # ex: FD2013Q1 => xxx_q1
                eval "result[:#{field}_q#{contextRef[-1]}] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q[1-4]QTD$/ # ex: FD2013Q2 => xxx_q2
                eval "result[:#{field}_q#{contextRef[-4]}] = node.text.chomp"
                end # case contextRef
            # 2nd regex set
          when 2
            case contextRef
            when /^[FD]+#{fiscal_year}Q1YTD_us-gaap_StatementClassOfStockAxis_us-gaap_CommonClassAMember$/ # ex: FD2013Q1YTD
                eval "result[:#{field}_q1] = node.text.chomp"
            when /^[FD]+#{fiscal_year}Q[2-3]YTD_us-gaap_StatementClassOfStockAxis_us-gaap_CommonClassAMember$/ # ex: FD2013Q1YTD
                eval "result[:#{field}_q#{contextRef[-4]}ytd] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q4YTD_us-gaap_StatementClassOfStockAxis_us-gaap_CommonClassAMember$/ # ex: FD2013Q4YTD
                eval "result[:#{field}_fy] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q[1-4]_us-gaap_StatementClassOfStockAxis_us-gaap_CommonClassAMember$/ # ex: FD2013Q1
                eval "result[:#{field}_q#{contextRef[-62]}] = node.text.chomp"
                when /^[FD]+#{fiscal_year}Q[1-4]QTD_us-gaap_StatementClassOfStockAxis_us-gaap_CommonClassAMember$/ # ex: FD2013Q2
                eval "result[:#{field}_q#{contextRef[-65]}] = node.text.chomp"
                end # case contextRef
          end
        end # nodes.each do |node|

        break if result.any?

        # Prepare to parse by next regex set
        if index == patterns[:keywords].length - 1 && using_regex_set < 2
          using_regex_set += 1
          redo
        end

      end # patterns[:keywords].each do |keyword, index|

      # Return if there is any result found
      if result.any?
        puts "Parse #{field} with CommonClassAMember. You'd better check value.".check_value_color if using_regex_set == 2
        return result
      else
        if should_presence
          puts "no result found, please check. field: #{field}".error_color
          raise "no result found, please check. field: #{field}"
        end
        return nil
      end
    end # self._parse_multiple_mapping_field(xml, statement, field, patterns)


    def self._remove_node_if_attr_contains(nodes, target_attr, str)
      nodes.dup.each do |node|
        nodes.delete(node) if node.attr(target_attr).include? str
      end
      return nodes
    end


    def self._remove_node_if_attr_not_match_regex(nodes, target_attr, regex_str)
      regex = Regexp.new regex_str

      nodes.dup.each do |node|
        nodes.delete(node) unless node.attr(target_attr) =~ regex
      end

      return nodes
    end

    # Return Nokogiri::XML object
    def self._open_xml(input)
      if input.is_a? String
        return _open_xml_link(input)
      elsif input.is_a? File
        return _open_xml_file(input)
      else
        $log.warn("Error input type")
        return nil
      end
    end

    def self._open_xml_link(link)
      unless link =~ /^#{URI::regexp}$/
        $log.error("Wrong uri format: #{link}")
        return nil
      end

      begin
        xml = Nokogiri::XML(open(link))
        return xml
      rescue
        $log.error("Cannot open link: #{link}")
        return nil
      end
    end

    def self._open_xml_file(file)
      begin
        xml = Nokogiri::XML(file)
        return xml
      rescue
        $log.error("Cannot open file")
        return nil
      end
    end
  end
end
