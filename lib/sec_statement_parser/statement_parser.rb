# statement_parser.rb

module SecStatementParser

  class StatementParser

    def initialize
      @statement = Hash.new
    end

    def parse(input)
      @xml = open_xml(input)
      # Clear before parsing
      @statement.clear unless @statement.nil?
      @statement = parse_statement
    end

    private

    MAX_DAYS_IN_A_YEAR = 366
    MIN_DAYS_IN_A_YEAR = 365
    MAX_DAYS_IN_A_QUARTER = 93
    MIN_DAYS_IN_A_QUARTER = 88

    def parse_statement
      @xml.remove_namespaces!
      @results = {}
      init_results_hash
      parse_statement_basic_info
      context_refs_hash = parse_context_refs(@results[:period_end_date])
      parse_statement_fields(context_refs_hash)
      ap @results
    end

    def init_results_hash
      @results[:fields_by_guess] = []
      @results[:should_check] = false
    end

    def add_to_guess_fields(symbol)
      @results[:fields_by_guess] << symbol
    end

    def parse_statement_fields(context_refs_hash)
      # for each field
      SecStatementFields::STATEMENT_FIELDS.each do |field, rules|
        # for each contextRef
        context_refs_hash.each do |context_ref_string, dates|

          match_count_for_current_keywords = 0

          # for each keyword
          rules[:keywords].each do |keyword|

            # skip if period is not a quarter or not a full year
            next if !dates[:period].between?(MIN_DAYS_IN_A_QUARTER, MAX_DAYS_IN_A_QUARTER) && !dates[:period].between?(MIN_DAYS_IN_A_YEAR, MAX_DAYS_IN_A_YEAR)

            # search
            node = @xml.xpath("//#{keyword}[@contextRef='#{context_ref_string}']")
            # skip if no result found
            next if node.empty?
            # one keyword should find only one result
            raise "Find #{node.length} results by \"#{keyword}\", expect 1 result" if node.length > 1

            # generate field name
            field_name = generate_field_symbol(field, context_ref_string, dates, @results[:fiscal_period])
            @results[field_name.to_sym] = node.first.text.to_f_or_i
            match_count_for_current_keywords += 1
          end # rules[:keywords].each do |keyword|

          raise "No result found for #{field}, please check\n\t#{context_refs_hash}\n\tcontext_ref_string:#{context_ref_string}" if match_count_for_current_keywords == 0 && rules[:should_presence]
          puts "Find #{match_count_for_current_keywords} results for #{field}, please check".check_value_color if match_count_for_current_keywords > 1

        end # context_refs.each do |context_ref, dates|
      end # SecStatementFields::STATEMENT_FIELDS.each do |field, rules|
    end # def parse_statement_fields(context_refs_hash)


    # CAUTIONS:
    # This fuction (generate_field_symbol) ONLY works when dates' end_date is equal to DocumentPeriodEndDate
    def generate_field_symbol(field, context_ref_string, dates, fiscal_period)
      # TYPE1_REGEX = '^[FD]+[0-9]{4}Q[1-4][QYTD]{0,3}'
      tmp = ""
      if context_ref_string =~ Regexp.new(SecStatementFields::REGEX_STR_TYPE1)
        case context_ref_string
        when /^[FD]+[0-9]{4}Q1YTD$/ # ex: FD2013Q1YTD => xxx_q1
          tmp = "#{field.to_s}_q1"
        when /^[FD]+[0-9]{4}Q[2-3]{1}YTD$/ # ex: FD2013Q2YTD => xxx_q2ytd
          tmp = "#{field.to_s}_q#{context_ref_string[-4]}ytd"
        when /^[FD]+[0-9]{4}Q4YTD$/ # ex: FD2013Q4YTD => xxx_fy
          tmp = "#{field.to_s}_fy"
        when /^[FD]+[0-9]{4}Q[1-4]{1}$/ # ex: FD2013Q1 => xxx_q1
          tmp = "#{field.to_s}_q#{context_ref_string[-1]}"
        when /^[FD]+[0-9]{4}Q[1-4]{1}QTD$/ # ex: FD2013Q2 => xxx_q2
          tmp = "#{field.to_s}_q#{context_ref_string[-4]}"
        else
          raise "Exception case: context_ref_string: #{context_ref_string}"
        end # case contextRef

        raise "Error output string: #{tmp}" if tmp !~ /_q[1-4]$/ && tmp !~ /_q[2-4]ytd$/ && tmp !~ /_fy$/

      elsif context_ref_string =~ /^eol_/

        case dates[:period]
        when MIN_DAYS_IN_A_QUARTER..MAX_DAYS_IN_A_QUARTER
          if fiscal_period.nil?
            tmp = "#{field.to_s}_this_quarter"
          else
            raise "Error fiscal period is not valid: #{fiscal_period}" if fiscal_period !~ /^Q[1-4]{1}$/
            tmp = "#{field.to_s}_#{fiscal_period.downcase}"
          end
        when MIN_DAYS_IN_A_YEAR..MAX_DAYS_IN_A_YEAR
          tmp = "#{field.to_s}_fy"
        else
          raise "period not matched: #{dates[:period]}"
        end
      else
        raise "Unknow contextRef type: #{context_ref}"
      end

      return tmp
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

      raise "Cannot find context refs" if context_refs.length == 0

      return context_refs
    end

    def parse_statement_basic_info
      SecStatementFields::STATEMENT_BASIC_INFO_FIELDS.each do |field, rule|
        @results[field] = get_one_text_by_element(rule[:keywords][0])
        raise_error_if_nil_and_should_presence(rule[:should_presence], @results[field], field)
      end

      fill_in_nil_fields_by_guess
    end

    # Guess nil fields by known fields
    def fill_in_nil_fields_by_guess
      # Fiscal year
      # FIXME: year of period_end_date may not be exactly the same with fiscal_year
      if @results[:fiscal_year].nil?
        @results[:fiscal_year] = Date.parse(@results[:period_end_date]).year.to_s
        add_to_guess_fields(:fiscal_year)
      end

      # Fiscal period
      if @results[:fiscal_period].nil?
        if @results[:document_type] == '10-K'
          @results[:fiscal_period] = 'FY'
        elsif @results[:document_type] == '10-Q'

          date = Date.parse(@results[:period_end_date])

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
          raise "Wrong document type: #{@results[:document_type]}"
        end
        add_to_guess_fields(:fiscal_period)
      end
    end

    def get_one_text_by_element(keyword)
      node = @xml.xpath("//#{keyword}")

      case node.length
      when 0
        puts "No result found by keyword \"#{keyword}\"".warning_color
        return nil
      when 1
        return node.text
      else
        raise "This keyword (#{keyword}) should NOT has multiple results" if node.length > 1
      end
    end

    def raise_error_if_nil_and_should_presence(should_presence, value, field)
      if should_presence && value.nil?
        raise "#{field} should presence"
      end
    end

    # Return Nokogiri::XML object
    def open_xml(input)
      if input.is_a? String
        return open_xml_link(input)
      elsif input.is_a? File
        return open_xml_file(input)
      else
        raise "Error input type"
      end
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