module SecStatementParser

  class SecDate

    DATE_STRING_VALIDATION_REGEXP = Regexp.new '^[12][0-9]{3}-[01][0-9]-[0-3][0-9]$'

    attr_reader :year, :month, :day

    def initialize(date_string)
      raise "The input should be String" unless date_string.is_a? String
      raise "Error date format: #{date_string}, should be \"year-month-day\"" if date_string.match(DATE_STRING_VALIDATION_REGEXP).nil?
      @year = date_string[0..3]
      @month = date_string[5..6]
      @day = date_string[8..9]
    end

  end
end