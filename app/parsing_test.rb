#!/usr/bin/env ruby -wKU

$: << './lib'

require 'sec_statement_parser'
require 'json'
require 'pp'

DATA_SOURCE_FILE = 'app/output/list.json'
OUTPUT_STATEMENT_FILE = 'app/output/statement.json'
OUTPUT_FAILED_STATEMENT_FILE = 'app/output/failed_statement.txt'

# catch ctrl+c
interrupted = false
trap('INT') { interrupted = true }

# Init
s = SecStatementParser::Statement.new('DEBUG')
result_hash = {}
statement_hash = {}
fail_array = []

# Read statement url list
begin
  stocks = JSON.parse(File.read(DATA_SOURCE_FILE))
rescue
end

# Read existing results
begin
  result_hash = JSON.parse(File.read(OUTPUT_STATEMENT_FILE))
  File.open(OUTPUT_FAILED_STATEMENT_FILE, 'r') do |f|
    f.each_line do |line|
      fail_array.push line.chomp
    end
  end
rescue
end

stocks.each do |stock, reports| # stocks
  break if interrupted

  # Reset hash
  statement_hash = {}

  reports.each do |report, contents| # annual_report
    break if interrupted
    contents.each do |year, url| #
      # catch ctrl+c
      break if interrupted

      begin
        puts "Parsing #{stock}'s #{year} report..."
        result = {}
        result = s.parse_link(url)
      rescue
        fail_array << stock unless fail_array.include? stock
        next
      end

      if result.nil? || result.empty?
        fail_array << stock unless fail_array.include? stock
      else
        pp result
        statement_hash[year.to_sym] = result
      end
    end
  end

  break if interrupted
  result_hash[stock.to_sym] = statement_hash

end # end stocks.each


File.open(OUTPUT_STATEMENT_FILE, 'w') do |f|
  f.write(JSON.pretty_generate result_hash)
end

File.open(OUTPUT_FAILED_STATEMENT_FILE, 'w') do |f|
  f.puts(fail_array)
end
