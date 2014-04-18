# statement_url_list
module SecStatementParser

  module StatementUrlList

    private

    BASE_SEC_URL = 'http://www.sec.gov'
    ANNUAL_REPORT = '10-K'
    QUARTERLY_REPORT = '10-Q'
    ENTRIES_PER_PAGE = 100
    EARLIEST_YEAR_OF_XBRL = 2010

    def self.get(symbol)

      list = {}
      return nil if (list_10K = _get_list(symbol, ANNUAL_REPORT)) == nil
      list['10-K'] = list_10K

      # Todo: enable 10-Q later
      # return nil if (list_10Q = get_list(symbol, QUARTERLY_REPORT)) == nil
      # list['10-Q'] = list_10Q

      return list
    end


    private

    def self._get_list(symbol, type)

      url_list = []
      target_td_nodes = []

      type = type.upcase

      # Validate input
      if type != ANNUAL_REPORT && type != QUARTERLY_REPORT
        puts "Support #{ANNUAL_REPORT} only"
        return nil
      end

      # Get html
      query_url = "http://www.sec.gov/cgi-bin/browse-edgar?CIK=#{symbol.downcase}&Find=Search&owner=exclude&action=getcompany&type=#{type}&count=#{ENTRIES_PER_PAGE}"
      begin
        puts "Obtaining #{symbol.upcase}'s #{type} URL list"
        doc = Nokogiri::HTML(open(query_url))
      rescue
        puts "Cannot obtain #{symbol.upcase}'s #{type}"
        return nil
      end

      # Check whether symbol is correct or not by analyzing return html
      if doc.css("#seriesDiv").empty?
        puts "Wrong stock symbol: \"#{symbol}\"".light_red.on_light_white
        return nil
      end

      # A financial statement contains "Interactive Data" implies it has XBRL format, and that's what we need.
      match_counter = 0
      doc.css('#seriesDiv tr td').each do |node|
        if node.css('a').text.downcase.include? 'interactive data'
          target_td_nodes << node
          match_counter += 1
        end
      end

      Raise ParseError.new('No available filing page found.') if match_counter == 0

      # To-do: handle exception when entries > ENTRIES_PER_PAGE (100)
      Raise ParseError.new('Match data') if match_counter >= ENTRIES_PER_PAGE

      target_td_nodes.each do |node|
        # filing_detail_url is something like http://www.sec.gov/Archives/edgar/data/1326801/000132680114000007/0001326801-14-000007-index.htm
        filing_detail_url = BASE_SEC_URL + node.css("a[id='documentsbutton']")[0]['href']

        # Get URL of XBRL
        xbrl_url = self._get_xbrl_url_from_filing_detail_page(filing_detail_url)

        if xbrl_url.nil?
          next
        else
          if Faraday.head(xbrl_url).status != 200
            puts "link fail: #{xbrl_url}".red
          else
            puts "get #{xbrl_url}"
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
  end
end
