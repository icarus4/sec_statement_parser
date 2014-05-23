# utilities.rb

module SecStatementParser

  module Utilities

    def year_range_is_valid(year)
      if year < SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL || year > Date.today.strftime("%Y").to_i
        puts "Please input valid year range: #{SecStatementParser::StatementUrlList::EARLIEST_YEAR_OF_XBRL} to #{Date.today.strftime("%Y")}, your input: #{year}"
        return false
      end
      return true
    end

    def create_dir_if_path_not_exist(path)
      FileUtils.mkdir_p(path) unless File.directory? path
    end

    def dir_exist?(path)
      File.directory?(path)
    end

    def list_absolute_filepath_recursively(path)
      Dir.glob("#{path}/**/*").reject{ |f| File.directory?(f) }
    end
  end
end
