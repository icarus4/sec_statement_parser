# statement.rb

module SecStatementParser

  class Statement
    include Utilities

    attr_reader (:symbol)

    def initialize(symbol="")
      return nil if symbol.empty?

      @symbol = symbol.upcase
    end
  end
end
