class Hash
  # search key by regex
  def has_rkey?(keyword)
    keyword = Regexp.new(keyword.to_s) unless keyword.is_a?(Regexp)
    !!keys.detect { |key| key =~ keyword }
  end

  def get_rkeys(keyword)
    keyword = Regexp.new(keyword.to_s) unless keyword.is_a?(Regexp)
    self.select { |k,v| k =~ keyword }.keys
  end
end