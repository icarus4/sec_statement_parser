# statement_parser.rb

module SecStatementParser

  class StatementParser

    def initialize
    end

    def parse(input)
      @xml = open_xml(input)
      @statement = parse_statement
    end

    private

    def parse_statement
      @xml.remove_namespaces!
      parse_statement_basic_info
      # todo: parse other fields
    end

    def parse_statement_basic_info
      results = {}
      SecStatementFields::STATEMENT_BASIC_INFO_FIELDS.each do |field, rule|
        results[field] = get_one_text_by_element(rule[:keywords][0])
        raise_error_if_nil_and_should_presence(rule[:should_presence], results[field], field)
      end

      results = fill_in_nil_fields_by_guess(results)
      ap results
    end

    # Guess nil fields by known fields
    def fill_in_nil_fields_by_guess(results)
      # Fiscal year
      # FIXME: year of period_end_date may not be exactly the same with fiscal_year
      if results[:fiscal_year].nil?
        results[:fiscal_year] = SecDate.new(results[:period_end_date]).year
      end

      # Fiscal period
      if results[:fiscal_period].nil?
        if results[:document_type] == '10-K'
          results[:fiscal_period] = 'FY'
        elsif results[:document_type] == '10-Q'
          # TODO: currently we are not sure how to decide fiscal period precisely...
        else
          raise "Wrong document type: #{results[:document_type]}"
        end
      end

      return results
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