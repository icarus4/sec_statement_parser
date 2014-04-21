#!/usr/bin/env ruby -wKU

$: << './lib'

require 'sec_statement_parser'
require 'json'
require 'pp'

OUTPUT_RESULT_FILE = 'app/output/list.json'
OUTPUT_FAILED_FILE = 'app/output/failed.txt'

# catch ctrl+c
interrupted = false
trap('INT') { interrupted = true }

# Init
result_hash = {}
fail_array = []
s = SecStatementParser::Statement.new('DEBUG')

# Read existing result so as to start from it
result_hash = JSON.parse(File.read(OUTPUT_RESULT_FILE))
File.open(OUTPUT_FAILED_FILE, 'r') do |f|
  f.each_line do |line|
    fail_array.push line.chomp
  end
end

begin
  retry_counter = 0
  File.open('./test/nasdaq_traded_stock_list.txt', 'r') do |f|

    counter = 0

    f.each_line do |line|

      # catch ctrl+c
      break if interrupted

      # Get symbol
      symbol = line.split('|')[0]
      puts "Processing #{symbol}..."

      # Skip if already parsed
      if result_hash.has_key?(symbol)
        puts "Already has #{symbol}, skip"
        next
      end

      # Store failed case
      list = s.list(symbol)
      if list.nil?
        fail_array << symbol unless fail_array.include? symbol
        next
      end

      # Success
      result_hash[symbol.to_sym] = list
      counter += 1
      retry_counter = 0

    end
  end

rescue

  puts "Unknown error, retry...".red
  retry_counter += 1

  retry if retry_counter > 3

ensure

  File.open(OUTPUT_RESULT_FILE, 'w') do |f|
    f.write(result_hash.to_json)
  end

  File.open(OUTPUT_FAILED_FILE, 'w') do |f|
    f.puts(fail_array)
  end

end
