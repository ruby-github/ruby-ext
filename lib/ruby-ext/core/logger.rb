require 'logger'

class Logger
  class Formatter
    def initialize
      @datetime_format = '%Y-%m-%d %H:%M:%S'
    end

    def call severity, time, progname, msg
      if progname.nil?
        progname_dup = nil
        size = 0
      else
        progname_dup = '[%s] ' % progname
        size = progname.widthsize + 3
      end

      str = msg2str(msg).locale.gsub /\e\[[\d;]+m/, ''

      case severity
      when 'DEBUG'
        if msg.is_a? Exception
          "%s%s%s: %s\n" % [INDENT, progname_dup, 'exception', str]
        else
          "%s%s%s\n" % [INDENT, progname_dup, str]
        end
      when 'PUTS'
        if msg.is_a? Exception
          "%s %s%s: %s\n" % [format_datetime(time), progname_dup, 'exception', str]
        else
          "%s %s%s\n" % [format_datetime(time), progname_dup, str]
        end
      when 'CMDLINE'
        if str =~ /\s*\[\s*(OK|NG)\s*\]\s*$/
          if $`.empty?
            str = '%s' % progname_dup
          else
            time = format_datetime time
            str = '%s %s$ %s' % [time, progname_dup, $`]
          end

          size += str.widthsize

          if size > 70
            "%s\n%-71s [ %s ]\n" % [str, '', $1]
          else
            "%s%s [ %s ]\n" % [str, ' ' * (71 - size), $1]
          end
        else
          "%s %s$ %s\n" % [format_datetime(time), progname_dup, str]
        end
      else
        if severity
          "%s %s[%s] %s\n" % [format_datetime(time), progname_dup, severity, str]
        else
          '%s' % str
        end
      end
    end
  end

  class ColorizeFormatter < Formatter
    def call severity, time, progname, msg
      if progname.nil?
        progname_dup = nil
        size = 0
      else
        progname_dup = '<font color:%s;highlight>[%s]</font> ' % [:cyan, progname]
        size = progname.widthsize + 3
      end

      str = msg2str(msg).locale

      if msg.is_a? Exception and severity != 'CMDLINE'
        if str =~ /\(\w+\)/
          str = '%s<font color:%s>%s</font>%s' % [$`, :cyan, $&, $']
        end
      end

      case severity
      when 'DEBUG'
        if msg.is_a? Exception
          "%s%s<font color:%s;highlight>%s:</font> %s\n" % [INDENT, progname_dup, :red, 'exception', str]
        else
          "%s%s%s\n" % [INDENT, progname_dup, str]
        end
      when 'PUTS'
        if msg.is_a? Exception
          "%s%s<font color:%s;highlight>%s:</font> %s\n" % [format_datetime(time), progname_dup, :red, 'exception', str]
        else
          "%s%s%s\n" % [format_datetime(time), progname_dup, str]
        end
      when 'CMDLINE'
        if str =~ /\s*\[\s*(OK|NG)\s*\]\s*$/
          if $`.empty?
            str = '%s' % progname_dup
            size += 0
          else
            time = format_datetime time
            str = "<font color:%s;highlight>%s</font> %s<font color:%s;highlight>$</font> <font color:%s;highlight>%s</font>" % [:green, time, progname_dup, :red, :blue, $`]
            size += ('%s $ %s' % [time, $`]).widthsize
          end

          if $1 == 'OK'
            colorize = :green
          else
            colorize = :red
          end

          if size > 70
            "%s\n%-71s [ <font color:%s;highlight>%s</font> ]\n" % [str, '', colorize, $1]
          else
            "%s%s [ <font color:%s;highlight>%s</font> ]\n" % [str, ' ' * (71 - size), colorize, $1]
          end
        else
          "<font color:%s;highlight>%s</font> %s<font color:%s;highlight>$</font> <font color:%s;highlight>%s</font>\n" % [:green, format_datetime(time), progname_dup, :red, :blue, str]
        end
      when 'CHECK', 'INFO', 'WARN', 'EXCEPTION', 'ERROR', 'FATAL', 'ANY'
        case severity
        when 'CHECK', 'INFO'
          colorize = :green
        when 'WARN'
          colorize = :yellow
        when 'EXCEPTION', 'ERROR', 'FATAL'
          colorize = :red
        else
          colorize = :cyan
        end

        "%s %s<font color:%s;highlight>[%s]</font> %s\n" % [format_datetime(time), progname_dup, colorize, severity, str]
      else
        super
      end
    end
  end

  class LogDevice
    def set_shift shift_age = nil, shift_size = nil
      if @filename
        if shift_age
          @shift_age = shift_age
        end

        if shift_size
          @shift_size = shift_size
        end
      end
    end

    private

    def create_logfile filename
      logdev = File.open filename, File::WRONLY | File::APPEND | File::CREAT
      logdev.sync = true
      add_log_header(logdev)
      logdev
    end
  end

  module Severity
    [:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :UNKNOWN].each do |x|
      remove_const x
    end

    DEBUG     = 0
    PUTS      = 1
    CHECK     = 2
    CMDLINE   = 3
    INFO      = 4
    WARN      = 5
    EXCEPTION = 6
    ERROR     = 7
    FATAL     = 8
    UNKNOWN   = 9
  end
  include Severity

  def puts?
    @level <= PUTS
  end

  def check?
    @level <= CHECK
  end

  def cmdline?
    @level <= CMDLINE
  end

  def exception?
    @level <= EXCEPTION
  end

  def puts progname = nil, &block
    add PUTS, nil, progname, &block
  end

  def check progname = nil, &block
    add CHECK, nil, progname, &block
  end

  def cmdline progname = nil, &block
    add CMDLINE, nil, progname, &block
  end

  def exception progname = nil, &block
    add EXCEPTION, nil, progname, &block
  end

  def self.cmdline cmdline = nil, logger = nil
    if cmdline
      logger.cmdline cmdline
    end

    status = true

    if block_given?
      status = yield
    end

    if status
      logger.cmdline '[OK]'

      true
    else
      logger.cmdline '[NG]'

      false
    end
  end

  remove_const :SEV_LABEL
  SEV_LABEL = %w(DEBUG PUTS CHECK CMDLINE INFO WARN EXCEPTION ERROR FATAL ANY)
end

class Logger
  attr_reader :logdev

  def initialize logdev = nil, shift_age = 0, shift_size = nil, level = DEBUG
    @progname = nil
    @level = DEBUG
    @default_formatter = Formatter.new
    @formatter = nil
    @logdev = {}

    add_logdev logdev, level, shift_age, shift_size
  end

  def add_logdev logdev, level = DEBUG, shift_age = 0, shift_size = nil
    logdev ||= STDOUT

    if not logdev.respond_to? :write or not logdev.respond_to? :close
      logdev = File.expand_path logdev
    end

    device = nil

    @logdev.each do |dev, dev_level|
      if dev.filename
        if dev.filename == logdev
          device = dev
        end
      else
        if dev.dev == logdev
          device = dev
        end
      end

      if device
        break
      end
    end

    if device
      device.set_shift shift_age, shift_size
    else
      device = LogDevice.new logdev, shift_age: shift_age, shift_size: shift_size
    end

    @logdev[device] = level
  end

  def add severity, message = nil, progname = nil, &block
    severity ||= UNKNOWN

    if severity < @level
      return true
    end

    progname ||= @progname

    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end

    if message.is_a? Exception
      if not $settings[:exception_trace]
        message = message.dclone
        message.set_backtrace nil
      end
    end

    @logdev.each do |dev, dev_level|
      if severity < dev_level
        next
      end

      if $settings[:colorize] and dev.dev.respond_to? :colorize
        formatter = ColorizeFormatter.new
      else
        formatter = @default_formatter
      end

      dev.write format_message(formatter, format_severity(severity), Time.now, progname, message)

      if severity == CMDLINE and DEBUG >= dev_level
        if message !~ /^\s*\[\s*(OK|NG)\s*\]\s*$/
          dev.write format_message(formatter, format_severity(DEBUG), Time.now, progname, '(in %s)' % Dir.pwd.utf8)
        end
      end
    end

    true
  end
  alias log add

  def << message, &block
    if message.is_a? Exception
      if not $settings[:exception_trace]
        message = message.dclone
        message.set_backtrace nil
      end
    end

    @logdev.each do |dev, dev_level|
      if $settings[:colorize] and dev.dev.respond_to? :colorize
        formatter = ColorizeFormatter.new
      else
        formatter = @default_formatter
      end

      if block_given?
        str = yield dev.dev, message
      else
        str = format_message formatter, nil, nil, nil, message
      end

      dev.write str
    end
  end

  def flush
    @logdev.each do |dev, dev_level|
      if dev.dev.respond_to? :flush
        dev.dev.flush
      end
    end
  end

  def close
    @logdev.each do |dev, dev_level|
      if not [STDOUT, STDERR].include? dev.dev
        dev.close
      end
    end
  end

  private

  def format_message formatter, severity, datetime, progname, msg
    (@formatter || formatter).call severity, datetime, progname, msg
  end
end