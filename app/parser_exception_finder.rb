#!/usr/bin/env ruby -wU
# parser_exception_finder.rb

$LOAD_PATH << './lib'

require "sec_statement_parser"
require "json"

OUTPUT_DIR = "#{Dir.home}/.sec_statement_parser/app/parser_exception_finder/output"
OUTPUT_PARSE_FAIL_FILE = "#{OUTPUT_DIR}/parse_fail_symbols.txt"
OUTPUT_GET_LIST_FAIL_FILE = "#{OUTPUT_DIR}/get_list_fail_symbols.txt"
# OUTPUT_PARSE_RESULT = "#{OUTPUT_DIR}/parse_result.json"
SYMBOL_FILE = "#{Dir.home}/.sec_statement_parser/data/nasdaq_traded_stock_list.txt"


class String
  def append_to_file(path)
    File.open(path, 'a') do |file|
      file.puts self
    end
  end
end

skip_parsed = ARGV[0] == '--no-skip' ? false : true

# catch ctrl-c
interrupted = false
trap('INT') { interrupted = true }

parse_fail_array = IO.readlines(OUTPUT_PARSE_FAIL_FILE).map(&:chomp)
get_list_fail_array = IO.readlines(OUTPUT_GET_LIST_FAIL_FILE).map(&:chomp)
result_json_hash = JSON.parse(File.read("#{OUTPUT_DIR}/A.json"))

symbol = ""
prev_symbol = ""


File.open(SYMBOL_FILE, 'r') do |f|

  f.each_line do |line|

    # catch ctrl-c
    break if interrupted

    symbol = line.split('|')[0]
    if prev_symbol[0] != symbol[0]
      if !prev_symbol.empty?
        File.open("#{OUTPUT_DIR}/#{prev_symbol[0]}.json", 'w') do |file|
          file.write(JSON.pretty_generate Hash[result_json_hash.sort])
        end
      end
      result_json_hash = JSON.parse(File.read("#{OUTPUT_DIR}/#{symbol[0]}.json"))
    end
    prev_symbol = symbol

    next if !skip_parsed && result_json_hash.has_key?(symbol)
    next if symbol[0] == 'A'

    begin
      puts "Prepare to parse #{symbol} @ #{Time.now}"
      s = SecStatementParser::Statement.new symbol
      s.get_list
    rescue
      symbol.append_to_file(OUTPUT_GET_LIST_FAIL_FILE) unless get_list_fail_array.include?(symbol)
      get_list_fail_array << symbol
      next
    end

    begin
      result_json_hash[symbol] = s.parse_url_list
    rescue
      symbol.append_to_file(OUTPUT_PARSE_FAIL_FILE) unless parse_fail_array.include?(symbol)
      parse_fail_array << symbol
      next
    end
  end
end

File.open("#{OUTPUT_DIR}/#{symbol[0]}.json", 'w') do |f|
  f.write(JSON.pretty_generate Hash[result_json_hash.sort])
end
