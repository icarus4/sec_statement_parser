#!/usr/bin/env ruby -wKU

$: << './lib'

require 'sec_statement_parser'
require 'json'
require 'pp'

DATA_SOURCE_FILE = 'app/output/list_of_xbrl_link.json'
OUTPUT_STATEMENT_FILE = 'app/output/parsing_test_results.json'
OUTPUT_FAILED_STATEMENT_FILE = 'app/output/parsing_test_failed_stocks.txt'

# Skip stocks in OUTPUT_FAILED_FILE
skip_parsed = ARGV[0] == '--skip-parsed' ? true : false
puts "skip parsed stock".green if skip_parsed

# catch ctrl+c
interrupted = false
trap('INT') { interrupted = true }

# Init
s = SecStatementParser::Statement.new('DEBUG')
result_hash = {}
statement_hash = {}
fail_array = []

# Read statement url list
stocks = JSON.parse(File.read(DATA_SOURCE_FILE))

# Read existing results
result_hash = JSON.parse(File.read(OUTPUT_STATEMENT_FILE))
File.open(OUTPUT_FAILED_STATEMENT_FILE, 'r') do |f|
  f.each_line do |line|
    fail_array.push line.chomp
  end
end

stocks.each do |stock, reports| # stocks
  break if interrupted

  if skip_parsed && result_hash.has_key?(stock) && !fail_array.include?(stock)
    puts "#{stock} is already parsed....skip".green
    next
  end

  # Reset hash
  statement_hash = {}

  reports.each do |report, urls| # annual_report
    break if interrupted

    urls.each do |url| #
      # catch ctrl+c
      break if interrupted
      next if url.include? "-2009" # skip 2009's statement because their format are different..

      result = {}
      puts "Parsing #{stock}'s report... #{url}"

      begin
        result = s.parse_link(url)
      rescue
        fail_array << stock unless fail_array.include? stock
        next
      end

      if result.nil? || result.empty?
        fail_array << stock unless fail_array.include? stock
      else
        pp result
        statement_hash["y#{result[:fiscal_year]}".to_sym] = result
      end
    end
  end

  result_hash[stock] = statement_hash

end # end stocks.each


File.open(OUTPUT_STATEMENT_FILE, 'w') do |f|
  f.write(JSON.pretty_generate result_hash)
end

File.open(OUTPUT_FAILED_STATEMENT_FILE, 'w') do |f|
  f.puts(fail_array)
end
