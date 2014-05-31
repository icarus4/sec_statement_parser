#!/usr/bin/env ruby

# $:.unshift( File.expand_path(__FILE__ + './lib') )
$LOAD_PATH << './lib'

require 'sec_statement_parser'
require 'colorize'
require 'pp'
require 'awesome_print'
require 'benchmark'

class Nokogiri::XML::Document
  def ns_to_array
    ns = self.namespaces
    array = []
    ns.each do |k,v|
      str = k.to_s.dup
      str.slice! 'xmlns'
      str.slice! ':'
      array << str
    end
    array
  end
end

FILE_1 = 'test/need_to_analyze/aa-20121231.xml'
FILE_2 = 'test/v-20130930.xml'

File.open(FILE_2, 'r') do |f|
  # File.open('test/fb-20131231.xml', 'r') do |f|
  xml = Nokogiri::XML(f)

  tmp = []
  namespaces = []

  xml.ns_to_array.each do |ns|
    if ns.empty?
      namespaces << ns
    else
      namespaces << "#{ns}:"
    end
  end

  end_date = xml.at_xpath('//dei:DocumentPeriodEndDate').text

  xml.remove_namespaces!

  nodes = xml.root.xpath("//context")
  nodes.dup.each do |node|
    nodes.delete(node) if node.xpath('.//segment').any?
    # nodes.delete(node) if node.xpath('.//endDate').text != end_date
    nodes.delete(node) if (Date.parse(end_date) - Date.parse(node.xpath('.//startDate').text)).to_i > 360
  end

  nodes.each do |node|
    _start_date = Date.parse(node.xpath('.//startDate').text)
    _end_date = Date.parse(node.xpath('.//endDate').text)
    # diff = Date.parse(end_date) - _start_date
    # puts diff.to_i
    puts "#{_start_date} - #{_end_date}"
  end

end
