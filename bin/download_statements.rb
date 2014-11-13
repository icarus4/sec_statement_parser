$LOAD_PATH << './lib'

require 'sec_statement_parser'
require 'json'
require 'csv'

STOCK_LIST_FILE = 'data/companylist.csv'
FAIL_FILE = "#{Dir.home}/.sec_statement_parser/fail_to_download_list"
LAST_DOWNLOADED_STOCK_FILE = "#{Dir.home}/.sec_statement_parser/last_downloaded_stock"

class String
  def append_to_file(path)
    File.open(path, 'a') do |file|
      file.puts self
    end
  end
  def write_to_file(path)
    File.open(path, 'w') do |file|
      file.puts self
    end
  end
end

# determine start from first stock or last downloaded stock
start_from_last_downloaded_stock = true
if ARGV[0] == 'restart'
  start_from_last_downloaded_stock = false
  puts "download from first stock"
else
  last_downloaded_stock = IO.read(LAST_DOWNLOADED_STOCK_FILE).strip
  puts "download from last downloaded stock: #{last_downloaded_stock}"
end


check_for_skip_downloaded_stock = start_from_last_downloaded_stock

CSV.foreach(STOCK_LIST_FILE) do |row|
  ticker = row[0].strip

  if check_for_skip_downloaded_stock == true
    puts "#{ticker} #{last_downloaded_stock}"
    next if ticker != last_downloaded_stock
    check_for_skip_downloaded_stock = false
  end

  begin
    s = SecStatementParser::Statement.new ticker
    s.download('10-K')
    ticker.write_to_file(LAST_DOWNLOADED_STOCK_FILE)
    sleep 3
  rescue
    ticker.append_to_file(FAIL_FILE)
    next
  end
end

