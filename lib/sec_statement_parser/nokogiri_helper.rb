# nokogiri_helper.rb
class Nokogiri::XML::NodeSet
  def text_to_array
    array = []
    self.each do |node|
      array << node.text
    end
    return array
  end
end
