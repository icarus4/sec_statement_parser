# nokogiri_helper.rb
class Nokogiri::XML::NodeSet
  def text_to_array
    array = []
    self.each do |node|
      array << node.text
    end
    return array
  end

  def remove_subnode_if_contains_element!(element)
    self.dup.each do |node|
      self.delete(node) if node.xpath(".//#{element}").any?
    end
  end

  def remove_subnode_if_not_contains_element!(element)
    self.dup.each do |node|
      self.delete(node) if node.xpath(".//#{element}").empty?
    end
  end
end
