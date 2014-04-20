# string_helper.rb

class String

  def integer?
    Integer(self) != nil rescue false
  end

  def float?
    Float(self) != nil rescue false
  end
end
