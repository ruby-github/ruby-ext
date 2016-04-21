require 'fileutils'
require 'tmpdir'
require 'pathname'

class File
  class << self
    alias __expand_path__ expand_path
    alias __open__ open
  end

  def self.expand_path filename, dir = nil
    if not dir.nil?
      dir = dir.to_s.utf8.strip
    end

    if not filename.nil?
      filename = filename.to_s.utf8.strip
    end

    if filename =~ /^[a-zA-Z]+:[\/\\]{2,}/
      filename.gsub '\\', File::SEPARATOR
    else
      __expand_path__(filename, dir).utf8
    end
  end

  def self.open filename, mode = 'r', *args
    if args.last.is_a? Hash
      options = args.pop
    else
      options = {}
    end

    create = false

    if mode.is_a? Integer
      if (mode & File::CREAT) == File::CREAT
        create = true
      end
    else
      if not mode.strip.empty? and not mode.include? 'r'
        create = true
      end
    end

    filename = expand_path filename

    if not File.directory? File.dirname(filename) and create
      FileUtils.mkdir_p File.dirname(filename)
    end

    if block_given?
      __open__ filename, mode, args.first, options do |file|
        yield file
      end
    else
      __open__ filename, mode, args.first, options
    end
  end

  def self.normalize filename
    if filename.empty?
      ''
    else
      filename = filename.gsub '\\', '/'

      if relative? filename
        relative_path filename
      else
        expand_path filename
      end
    end
  end

  def self.relative_path filename, dir = nil
    if dir.nil?
      dir = Dir.pwd
    end

    filename = expand_path filename
    dir = expand_path dir

    if not dir.end_with? '/'
      dir += '/'
    end

    begin
      Pathname.new(filename.locale).relative_path_from(Pathname.new(dir.locale)).to_s.utf8
    rescue
      filename
    end
  end

  def self.absolute? filename
    not relative? filename
  end

  def self.relative? filename
    Pathname.new(filename.locale.strip).relative?
  end

  def self.lock filename, mode = 'r+'
    filename = expand_path filename

    if not file? filename
      open filename, 'w' do |file|
      end
    end

    open filename, mode do |file|
      file.flock File::LOCK_EX

      yield file
    end
  end

  class << self
    alias absolute_path expand_path
  end
end

class File
  def self.os filename, osname = nil
    filename = normalize filename
    osname ||= OS.name

    if osname.to_s == 'windows'
      if filename !~ /^[a-zA-Z]+:[\/\\]{2,}/
        filename.gsub! File::SEPARATOR, '\\'
      end
    end

    filename
  end

  def self.cmdline filename, force = true, osname = nil
    if force
      filename = os filename, osname
    end

    if filename =~ /\s/ and not filename.include? '"'
      '"%s"' % filename
    else
      filename
    end
  end

  def self.expands xpath
    xpath = normalize xpath

    if File.exist? xpath
      [
        xpath
      ]
    else
      if File::FNM_SYSCASE.nonzero?
        Dir.glob(xpath, File::FNM_CASEFOLD).sort.utf8
      else
        Dir.glob(xpath).sort.utf8
      end
    end
  end

  def self.root filename
    filename = expand_path filename

    if filename =~ /^(\w+:\/\/+[^\/\\]+)[\/\\]/
      $1
    else
      loop do
        dir, name = split filename

        if dir == '.'
          if not filename.start_with? './'
            return name
          end
        end

        if dir == filename
          return dir
        end

        filename = dir
      end
    end
  end

  def self.pattern_split xpath
    xpath = normalize xpath

    if not File.exist? xpath
      if xpath =~ /\*|\?|\[.+\]|\{.+\}/
        dir = $`

        if dir.empty?
          dir = '.'
        else
          if dir.end_with? '/'
            dir.chop!
          else
            dir = dirname dir
          end

          xpath = xpath[dir.size + 1..-1]
        end

        [
          dir, xpath
        ]
      else
        [
          nil, xpath
        ]
      end
    else
      [
        nil, xpath
      ]
    end
  end

  def self.cmdline_split cmdline
    filename = ''
    args = nil

    cmdline = cmdline.utf8.strip
    quotation = nil
    index = 0

    cmdline.each_char do |ch|
      if quotation.nil?
        if ['"', "'"].include? ch
          quotation = ch
        else
          if [' ', '\t', '\r', '\n', '\f'].include? ch
            args = cmdline[index..-1].strip

            break
          else
            filename << ch
          end
        end
      else
        if ['"', "'"].include? ch
          quotation = nil
        else
          filename << ch
        end
      end

      index += 1
    end

    [
      normalize(filename), args
    ]
  end

  def self.include? a, b
    a = expand_path a
    b = expand_path b

    if File::FNM_SYSCASE.nonzero?
      a = a.downcase
      b = b.downcase
    end

    a == b or b.start_with? a + File::SEPARATOR
  end

  def self.same_path? a, b, expand = false
    if expand
      a = expand_path a
      b = expand_path b
    else
      a = normalize a
      b = normalize b
    end

    if File::FNM_SYSCASE.nonzero?
      a.casecmp(b).zero?
    else
      a == b
    end
  end

  def self.local_path? filename
    filename = expand_path filename

    if OS.windows?
      if filename =~ /^[a-zA-Z]:\//
        true
      else
        false
      end
    else
      if filename =~ /^\/\w+/
        true
      else
        false
      end
    end
  end
end

class File
  def self.tmpname
    '%s%04d' % [Time.now.strftime('%Y%m%d%H%M%S'), rand(1000)]
  end

  def self.tmpdir dir = nil, prefix = nil, logger = nil
    dirname = File.join dir || Dir.tmpdir, tmpname

    if not prefix.nil?
      dirname = File.join File.dirname(dirname), '%s_%s' % [prefix, File.basename(dirname)]
    end

    if block_given?
      begin
        mkdir dirname, logger
        yield dirname
      ensure
        delete dirname, logger
      end
    else
      dirname
    end
  end
end

class File
  def self.mkdir paths, logger = nil
    dirs = []

    paths.to_array.each do |dir|
      dir = normalize dir

      if not File.directory? dir
        dirs << dir
      end
    end

    dirs.uniq!

    status = true

    if not dirs.empty?
      if logger
        logger.cmdline 'mkdir'
      end

      mkdir_fails = []

      dirs.each do |dir|
        if logger
          logger.debug dir
        end

        begin
          FileUtils.mkdir_p dir
        rescue
          if logger
            logger.exception $!
          end

          status = false
        end

        if not File.directory? dir
          mkdir_fails << dir
        end
      end

      if not mkdir_fails.empty?
        sleep 3

        begin
          mkdir_fails.each do |dir|
            if not File.directory? dir
              raise Errno::ENOENT, dir
            end
          end
        rescue
          if logger
            logger.exception $!
          end

          status = false
        end
      end
    end

    status
  end

  def self.copy src, dest, logger = nil, opt = nil
    src = normalize src
    dest = normalize dest

    if logger
      logger.cmdline 'copy %s, %s' % [src, dest]
    end

    copy_file src, dest, logger, opt do |src_file, dest_file|
      if block_given?
        yield src_file, dest_file
      else
        [
          src_file, dest_file
        ]
      end
    end
  end

  def self.move src, dest, logger = nil, force = false
    src = normalize src
    dest = normalize dest

    if logger
      logger.cmdline 'move %s, %s' % [src, dest]
    end

    if same_path? root(src), root(dest)
      move_file src, dest, logger
    else
      if force
        copy_file src, dest, logger and delete_file src, logger
      else
        copy_file src, dest, logger
      end
    end
  end

  def self.delete paths, logger = nil
    names = []

    paths.to_array.each do |name|
      name = normalize name

      if File.exist? name
        names << name
      end
    end

    names.uniq!

    status = true

    if not names.empty?
      if logger
        logger.cmdline 'delete'
      end

      names.each do |name|
        if not delete_file name, logger do |file|
            if block_given?
              yield file
            else
              file
            end
          end

          status = false
        end
      end
    end

    status
  end

  def self.copy_file src, dest, logger = nil, opt = nil
    if same_path? src, dest, true
      return true
    end

    map = copy_map src, dest do |src_file, dest_file|
      if block_given?
        yield src_file, dest_file
      else
        [
          src_file, dest_file
        ]
      end
    end

    preserve = true

    if not opt.nil?
      preserve = opt[:preserve].to_s.boolean true
    end

    status = true

    map.each do |dest_file, src_file|
      if logger
        logger.debug '%s, %s' % [src_file, dest_file]
      end

      begin
        case
        when file?(src_file)
          if not directory? dirname(dest_file)
            FileUtils.mkdir_p dirname(dest_file)
          end

          begin
            FileUtils.copy_file src_file, dest_file, preserve
          rescue
            FileUtils.copy_file src_file, dest_file, false

            if preserve
              File.utime Time.now, Time.now, dest_file
            end
          end
        when directory?(src_file)
          if not directory? dest_file
            FileUtils.mkdir_p dest_file
          end
        else
          raise Errno::ENOENT, src_file
        end
      rescue
        if logger
          logger.exception $!
        end

        status = false
      end
    end

    status
  end

  def self.move_file src, dest, logger = nil
    if same_path? src, dest, true
      return true
    end

    src = normalize src
    dest = normalize dest

    map = {}
    dir, pattern = pattern_split src

    if dir
      if directory? dir
        Dir.chdir dir do
          expands(pattern).each do |file|
            src_file = join dir, file
            dest_file = join dest, file

            map[src_file] = dest_file
          end
        end
      end
    else
      map[src] = dest
    end

    status = true

    map.each do |src_file, dest_file|
      if file? src_file or not exist? dest_file
        if logger
          logger.debug '%s, %s' % [src_file, dest_file]
        end

        begin
          if not directory? dirname(dest_file)
            FileUtils.mkdir_p dirname(dest_file)
          end

          FileUtils.move src_file, dest_file
        rescue
          exception = $!

          if not copy_file src_file, dest_file or not delete_file src_file
            if logger
              logger.exception exception
            end

            status = false
          end
        end
      else
        if copy_file src_file, dest_file, logger
          if not delete_file src_file, logger
            status = false
          end
        else
          status = false
        end
      end
    end

    status
  end

  def self.delete_file xpath, logger = nil
    delete_fails = []

    expands(xpath).each do |path|
      list = []

      if directory? path
        list += expands(join(path, '**/*')).reverse
      end

      list << path

      list.each do |name|
        if block_given?
          name = yield name
        end

        if name.nil?
          next
        end

        if logger
          logger.debug name
        end

        FileUtils.rm_rf name

        if exist? name
          delete_fails << name
        end
      end
    end

    status = true

    if not delete_fails.empty?
      sleep 5

      begin
        delete_fails.each do |name|
          if exist? name
            raise Errno::EACCES, name
          end
        end
      rescue
        if logger
          logger.exception $!
        end

        status = false
      end
    end

    status
  end

  def self.copy_map src, dest
    src = normalize src

    if dest.nil?
      dest = '.'
    else
      dest = normalize dest
    end

    map = {}
    dir, pattern = pattern_split src

    if dir
      if directory? dir
        list = []

        Dir.chdir dir do
          expands(pattern).each do |file|
            list << file

            if directory? file
              list += expands join(file, '**/*')
            end
          end
        end

        list.each do |file|
          src_file = join dir, file
          dest_file = join dest, file

          if block_given?
            src_file, dest_file = yield src_file, dest_file

            if src_file.nil?
              next
            end
          end

          map[dest_file] = src_file
        end
      end
    else
      if block_given?
        src, dest = yield src, dest

        if not src.nil?
          map[dest] = src
        end
      else
        map[dest] = src
      end

      if directory? src
        list = []

        Dir.chdir src do
          list += expands '**/*'
        end

        list.each do |file|
          src_file = join src, file
          dest_file = join dest, file

          if block_given?
            src_file, dest_file = yield src_file, dest_file

            if src_file.nil?
              next
            end
          end

          map[dest_file] = src_file
        end
      end
    end

    map
  end

  class << self
    private :copy_file, :move_file, :delete_file
  end
end

class Pathname
  private

  def chop_basename path
    base = File.basename path

    if /\A#{SEPARATOR_PAT}?\z/o =~ base
      return nil
    else
      return path[0, path.rindex(base) || 0], base
    end
  end
end