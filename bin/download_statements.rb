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

# catch ctrl-c & kill
interrupted = false
trap('INT') { interrupted = true }
trap('TERM') { interrupted = true }


# determine start from first stock or last downloaded stock
start_from_last_downloaded_stock = false
stock_list_file = STOCK_LIST_FILE
if ARGV[0] == 'restart'
  puts "download from first stock"
elsif ARGV[0] == 'fail'
  puts "download from fail list"
  stock_list_file = FAIL_FILE
else
  start_from_last_downloaded_stock = true
  last_downloaded_stock = IO.read(LAST_DOWNLOADED_STOCK_FILE).strip
  puts "download from last downloaded stock: #{last_downloaded_stock}"
end

check_for_skip_downloaded_stock = start_from_last_downloaded_stock


CSV.foreach(stock_list_file) do |row|
  ticker = row[0].strip

  if check_for_skip_downloaded_stock == true
    puts "skip #{ticker}"
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
  end

  # catch ctrl-c or kill
  if interrupted == true
    puts "signal INT/TERM catched, exiting..."
    sleep 1
    break
  end
end

