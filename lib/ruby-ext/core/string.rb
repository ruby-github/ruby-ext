class String
  def utf8
    dup.utf8!
  end

  def utf8!
    begin
      encoding = encoding?

      if encoding.nil?
        force_encoding 'UTF-8'
      else
        force_encoding encoding
      end

      if self.encoding != Encoding::UTF_8
        encode! 'UTF-8', invalid: :replace, undef: :replace, replace: ''
      end
    rescue
      self.clear
    end

    self
  end

  def locale
    dup.locale!
  end

  def locale!
    begin
      encoding = encoding?

      if encoding.nil?
        force_encoding 'UTF-8'
      else
        force_encoding encoding
      end

      if self.encoding != Encoding.default_external
        encode! 'locale', invalid: :replace, undef: :replace, replace: ''
      end
    rescue
      self.clear
    end

    self
  end

  def encoding?
    if encoding != Encoding::ASCII_8BIT and valid_encoding?
      encoding.to_s
    else
      dup = self.dup

      (['utf-8', 'locale', 'external', 'filesystem'] + Encoding.name_list).uniq.each do |name|
        if name == 'ASCII-8BIT'
          next
        end

        if dup.force_encoding(name).valid_encoding?
          return name
        end
      end

      nil
    end
  end

  def boolean default = nil
    case downcase.strip
    when 'true'
      true
    when 'false'
      false
    when 'nil', 'null'
      nil
    else
      if default.nil?
        self
      else
        default
      end
    end
  end

  def int
    bytes.map { |x| format '%03d' % x }.join
  end

  def nil
    str = strip

    if str.empty? or str.downcase == 'nil' or str.downcase == 'null'
      nil
    else
      str
    end
  end

  def escapes
    gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&apos;')
  end

  def widthsize
    size = 0

    each_char do |ch|
      size += 1

      if ch.bytesize > 1
        size += 1
      end
    end

    size
  end

  def width_left size
    str = ''

    cur_size = 0

    each_char do |ch|
      cur_size += 1

      if ch.bytesize > 1
        cur_size += 1
      end

      if cur_size > size
        break
      end

      str << ch
    end

    str
  end

  def wrap size = 79
    wrap_lines = []

    lines.each do |line|
      cur_line = ''

      line.each_char do |c|
        if cur_line.bytesize + c.bytesize > size
          wrap_lines << cur_line
          cur_line = nil
        end

        if cur_line.nil?
          cur_line = c
        else
          cur_line << c
        end
      end

      if not cur_line.nil?
        wrap_lines << cur_line
      end
    end

    wrap_lines
  end

  def vars opt = {}
    if self =~ /\$(\(([\w.:-]+)\)|{([\w.:-]+)})/
      val = $1[1..-2]

      if opt.has_key? val or opt.has_key? val.to_sym
        if opt.has_key? val
          str = opt[val]
        else
          str = opt[val.to_sym]
        end
      else
        str = $&
      end

      '%s%s%s' % [$`, str, $'.vars(opt)]
    else
      self
    end
  end

  def strip_lines prefix = nil
    lines = []
    size = nil

    self.lines.each do |line|
      line.rstrip!

      if line.empty?
        lines << nil

        next
      end

      cur_line = line.strip

      if size.nil?
        lines << cur_line
        size = line.size - cur_line.size
      else
        lines << ' ' * [0, line.size - cur_line.size - size].max + cur_line
      end
    end

    lines.join "\n%s" % prefix
  end
end