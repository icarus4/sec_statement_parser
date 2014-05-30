# statement.rb

module SecStatementParser

  class Statement
    include Utilities

    attr_reader :symbol, :result, :url_list, :statements

    def initialize(symbol, debug=false)
      @symbol = validate_symbol symbol
      @debug = !!debug
      @parser = StatementParser.new(@debug)
      @statements = []
    end

    def download(symbol=@symbol)
      @symbol = validate_symbol(symbol) unless symbol.equal_ignore_case?(@symbol)
      download_statements
    end

    def parse_local(symbol=@symbol)
      @symbol = validate_symbol(symbol) unless symbol.equal_ignore_case?(@symbol)
      parse_local_statements(@symbol)
    end

    def parse_local_all
      parse_local_statements
    end

    def get_list(symbol=@symbol)
      @symbol = validate_symbol(symbol) unless symbol.equal_ignore_case?(@symbol)
      @url_list = _get_list
    end

    def parse_url_list
      raise "#get_list before #parse_url_list" if @url_list.nil?

      @url_list.values.each do |urls|
        urls.each do |url|
          @statements << @parser.parse(url)
        end
      end

      return @statements
    end

    # TODO
    def parse_with_download(symbol=@symbol)
      @symbol = validate_symbol(symbol) unless symbol.equal_ignore_case?(@symbol)
      # TODO:
      raise "Not implement yet"
    end


    private

    MAX_SYMBOL_LENGTH = 8
    STATEMENT_DOWNLOAD_DIR = "#{Dir.home}/.sec_statement_parser/statements"

    def parse_local_statements(symbol=nil)
      statement_dir = "#{STATEMENT_DOWNLOAD_DIR}/#{symbol}"

      if dir_exist?(statement_dir)
        parse_file_recursively(statement_dir)
      else
      end

      # if found at local
        # open file
        # parse
      # if not found at local
        # get list
        # parse
    end

    def parse_file_recursively(statement_dir)
      list_absolute_filepath_recursively(statement_dir).each do |filepath|
        File.open(filepath, 'r') do |file|
          puts "Parsing #{filepath}".green
          @statements << @parser.parse(file)
        end
      end
    end

    def _get_list
      StatementUrlList::get @symbol
    end

    def download_statements
      base_path = "#{STATEMENT_DOWNLOAD_DIR}/#{@symbol}"
      annual_report_path = "#{base_path}/10-K"
      quarterly_report_path = "#{base_path}/10-Q"

      @url_list = _get_list

      # Create dirs to save statements
      create_dir_if_path_not_exist(annual_report_path)
      create_dir_if_path_not_exist(quarterly_report_path)

      @url_list.each do |type, urls|
        next if urls.nil?
        urls.each do |url|
          download_dir = (type == :annual_report) ? annual_report_path : quarterly_report_path
          # -nc, --no-clobber              skip downloads that would download to existing files (overwriting them).
          # -P,  --directory-prefix=PREFIX  save files to PREFIX/...
          # -t,  --tries=NUMBER            set number of retries to NUMBER (0 unlimits).
          # -N,  --timestamping            don't re-retrieve files unless newer than local.
          #      --retry-connrefused       retry even if connection is refused.
          # -c,  --continue                resume getting a partially-downloaded file.
          # -q,  --quiet                   quiet (no output).
          print "Downloading #{url.split('/')[-1]} ..."
          puts "done".green if system("wget #{url} -P #{download_dir} -t 3 -q") == true
        end
      end

    end

    def validate_symbol(symbol)
      raise "Error symbol type: #{symbol.class}" unless symbol.is_a?(String)
      raise "Error symbol format. symbol: #{symbol}" unless symbol.alpha?
      raise "Invalid symbol length. symbol: #{symbol}" unless valid_symbol_length? symbol
      symbol.upcase
    end

    def valid_symbol_length?(symbol)
      return (symbol.length <= MAX_SYMBOL_LENGTH && symbol.length > 0) ? true : nil
    end

  end
end
