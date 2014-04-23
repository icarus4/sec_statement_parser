# statement_fields.rb

module SecStatementParser

  module SecStatementFields

    @@fields = {
      fiscal_year:                { keywords: ['dei:DocumentFiscalYearFocus'] },   # This should be parsed first
      period:                     { keywords: ['dei:DocumentFiscalPeriodFocus'] }, # FY/Q1/Q2/Q3/Q4
      #trading_symbol:             { keywords: ['dei:TradingSymbol'] },
      registrant_name:            { keywords: ['dei:EntityRegistrantName'] },
      document_type:              { keywords: ['dei:DocumentType'] },
      period_end_date:            { keywords: ['dei:DocumentPeriodEndDate'] },
      cik:                        { keywords: ['dei:EntityCentralIndexKey'] },
      amendment_flag:             { keywords: ['dei:AmendmentFlag'] },              # usually be false, need to check when to be true

      revenue:                    { keywords: ['us-gaap:Revenues',
                                               'us-gaap:SalesRevenueServicesNet'] },
      #cost_of_revenue:          { keywords: ['us-gaap:CostOfRevenue'] },
      operating_income:           { keywords: ['us-gaap:OperatingIncomeLoss'] }, # operating profit
      net_income:                 { keywords: ['us-gaap:NetIncomeLoss'] },
      eps_basic:                  { keywords: ['us-gaap:EarningsPerShareBasic'] },
      eps_diluted:                { keywords: ['us-gaap:EarningsPerShareDiluted'] }
    }

    def self.parse(input)
      statement = {}

      xml = _open_xml(input); return nil if xml.nil?

      @@fields.each do |field, patterns|
        puts "parsing #{field} by #{patterns}"
        statement[field.to_sym] = _parse_field(xml, patterns, statement[:fiscal_year])
      end

      return statement
    end


    private

    def self._parse_field(xml, patterns, fiscal_year)
      # patterns is a hash like: { keywords: ['dei:DocumentFiscalYearFocus'] }
      keywords = _get_keywords(patterns)
      result = _search_by_keywords_and_fiscal_year(xml, keywords, fiscal_year)

      return result
    end # def self._parse_field(xml, patterns, fiscal_year)

    def self._search_by_keywords_and_fiscal_year(xml, keywords, fiscal_year)
      result = nil
      matched_count_by_keywords = 0
      keywords.each do |keyword|
        if fiscal_year.nil?
          nodes = xml.xpath("//#{keyword}")
        else
          nodes = xml.xpath("//#{keyword}[contains(@contextRef, '#{fiscal_year}')]")
        end

        # Failed case: cannot find any result by keyword
        # In this case, we try to use next keyword
        if nodes.length == 0
          puts "Cannot find by #{keyword}".yellow
          next
        end

        # Success case: just find one result
        if nodes.length == 1
          result = nodes.text
          matched_count_by_keywords += 1
          next
        end

        # Not sure case: find multiple results
        if nodes.length > 1
          matched_count_in_nodes = 0
          nodes.each do |node|
            # Filter out attribute value with '_' character
            if !node.attr('contextRef').include? '_'
              matched_count_in_nodes += 1
              matched_count_by_keywords +=1
              result = node.text
            end
          end

          case matched_count_in_nodes
          when 0
            puts "No matched result by using #{keyword}".yellow
            next
          when 1
            next
          else
            puts "Match multiple result by using #{keyword}, please check. Exit.".red
            exit
          end
        end # if nodes.length > 1
      end # keywords.each do |keyword|

      if matched_count_by_keywords == 1
        return result
      else
        puts "Found #{matched_count_by_keywords} results by #{keywords}, please check".red
        exit
      end
    end


    def self._get_keywords(patterns)
      patterns.each do |k, v|
        return v if k == :keywords
      end
      return nil
    end

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
        raise ParseError, "keyword=\"#{keyword}\" match_count=#{match_count}" if match_count != 1
      end

      return parse_result
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
