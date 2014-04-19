# statement.rb

module SecStatementParser

  class Statement
    include SecStatementFields
    include Debug

    attr_reader(:symbol,:urls)

    @@fields[:fields_parsed_by_xpath].each do |k, v|
      self.__send__(:attr_reader, k)
    end

    @@fields[:fields_parsed_by_parse_method_1].each do |k, v|
      self.__send__(:attr_reader, k)
    end

    def initialize(log_level='')
      init_logger(log_level)
    end

    def get(symbol='')
      return nil if symbol.empty?

      @symbol = symbol.upcase
      @urls = StatementUrlList.get(@symbol)
    end

    def parse_annual_report(year)
      # Check year range
      if year < SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL || year > Date.today.strftime("%Y").to_i
        puts "Please input valid year range: #{SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL} to #{Date.today.strftime("%Y")}, your input: #{year}"
        return nil
      end

      # Todo: reset fields before parse
    end

    def parse_file(file)
      return nil unless file.is_a? File

      begin
        xml = Nokogiri::XML(file)
      rescue
        puts 'Cannot open file'
        return nil
      end

      result = SecStatementFields.parse(xml)
      result.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end
  end
end
