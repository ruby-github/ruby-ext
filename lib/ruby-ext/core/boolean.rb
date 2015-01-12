class TrueClass
  def to_i
    1
  end

  def exit
    Kernel.exit 0
  end
end

class FalseClass
  def to_i
    0
  end

  def exit
    Kernel.exit 1
  end
end