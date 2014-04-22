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

    def list(symbol='')
      puts "Please enter symbol." or return nil if symbol.empty?

      @list = StatementUrlList.get(symbol.upcase)
    end

    def parse_annual_report(year)
      # Check year range
      return nil unless year_range_is_valid(year)

      # Todo: reset fields before parse

      link = @urls[:annual_report]["y#{year}".to_sym]
      result = SecStatementFields.parse(link)

      # Set parsed results to instance variables of Statement
      result.each do |k, v|
        instance_variable_set("@#{k}", v)
      end

      return result
    end

    def parse_link(link)
      result = SecStatementFields.parse(link)
      return result
    end

    def parse_file(file)
      return nil unless file.is_a? File
      result = SecStatementFields.parse(file)
    end
  end
end
