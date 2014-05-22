# statement.rb

module SecStatementParser

  class Statement
    attr_reader :symbol

    def initialize(symbol)
      @symbol = validate_symbol symbol
    end

    def download(symbol)
      @symbol = validate_symbol(symbol) if symbol.upcase != @symbol
      download_statements
    end

    # def parse_without_download(symbol)
    #   @symbol = validate_symbol(symbol) if symbol.upcase != @symbol

    # end

    # def parse_with_download(symbol)
    #   @symbol = validate_symbol(symbol) if symbol.upcase != @symbol

    # end


    private

    MAX_SYMBOL_LENGTH = 8
    STATEMENT_DOWNLOAD_DIR = "#{Dir.home}/.sec_statement_parser/statements"

    def download_statements
      @url_list ||= StatementUrlList::get @symbol
      wget_statements @symbol, @url_list
    end

    def wget_statements(symbol, url_list)
      base_path = "#{STATEMENT_DOWNLOAD_DIR}/#{symbol}"
      annual_report_path = "#{base_path}/10-K"
      quarterly_report_path = "#{base_path}/10-Q"

      # Create folders to save statements
      create_folder_if_path_not_exist(annual_report_path)
      create_folder_if_path_not_exist(quarterly_report_path)

      url_list.each do |type, urls|
        next if urls.nil?
        urls.each do |url|
          download_folder = (type == :annual_report) ? annual_report_path : quarterly_report_path

          # -nc, --no-clobber              skip downloads that would download to existing files (overwriting them).
          # -P,  --directory-prefix=PREFIX  save files to PREFIX/...
          # -t,  --tries=NUMBER            set number of retries to NUMBER (0 unlimits).
          # -N,  --timestamping            don't re-retrieve files unless newer than local.
          #      --retry-connrefused       retry even if connection is refused.
          # -c,  --continue                resume getting a partially-downloaded file.
          # -q,  --quiet                   quiet (no output).
          print "Downloading #{url.split('/')[-1]} ..."
          puts "done".green if system("wget #{url} -P #{download_folder} -t 3 -q") == true
        end
      end

    end

    def create_folder_if_path_not_exist(path)
      FileUtils.mkdir_p(path) unless File.directory? path
    end

    def validate_symbol(symbol)
      raise "Error symbol type" unless symbol.is_a?(String)
      raise "Error symbol format" unless symbol.alpha?
      raise "Invalid symbol length" unless valid_symbol_length? symbol
      symbol.upcase
    end

    def valid_symbol_length?(symbol)
      return (symbol.length <= MAX_SYMBOL_LENGTH && symbol.length > 0) ? true : nil
    end

  end
end
