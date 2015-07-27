module OS
  module_function

  def name
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw|cygwin/
      :windows
    when /linux/
      :linux
    when /solaris/
      :solaris
    when /freebsd|openbsd|netbsd/
      :bsd
    when /darwin/
      :mac
    when /aix/
      :aix
    when /hpux/
      :hpux
    else
      RbConfig::CONFIG['host_os']
    end
  end

  def windows?
    name == :windows
  end

  def java?
    RUBY_PLATFORM =~ /java/
  end

  def x64?
    if $settings[:x64]
      return true
    end

    case RbConfig::CONFIG['host_cpu']
    when /_64$/
      true
    when /(i386|i686)/
      false
    else
      if java? and ENV_JAVA['sun.arch.data.model']
        ENV_JAVA['sun.arch.data.model'].to_i == 64
      else
        1.size == 8
      end
    end
  end

  def cpu_info
    info = {
      size:       1,
      speed:      nil,
      max_speed:  nil,
      usage:      nil
    }

    case name
    when :windows
      first = nil

      WIN32OLE.connect('winmgmts://').ExecQuery('select * from Win32_Processor').each do |x|
        if first.nil?
          if x.ole_respond_to? :NumberOfLogicalProcessors
            info[:size] = x.NumberOfLogicalProcessors.to_i
          end

          info[:speed] = x.CurrentClockSpeed.to_i
          info[:max_speed] = x.MaxClockSpeed.to_i

          first = x
        end

        info[:usage] ||= []
        info[:usage] << x.LoadPercentage.to_i
      end

      if not first.ole_respond_to? :NumberOfLogicalProcessors
        info[:size] = WIN32OLE.connect('winmgmts://').ExecQuery('select NumberOfProcessors from Win32_ComputerSystem').to_enum.first.NumberOfProcessors.to_i
      end
    when :linux
      info[:size] = `grep -c processor /proc/cpuinfo`.to_i
    when :solaris
      info[:size] = `psrinfo -p`.to_i
    when :bsd
      info[:size] = `sysctl -n hw.ncpu`.to_i
    when :mac
      if RbConfig::CONFIG['host_os'] =~ /darwin9/
        info[:size] = `hwprefs cpu_count`.to_i
      else
        if `which hwprefs` != ''
          info[:size] = `hwprefs thread_count`.to_i
        else
          info[:size] = `sysctl -n hw.ncpu`.to_i
        end
      end
    end

    if info[:usage].is_a? Array
      usage = 0

      info[:usage].each do |x|
        usage += x
      end

      if usage > 0
        usage = (usage.to_f / info[:usage].size).round
      end

      info[:usage] = usage
    end

    info
  end

  def memory_info
    info = {
      memory: 1,
      usage:  nil
    }

    case name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'
      info[:memory] = wmi.ExecQuery('select Capacity from Win32_PhysicalMemory').to_enum.first.Capacity.to_i / (1024 * 1024)
    when :linux
      info[:memory] = `grep -c MemTotal /proc/meminfo`.to_i / (1024 * 1024)
    when :solaris
    when :bsd
    when :mac
    end

    info
  end

  def processes
    info = {}

    case OS.name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'

      wmi.ExecQuery('select * from win32_process').each do |process|
        info[process.ProcessId] = {
          name:             process.Name.to_s.utf8.strip,
          pid:              process.ProcessId,
          parent_pid:       process.ParentProcessId,
          command_line:     process.CommandLine.to_s.utf8.strip,
          working_set_size: process.WorkingSetSize,
          creation_date:    process.CreationDate.to_s.utf8.strip,
          __process__:      process
        }
      end
    when :linux
      lines = `ps -eo pid,ppid,m_size,start_time,command`.lines
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, ppid, size, start, command = line.split /\s+/, 5

        info[pid.to_i] = {
          name:             File.basename(command.to_s.split(/\s/).first),
          pid:              pid.to_i,
          parent_pid:       ppid.to_i,
          command_line:     command.to_s,
          working_set_size: size.to_i,
          creation_date:    start.to_s,
          __process__:      nil
        }
      end

      lines = `ps -e`.lines.to_array
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, tty, time, cmd = line.split /\s+/, 4

        if info[pid.to_i].nil?
          next
        end

        info[pid.to_i][:name] = cmd.to_s
      end
    when :solaris
      lines = `ps -eo pid,ppid,rss,stime,args`.lines
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, ppid, size, start, command = line.split /\s+/, 5

        info[pid.to_i] = {
          name:             File.basename(command.to_s.split(/\s/).first),
          pid:              pid.to_i,
          parent_pid:       ppid.to_i,
          command_line:     command.to_s,
          working_set_size: size.to_i,
          creation_date:    start.to_s,
          __process__:      nil
        }
      end

      lines = `ps -e`.lines.to_array
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, tty, time, cmd = line.split /\s+/, 4

        if info[pid.to_i].nil?
          next
        end

        info[pid.to_i][:name] = cmd.to_s
      end
    end

    info
  end

  def os_info
    info = {}

    case OS.name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'

      wmi.ExecQuery('select * from win32_operatingsystem').each do |x|
        [
          'Caption',
          'CodeSet',
          'CountryCode',
          'CSDVersion',
          'CSName',
          'Name',
          'OSArchitecture',
          'OSLanguage',
          'RegisteredUser',
          'SerialNumber',
          'ServicePackMajorVersion',
          'ServicePackMinorVersion',
          'Version',
          'WindowsDirectory'
        ].each do |method_name|
          begin
            info[method_name.downcase.to_sym] = x.__send__(method_name).to_s.utf8.strip
          rescue
            info[method_name.downcase.to_sym] = nil
          end
        end

        info[:__os__] = x

        break
      end
    when :linux
    when :solaris
    end

    info
  end

  def process name, pid = nil
    if pid.nil?
      name = name.utf8.strip

      processes.each do |process_id, process_info|
        if process_info[:name] == name
          return process_info
        end
      end

      nil
    else
      processes[pid]
    end
  end

  def kill logger = nil, opt = {}
    status = true

    processes.each do |pid, info|
      name = info[:name]

      if block_given?
        if not yield pid, info
          next
        end
      else
        if opt.has_key? :pid and opt[:pid] != pid
          next
        end

        if opt.has_key? :name and opt[:name] != name
          next
        end
      end

      begin
        Process.kill :KILL, pid
      rescue
        if windows?
          if 0 != cmdline2e('TASKKILL /F /PID %s' % pid, logger)
            status = false
          end
        else
          status = false
        end
      end
    end

    status
  end

  def reboot sec = nil, logger = nil
    sec ||= 10

    if windows?
      cmdline = 'shutdown -f -r -t %d' % sec
    else
      cmdline = 'shutdown -r -t %d now' % sec
    end

    cmdline2e(cmdline, logger).zero?
  end

  def ldd file, logger = nil
    if windows?
      cmdline = '%s %s' % [File.cmdline(File.join(gem_dir('ruby-ext'), 'bin/ldd')), File.cmdline(file)]
    else
      cmdline = 'ldd %s' % File.cmdline(file)
    end

    depends = []

    if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
        if line =~ /=>/
          depends << $`.strip
        end
      end

      depends
    else
      nil
    end
  end
end

module OS
  module_function

  def expandname filename, cmdline = false, shell = false
    if cmdline
      file, args = File.cmdline_split filename
    else
      file = filename.strip
      args = nil
    end

    dirname = File.dirname file
    basename = File.basename file
    extname = File.extname(file).downcase

    if file == basename
      dirname = nil
    end

    if windows?
      case extname
      when '.sh'
        basename = '%s.bat' % File.basename(basename, '.*')
      when '.so'
        if basename =~ /^lib(.*)\.so$/
          basename = '%s.dll' % $1
        else
          basename = '%s.dll' % File.basename(basename, '.*')
        end
      when ''
        if shell and not cmdline
          basename += '.bat'
        end
      end
    else
      case extname
      when '.bat'
        basename = '%s.sh' % File.basename(basename, '.*')
      when '.dll', '.lib'
        basename = 'lib%s.so' % File.basename(basename, '.*')
      when '.exe'
        basename = File.basename basename, '.*'
      when ''
        if shell and not cmdline
          basename += '.sh'
        end
      end
    end

    if dirname
      file = File.join dirname, basename
    else
      file = basename
    end

    if args.nil?
      file
    else
      '%s %s' % [File.cmdline(file), args]
    end
  end

  def shell filename, cmdline = false
    filename = filename.strip

    if windows?
      if filename.start_with? 'call '
        filename
      else
        if cmdline
          'call %s' % filename
        else
          'call %s' % File.cmdline(filename)
        end
      end
    else
      file = File.cmdline_split(filename).first.to_s

      if File.extname(file) == '.sh'
        if cmdline
          'sh %s' % filename
        else
          'sh %s' % File.cmdline(filename)
        end
      else
        if File.dirname(file) == Dir.pwd.utf8 and not filename.start_with? './'
          filename = './%s' % filename
        end

        if cmdline
          filename
        else
          File.cmdline filename
        end
      end
    end
  end

  def chdir home, os = nil
    os ||= name

    if os == :windows
      'cd /d %s' % File.cmdline(home, true, os)
    else
      'cd %s' % File.cmdline(home, true, os)
    end
  end

  def rake cmdline, os = nil
    os ||= name

    if os == :windows
      cmdline = 'call rake %s' % cmdline
    else
      cmdline = 'rake %s' % cmdline
    end

    if $settings[:rake_trace]
      cmdline += ' --trace'
    end

    cmdline
  end
end

module OS
  module_function

  def tempdir
    if windows?
      'c:/tmp'
    else
      '/tmp'
    end
  end
end

module Colorize
  COLORS = {
    black:      30,
    red:        31,
    green:      32,
    yellow:     33,
    blue:       34,
    magenta:    35,
    cyan:       36,
    white:      37
  }

  EXTRAS = {
    clear:      0,
    highlight:  1,
    underline:  4,
    shine:      5,
    reversed:   7,
    invisible:  8
  }

  def colorize string, fore = nil, back = nil, extras = nil
    colorize = []

    if fore
      if COLORS.has_key? fore.to_sym
        colorize << COLORS[fore.to_sym]
      end
    end

    if back
      if COLORS.has_key? back.to_sym
        colorize << COLORS[back.to_sym] + 10
      end
    end

    if extras
      extras.split(',').each do |x|
        if EXTRAS.has_key? x.to_sym
          colorize << EXTRAS[x.to_sym]
        end
      end
    end

    if not string.empty? and not colorize.empty?
      "\e[%sm%s\e[0m" % [colorize.join(';'), string]
    else
      string
    end
  end

  def uncolorize string
    string.gsub /\e\[[\d;]+m/, ''
  end

  def write string
    strs = []
    string = string.to_s

    while not string.empty?
      if string =~ /<\s*font\s*(.*?)\s*>(.*?)<\/\s*font\s*>/
        if not $`.empty?
          strs << [$`, nil]
        end

        strs << [$2, $1]
      else
        strs << [string, nil]

        break
      end

      string = $'
    end

    size = 0

    strs.each do |str, args|
      fore = nil
      back = nil
      extras = []

      if args
        args.split(';').each do |x|
          name, params = x.split ':', 2

          if params
            case name
            when 'color'
              fore = params
            when 'bgcolor'
              back = params
            end
          else
            extras << name
          end
        end
      end

      __write__ colorize(str, fore, back, extras.join(',')).locale
      size += str.size
    end

    size
  end
end

class << STDOUT
  alias __write__ write

  include Colorize
end

class << STDERR
  alias __write__ write

  include Colorize
end

autoload :WIN32OLE, 'win32ole'