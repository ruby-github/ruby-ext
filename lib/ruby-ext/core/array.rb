class Array
  def dclone
    dup = self.dup

    dup.each_with_index do |x, index|
      dup[index] = x.dclone
    end

    dup
  end

  def utf8!
    each_with_index do |x, index|
      self[index] = x.utf8
    end

    self
  end

  def locale!
    each_with_index do |x, index|
      self[index] = x.locale!
    end

    self
  end

  def deep_merge array, &block
    dclone.deep_merge! array, &block
  end

  def deep_merge! array, &block
    array.each_with_index do |v, index|
      val = self[index]

      if val.is_a? Array
        if v.is_a? Array
          self[index] = val.deep_merge! v, &block
        end
      else
        if not v.is_a? Array
          if block
            self[index] = block.call val, v
          else
            if val.nil? or v.nil?
              self[index] = val || v
            else
              self[index] = val + v
            end
          end
        end
      end
    end

    self
  end

  def split all = false
    array = []

    list = []

    each do |x|
      if yield x
        if not list.empty?
          array << list
        end

        if all
          list = [
            x
          ]
        else
          list = []
        end
      else
        list << x
      end
    end

    if not list.empty?
      array << list
    end

    array
  end

  def to_array
    self
  end

  def to_string
    if empty?
      '[]'
    else
      "[\n%s\n]" % map { |x| INDENT + x.to_string.lines.join(INDENT).utf8 }.join(",\n")
    end
  end
end