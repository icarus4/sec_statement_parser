#!/usr/bin/env ruby -wKU

$: << './lib'

require 'sec_statement_parser'
require 'json'
require 'pp'

OUTPUT_RESULT_FILE = 'app/output/list_of_xbrl_link.json'
OUTPUT_FAILED_FILE = 'app/output/failed.txt'

# Skip stocks in OUTPUT_FAILED_FILE
skip_fail = ARGV[0] == 'skip' ? true : false

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

loop do
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

        # Skip stocks in OUTPUT_FAILED_FILE
        if skip_fail
          if fail_array.include? symbol
            puts "Skip stocks listed in #{OUTPUT_FAILED_FILE}".red
            next
          end
        end

        list = s.list(symbol)

        # Store failed case
        if list.nil?
          fail_array << symbol unless fail_array.include? symbol
          next
        end

        # Success
        result_hash[symbol.to_sym] = list
        fail_array.delete(symbol) if fail_array.include? symbol # Remove from fail list if seccess

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
      f.write(JSON.pretty_generate result_hash)
    end

    File.open(OUTPUT_FAILED_FILE, 'w') do |f|
      f.puts(fail_array)
    end

  end # end begin

  break if interrupted

end # end loop
