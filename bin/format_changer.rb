require 'json'
require 'pp'

source_hash = JSON.parse(File.read('./bin/output/list.json'))
output_hash = {}

source_hash.each do |stock, reports|
  tmp = {}
  url_list = []
  reports.each do |report, statements|
    statements.each do |year, url|
      url_list << url
    end
  end
  tmp[:annual_report] = url_list
  output_hash[stock] = tmp
end

File.open('./bin/output/list_of_xbrl_link.json', 'w') do |f|
  f.write(JSON.pretty_generate output_hash)
end
