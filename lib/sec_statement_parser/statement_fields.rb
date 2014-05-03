# statement_fields.rb

module SecStatementParser

  module SecStatementFields

    @@fields = {
      document_type:              { keywords: ['dei:DocumentType'], mode: :single, should_presence: true },
      fiscal_year:                { keywords: ['dei:DocumentFiscalYearFocus'], mode: :single, should_presence: true },   # This should be parsed first
      fiscal_period:              { keywords: ['dei:DocumentFiscalPeriodFocus'], mode: :single, should_presence: true }, # FY/Q1/Q2/Q3/Q4
      amendment_flag:             { keywords: ['dei:AmendmentFlag'], mode: :single, should_presence: true },             # usually be false, need to check when to be true
      registrant_name:            { keywords: ['dei:EntityRegistrantName'], mode: :single, should_presence: true },
      period_end_date:            { keywords: ['dei:DocumentPeriodEndDate'], mode: :single, should_presence: true },
      cik:                        { keywords: ['dei:EntityCentralIndexKey'], mode: :single, should_presence: true },
      trading_symbol:             { keywords: ['dei:TradingSymbol'], mode: :single, should_presence: false }

      # revenue:                    { keywords: ['us-gaap:Revenues',
      #                                          'us-gaap:SalesRevenueNet',
      #                                          'us-gaap:SalesRevenueServicesNet'] },
      # #cost_of_revenue:          { keywords: ['us-gaap:CostOfRevenue'] },
      # #operating_income:           { keywords: ['us-gaap:OperatingIncomeLoss'] }, # operating profit
      # net_income:                 { keywords: ['us-gaap:NetIncomeLoss'] },
      # eps_basic:                  { keywords: ['us-gaap:EarningsPerShareBasic'] },
      # eps_diluted:                { keywords: ['us-gaap:EarningsPerShareDiluted'] }
    }

    def self.parse(input)
      statement = {}

      xml = _open_xml(input); return nil if xml.nil?

      @@fields.each do |field, patterns|
        statement[field.to_sym] = _parse_field(xml, statement, patterns)
      end

      return statement
    end


    private

    def self._parse_field(xml, statement, patterns)
      # patterns is a hash like: { keywords: ['dei:DocumentFiscalYearFocus'], mode: :single, should_presence: true }
      keywords        = patterns[:keywords]
      mode            = patterns[:mode]
      should_presence = patterns[:should_presence]
      result          = nil

      case mode
      when :single
        result = _search_single_quantity(xml, keywords, should_presence)
      else
        result = _search_by_keywords(xml, statement, keywords)
      end
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
          puts "0 result found, please check\nkeywords: #{keywords}".red
          Raise "0 result found, please check\nkeywords: #{keywords}"
        else
          puts "0 result found.\nkeywords: #{keywords}".yellow
          return nil
        end
      end

      # if multiple results found and they are identical, it should be valid.
      # result.uniq.length is check whether results are identical or not.
      if result.length > 1 && result.uniq.length > 1
        puts "#{result.length} results found, please check\nkeywords: #{keywords}\nresult: #{result}".red
        Raise "#{result.length} results found, please check\nkeywords: #{keywords}\nresult: #{result}"
      end

      return result[0].chomp
    end

    def self._search_by_keywords(xml, statement, keywords)
      result = []
      fiscal_year = statement[:fiscal_year]
      fiscal_period = statement[:fiscal_period]

      keywords.each do |keyword|
        if fiscal_year.nil?
          nodes = xml.xpath("//#{keyword}")
        else
          case fiscal_period
          when nil
            period = nil
          when 'FY'
            period = 'Q4YTD'
          else
            period = "#{fiscal_period}QTD"
          end
          nodes = xml.xpath("//#{keyword}[contains(@contextRef, '#{fiscal_year}#{period}')]")
        end

        # Failed case: cannot find any result by keyword
        # In this case, we try to use next keyword
        if nodes.length == 0
          next
        end

        # Success case: just find one result
        if nodes.length == 1
          result << nodes.text
          next
        end

        # Not sure case: find multiple results
        if nodes.length > 1
          matched_count_in_nodes = 0
          redo_for_class_search = false
          nodes.each_with_index do |node, index|
            # Filter out attribute value with '_' character
            if redo_for_class_search == false
              if !node.attr('contextRef').include? '_'
                matched_count_in_nodes += 1
                result << node.text
              end
            else # Redo if cannot find any matched result
              if node.attr('contextRef').include? 'CommonClassAMember'
                matched_count_in_nodes += 1
                result << node.text
              end
            end

            # Redo if cannot find any matched result
            if index == nodes.length - 1 && matched_count_in_nodes == 0 && redo_for_class_search == false
              redo_for_class_search = true
              redo
            end
          end

          case matched_count_in_nodes
          when 0
            puts "#{matched_count_in_nodes} matched result by using #{keywords}".yellow
            next
          when 1
            next
          else
            puts "#{matched_count_in_nodes} matched results by using #{keywords}, please check. Exit.".red
            Raise "#{matched_count_in_nodes} matched results by using #{keywords}, please check. Exit."
          end
        end # if nodes.length > 1
      end # keywords.each do |keyword|

      # Check results
      case result.length
      when 0
        puts "0 result found by #{keywords}, please check.".red
        Raise "0 result found by #{keywords}, please check."
      when 1
        return result[0].chomp
      else
        if result.uniq.length == 1
          return result[0].chomp
        else
          puts "#{result.length} results found by #{keywords}, please check".red
          Raise "#{result.length} results found by #{keywords}, please check"
        end
      end
    end

    def self._remove_node_if_attr_contains(nodes, target_attr, str)
      _nodes = nodes.dup # FIXME: Here we have to use nodes.dup. But....why nodes.clone does not work???
      _nodes.each do |node|
        nodes.delete(node) if node.attr(target_attr).include? str
      end
      return nodes
    end


    # Return Nokogiri::XML
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
