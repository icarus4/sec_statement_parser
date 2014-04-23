# statement_fields.rb

module SecStatementParser

  module SecStatementFields

    @@fields = {
      fiscal_year:                { keywords: ['dei:DocumentFiscalYearFocus'] },   # This should be parsed first
      fiscal_period:              { keywords: ['dei:DocumentFiscalPeriodFocus'] }, # FY/Q1/Q2/Q3/Q4
      # amendment_flag:             { keywords: ['dei:AmendmentFlag'] },             # usually be false, need to check when to be true
      #trading_symbol:             { keywords: ['dei:TradingSymbol'] },
      registrant_name:            { keywords: ['dei:EntityRegistrantName'] },
      document_type:              { keywords: ['dei:DocumentType'] },
      period_end_date:            { keywords: ['dei:DocumentPeriodEndDate'] },
      cik:                        { keywords: ['dei:EntityCentralIndexKey'] },

      revenue:                    { keywords: ['us-gaap:Revenues',
                                               'us-gaap:SalesRevenueNet',
                                               'us-gaap:SalesRevenueServicesNet'] },
      #cost_of_revenue:          { keywords: ['us-gaap:CostOfRevenue'] },
      #operating_income:           { keywords: ['us-gaap:OperatingIncomeLoss'] }, # operating profit
      net_income:                 { keywords: ['us-gaap:NetIncomeLoss'] },
      eps_basic:                  { keywords: ['us-gaap:EarningsPerShareBasic'] },
      eps_diluted:                { keywords: ['us-gaap:EarningsPerShareDiluted'] }
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
      # patterns is a hash like: { keywords: ['dei:DocumentFiscalYearFocus'] }
      keywords = _get_keywords(patterns)
      result = _search_by_keywords(xml, statement, keywords)

      return result
    end # def self._parse_field(xml, patterns, fiscal_year)

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
            period = "#{fiscal_period}YTD"
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
            exit
          end
        end # if nodes.length > 1
      end # keywords.each do |keyword|

      # Check results
      case result.length
      when 0
        puts "0 result found by #{keywords}, please check.".red
        exit
      when 1
        return result[0].chomp
      else
        puts "#{result.length} results found by #{keywords}, please check".yellow
        sleep 1
        return result[0].chomp
      end
    end


    def self._get_keywords(patterns)
      patterns.each do |k, v|
        return v if k == :keywords
      end
      return nil
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
