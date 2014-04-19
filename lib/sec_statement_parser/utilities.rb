# utilities.rb

module SecStatementParser

  module Utilities

    def year_range_is_valid(year)
      if year < SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL || year > Date.today.strftime("%Y").to_i
        puts "Please input valid year range: #{SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL} to #{Date.today.strftime("%Y")}, your input: #{year}"
        return false
      end
      return true
    end
  end
end
