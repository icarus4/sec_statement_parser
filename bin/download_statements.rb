$LOAD_PATH << './lib'

require 'sec_statement_parser'
require 'json'
require 'csv'

STOCK_LIST_FILE = 'data/companylist.csv'

CSV.foreach(STOCK_LIST_FILE) do |row|
  begin
    s = SecStatementParser::Statement.new row[0]
    s.download('10-K')
  rescue
    next
  end
end

