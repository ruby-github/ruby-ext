class Object
  alias __clone__ clone
  alias __dup__ dup

  def clone
    begin
      __clone__
    rescue
      self
    end
  end

  def dup
    begin
      __dup__
    rescue
      self
    end
  end
end

class Object
  def dclone
    clone
  end

  def utf8
    dclone.utf8!
  end

  def utf8!
    instance_variables.each do |x|
      instance_variable_set x, instance_variable_get(x).utf8
    end

    self
  end

  def locale
    dclone.locale!
  end

  def locale!
    instance_variables.each do |x|
      instance_variable_set x, instance_variable_get(x).locale
    end

    self
  end

  def env envs, logger = nil, opt = {}
    hash = {}

    ENV.each do |k, v|
      if not File::FNM_SYSCASE.zero?
        k = k.upcase
      end

      hash[k] = v
    end

    hash.merge! opt

    if logger
      logger.cmdline 'SET ENV'
    end

    envs.each do |k, v|
      if not File::FNM_SYSCASE.zero?
        k = k.upcase
      end

      if not v.nil?
        v = v.to_s.vars hash
      end

      ENV[k] = v

      if logger
        if v.nil?
          logger.debug 'SET %s = nil' % k
        else
          logger.debug 'SET %s = %s' % [k, v]
        end
      end

      hash[k] = v
    end

    true
  end

  def gem_dir name = nil, version = nil
    if name.nil?
      File.join Gem.dir, 'gems'
    else
      dirs = []

      Dir.glob(File.join(Gem.dir, 'gems', '%s*' % name)).each do |x|
        if not version.nil?
          if File.basename(x) !~ /^#{name}-[0-9.]+$/
            next
          end
        end

        dirs << x
      end

      dirs.last
    end
  end

  def to_array
    [
      self
    ]
  end

  def to_string
    to_s
  end
end

INDENT = ' ' * 2