# statement_parser.rb

module SecStatementParser

  class StatementParser

    def initialize(debug=false)
      @debug = !!debug
    end

    def parse(input)
      tmp = open_xml(input)
      @xml = tmp[:xml]
      @statement_link = tmp[:url]
      return parse_statement
    end

    private

    MAX_DAYS_IN_A_YEAR = 370
    MIN_DAYS_IN_A_YEAR = 360
    MAX_DAYS_IN_A_QUARTER = 101 # should be 93, but set to 101 for goog-20120930.xml
    MIN_DAYS_IN_A_QUARTER = 88

    def parse_statement
      @xml.remove_namespaces!
      @results = {}
      init_results_hash
      parse_statement_basic_info
      context_refs_hash = parse_context_refs(@results[:fiscal_period_end_date])
      parse_statement_fields(context_refs_hash)
      return @results
    end

    def init_results_hash
      @results[:parse_info_for_debug] = {}
      @results[:parse_info_for_debug][:fields_by_guess] = []
      @results[:parse_info_for_debug][:fields_with_multi_results] = []
      @results[:parse_info_for_debug][:fields_with_zero_result] = []
      @results[:parse_info_for_debug][:should_check] = false
    end

    def add_to_guess_fields(symbol)
      @results[:parse_info_for_debug][:fields_by_guess] << symbol
    end

    def add_to_multi_results_fields(symbol)
      @results[:parse_info_for_debug][:fields_with_multi_results] << symbol
    end

    def add_to_zero_result_fields(symbol)
      @results[:parse_info_for_debug][:fields_with_zero_result] << symbol
    end

    def parse_statement_fields(context_refs_hash)
      # for each field
      SecStatementFields::STATEMENT_FIELDS.each do |field, rules|

        match_count_for_current_context_ref_set = 0

        # for each contextRef
        context_refs_hash.each do |context_ref_string, dates|

          match_count_for_current_keyword_set = 0
          found_values = []

          # for each keyword
          rules[:keywords].each do |keyword|

            # skip if period is not a quarter or not a full year
            next if !dates[:period].between?(MIN_DAYS_IN_A_QUARTER, MAX_DAYS_IN_A_QUARTER) && !dates[:period].between?(MIN_DAYS_IN_A_YEAR, MAX_DAYS_IN_A_YEAR)

            # search
            node = @xml.xpath("//#{keyword}[@contextRef='#{context_ref_string}']")
            # skip if no result found
            next if node.empty?
            # one keyword should find only one result
            raise ParseError, "Find #{node.length} results by \"#{keyword}\", expect 1 result" if node.length > 1

            found_values << node.first.text.to_f_or_i
            match_count_for_current_keyword_set += 1
            match_count_for_current_context_ref_set += 1
          end # rules[:keywords].each do |keyword|

          if match_count_for_current_keyword_set == 0
            puts "No result found for #{field}, please check".check_value_color
            puts "#{context_refs_hash}".check_value_color
            puts "context_ref_string:#{context_ref_string}".check_value_color
            puts ""
            next
          end

          if match_count_for_current_keyword_set > 1
            puts "Find #{match_count_for_current_keyword_set} results for #{field}, please check".check_value_color
            add_to_multi_results_fields(field)
          end

          fill_value_to_results(dates[:period], field, found_values.first)

        end # context_refs.each do |context_ref_string, dates|

        if match_count_for_current_context_ref_set == 0
          add_to_zero_result_fields(field)
          if rules[:should_presence]
            raise ParseError, "No result found for #{field} with contextRef set: #{context_refs_hash}"
          else
            @results[field] = nil
          end
        end
      end # SecStatementFields::STATEMENT_FIELDS.each do |field, rules|
    end # def parse_statement_fields(context_refs_hash)

    def fill_value_to_results(days, field, value)
      @results[:last_3month_data]  = {} unless @results.has_key?(:last_3month_data)
      @results[:last_12month_data] = {} unless @results.has_key?(:last_12month_data)

      case days
      when MIN_DAYS_IN_A_QUARTER..MAX_DAYS_IN_A_QUARTER
        period = :last_3month_data
      when MIN_DAYS_IN_A_YEAR..MAX_DAYS_IN_A_YEAR
        period = :last_12month_data
      else
        raise ParseError, "Error period"
      end

      @results[period][field] = value
    end

    def parse_context_refs(end_date)
      context_refs = {}

      nodes = @xml.xpath('//context')
      nodes.remove_subnode_if_contains_element!('segment')
      nodes.remove_subnode_if_not_contains_element!('startDate')
      nodes.remove_subnode_if_not_contains_element!('endDate')

      nodes.each do |node|
        hash = {}
        context_id = node.xpath('.//@id').first.value
        _start_date = node.xpath('.//startDate').text
        _end_date = node.xpath('.//endDate').text
        _period = (Date.parse(_end_date) - Date.parse(_start_date) + 1).to_i

        # Parse end date equals DocumentPeriodEndDate only
        next if _end_date != end_date

        # Skip period is not a full year or not a quarter
        next if !_period.between?(MIN_DAYS_IN_A_YEAR, MAX_DAYS_IN_A_YEAR) && !_period.between?(MIN_DAYS_IN_A_QUARTER, MAX_DAYS_IN_A_QUARTER)

        hash[:start_date] = _start_date
        hash[:end_date] = _end_date
        hash[:period] = _period

        context_refs[context_id] = hash
      end

      if context_refs.length == 0
        ap nodes
        raise ParseError, "Cannot find context refs"
      end

      return context_refs
    end

    def parse_statement_basic_info
      SecStatementFields::STATEMENT_BASIC_INFO_FIELDS.each do |field, rule|
        @results[field] = get_one_text_by_element(rule[:keywords][0])
        raise_error_if_nil_and_should_presence(rule[:should_presence], @results[field], field)
      end

      @results[:statement_link] = @statement_link

      fill_in_nil_fields_by_guess
    end

    # Guess nil fields by known fields
    def fill_in_nil_fields_by_guess
      # Fiscal year
      # FIXME: year of fiscal_period_end_date may not be exactly the same with :year
      if @results[:year].nil?
        @results[:year] = Date.parse(@results[:fiscal_period_end_date]).year.to_s
        add_to_guess_fields(:year)
      end

      # Fiscal period
      if @results[:fiscal_period].nil?
        if @results[:document_type] == '10-K'
          @results[:fiscal_period] = 'FY'
        elsif @results[:document_type] == '10-Q'

          date = Date.parse(@results[:fiscal_period_end_date])

          if date.month == 3 && date.day == 31
            @results[:fiscal_period] = 'Q1'
          elsif date.month == 6 && date.day == 30
            @results[:fiscal_period] = 'Q2'
          elsif date.month == 9 && date.day == 30
            @results[:fiscal_period] = 'Q3'
          elsif date.month == 12 && date.day == 31
            @results[:fiscal_period] = 'Q4'
          else
            # TODO...
          end
        else
          raise ParseError, "Wrong document type: #{@results[:document_type]}"
        end
        add_to_guess_fields(:fiscal_period)
      end
    end

    def get_one_text_by_element(keyword)
      node = @xml.xpath("//#{keyword}")

      case node.length
      when 0
        puts "No result found by keyword \"#{keyword}\"".check_value_color
        return nil
      when 1
        return node.text
      else
        raise ParseError "This keyword (#{keyword}) should NOT has multiple results" if node.length > 1
      end
    end

    def raise_error_if_nil_and_should_presence(should_presence, value, field)
      if should_presence && value.nil?
        raise ParseError, "#{field} should presence"
      end
    end

    # Return Nokogiri::XML object
    def open_xml(input)
      if input.is_a? String
        puts "opening #{input}"
        xml = open_xml_link(input)
        url = input
      elsif input.is_a? File
        xml = open_xml_file(input)
        url = nil
      else
        raise "Error input type"
      end
      return { xml: xml, url: url }
    end

    def open_xml_link(link)
      unless link =~ /^#{URI::regexp}$/
        raise "Wrong uri format: #{link}"
      end

      begin
        xml = Nokogiri::XML(open(link))
        return xml
      rescue
        raise "Cannot open link: #{link}"
      end
    end

    def open_xml_file(file)
      begin
        xml = Nokogiri::XML(file)
        return xml
      rescue
        raise "Cannot open file"
      end
    end
  end
end