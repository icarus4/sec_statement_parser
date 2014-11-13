# statement_url_list.rb

module SecStatementParser

  module StatementUrlList

    extend Utilities

    BASE_SEC_URL = 'http://www.sec.gov'
    ANNUAL_REPORT = '10-K'
    QUARTERLY_REPORT = '10-Q'
    ENTRIES_PER_PAGE = 100
    EARLIEST_YEAR_OF_XBRL = 2010

    def self.get(symbol, type=:both, start_year: StatementUrlList::EARLIEST_YEAR_OF_XBRL, end_year: Date.today.strftime("%Y").to_i)
      raise "start_year > end_year" if start_year > end_year
      raise "invalid start_year" unless year_range_is_valid(start_year)
      raise "invalid end_year" unless year_range_is_valid(end_year)

      list = {}
      list_10K = _get_list_of_xbrl_url(symbol, ANNUAL_REPORT) if type == :both || type == :annual_report
      list_10Q = _get_list_of_xbrl_url(symbol, QUARTERLY_REPORT) if type == :both || type == :quarterly_report

      return nil if list_10Q == nil and list_10K == nil

      list[:annual_report] = list_10K
      list[:quarterly_report] = list_10Q

      return list
    end

    private

    def self._get_list_of_xbrl_url(symbol, type)

      url_list = []
      target_td_nodes = []

      type = type.upcase

      # Validate input
      # TODO: handle quarterly report
      if type != ANNUAL_REPORT && type != QUARTERLY_REPORT
        raise "Error statement type. Support #{ANNUAL_REPORT} and #{QUARTERLY_REPORT} only"
      end

      # Get html
      query_url = "http://www.sec.gov/cgi-bin/browse-edgar?CIK=#{symbol.downcase}&Find=Search&owner=exclude&action=getcompany&type=#{type}&count=#{ENTRIES_PER_PAGE}"
      begin
        puts "Obtaining #{symbol.upcase}'s #{type} URL list"
        doc = Nokogiri::HTML(open(query_url))
      rescue
        raise "Cannot obtain #{symbol.upcase}'s #{type}"
      end

      # Check whether symbol is correct or not by analyzing return html
      if doc.css("#seriesDiv").empty?
        puts "Wrong stock symbol: \"#{symbol}\"".light_red.on_light_white
        raise "Wrong stock symbol"
      end

      # A financial statement contains "Interactive Data" implies it has XBRL format, and that's what we need.
      match_counter = 0
      doc.css('#seriesDiv tr td').each do |node|
        if node.css('a').text.downcase.include? 'interactive data'
          target_td_nodes << node
          match_counter += 1
        end
      end

      if match_counter == 0
        puts 'No available filing page found.'.yellow
        return nil
      end

      # TODO: handle exception when entries > ENTRIES_PER_PAGE (100)
      raise ParseError, 'Match data' if match_counter >= ENTRIES_PER_PAGE

      target_td_nodes.each do |node|
        # filing_detail_url is something like http://www.sec.gov/Archives/edgar/data/1326801/000132680114000007/0001326801-14-000007-index.htm
        filing_detail_url = BASE_SEC_URL + node.css("a[id='documentsbutton']")[0]['href']

        # Get URL of XBRL
        xbrl_url = self._get_xbrl_url_from_filing_detail_page(filing_detail_url)

        if xbrl_url.nil?
          next
        else
          begin
            if Faraday.head(xbrl_url).status != 200
              puts "link fail: #{xbrl_url}".yellow
            else
              puts "get #{xbrl_url}"
            end
          rescue
            puts "Unknown error when testing #{xbrl_url} using Faraday".yellow
          end

          url_list << xbrl_url
        end
      end

      return url_list
    end

    def self._get_xbrl_url_from_filing_detail_page(filing_detail_url)

      begin
        doc = Nokogiri::HTML(open(filing_detail_url))
      rescue
        puts "open #{filing_detail_url} failed".yellow
        return nil
      end

      # Data Files is the table contains xbrl files.
      # ex: see bottom of this page:
      # http://www.sec.gov/Archives/edgar/data/1326801/000132680114000007/0001326801-14-000007-index.htm
      doc.css("table[summary='Data Files'] tr").each do |tr|
        match = false
        tr.css('td').each do |td|
          # check whether this tr contrains xbrl instance or not
          if td.text.upcase == 'EX-101.INS'
            match = true
            break
          end
        end

        if match == true
          xbrl_url = BASE_SEC_URL + tr.css('a')[0]['href']
          return xbrl_url
        end
      end

      return nil
    end

    def self._get_fiscal_year(link)
      begin
        doc = Nokogiri::XML(open(link))
      rescue
        $log.warn("Cannot open link #{list[0]}")
        return nil
      end

      return doc.xpath('//dei:DocumentFiscalYearFocus').text.to_i
    end

    def self._get_year_from_linkname(link)

      # TODO: error handle

      # ex: http://www.sec.gov/Archives/edgar/data/1403161/000140316113000011/v-20130930.xml => return 2013
      return link.split('-')[1][0..3].to_i
    end
  end
end
