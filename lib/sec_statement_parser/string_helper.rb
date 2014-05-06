# string_helper.rb

class String

  def integer?
    Integer(self) != nil rescue false
  end

  def float?
    Float(self) != nil rescue false
  end

  def warning_color
    self.black.on_yellow
  end

  def error_color
    self.black.on_light_red
  end
end
