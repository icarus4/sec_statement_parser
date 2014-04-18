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

    def initialize(log_level="WARN")

      # Set default log level to WARN
      log_level = "WARN" unless LOG_LEVELS.include? log_level.upcase
      $log = Logger.new(STDOUT)
      eval("$log.level = Logger::#{log_level.upcase}")
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
      pp result
      result.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end
  end
end
