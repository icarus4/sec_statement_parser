# statement.rb

module SecStatementParser

  class Statement
    include SecStatementFields
    include Debug
    include Utilities

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
      return nil unless year_range_is_valid(year)

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
