# string_helper.rb

class String

  def integer?
    Integer(self) != nil rescue false
  end

  def float?
    Float(self) != nil rescue false
  end

  def to_f_or_i
    if self.integer?
      return self.to_i
    elsif self.float?
      return self.to_f
    else
      raise "#{self} is not a Integer or Float"
    end
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
