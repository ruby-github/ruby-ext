require 'pathname'

class Pathname
  private

  def cleanpath_aggressive
    path = @path

    names = []
    pre = path.gsub '\\', File::SEPARATOR

    loop do
      if pre =~ /^\/{2,}/ or pre =~ /^[a-zA-Z]+:\/{2,}[\w.]+(:\d+)?\/?$/
        break
      end

      r = chop_basename pre

      if r.nil?
        break
      end

      pre, base = r

      case base
      when '.'
      when '..'
        names.unshift base
      else
        if names[0] == '..'
          names.shift
        else
          names.unshift base
        end
      end

      if pre.empty?
        break
      end
    end

    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      while names[0] == '..'
        names.shift
      end
    end

    self.class.new prepend_prefix(pre, File.__join__(names))
  end

  def cleanpath_conservative
    path = @path

    names = []
    pre = path.gsub '\\', File::SEPARATOR

    while r = chop_basename(pre)
      pre, base = r

      if base != '.'
        names.unshift base
      end

      if pre.empty?
        break
      end
    end

    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      while names[0] == '..'
        names.shift
      end
    end

    if names.empty?
      self.class.new File.dirname(pre)
    else
      if names.last != '..' && File.basename(path) == '.'
        names << '.'
      end

      __path__ = prepend_prefix pre, File.__join__(names)

      if /\A(?:\.|\.\.)\z/ !~ names.last && has_trailing_separator?(path)
        self.class.new add_trailing_separator(__path__)
      else
        self.class.new __path__
      end
    end
  end

  def prepend_prefix prefix, relpath
    if prefix =~ /\/{2,}$/
      prefix = $`
    end

    paths = [
      prefix, relpath.chomp(File::SEPARATOR)
    ]

    paths.delete ''
    File.__join__ paths
  end

  def chop_basename path
    base = File.basename path

    if /\A#{SEPARATOR_PAT}?\z/o =~ base
      nil
    else
      index = path.rindex base

      if index.nil?
        nil
      else
        [path[0, index], base]
      end
    end
  end
end