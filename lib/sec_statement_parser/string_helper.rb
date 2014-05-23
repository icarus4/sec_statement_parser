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

  def check_value_color
    self.black.on_light_cyan
  end

  def alpha?
    !!match(/^[[:alpha:]]+$/)
  end

  def equal_ignore_case?(str)
    self.casecmp(str).zero?
  end
end
