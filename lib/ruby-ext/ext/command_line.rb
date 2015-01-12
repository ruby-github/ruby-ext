require 'json'
require 'open3'

RUBYSCRIPT =<<-STR
  require 'json'

  def script args = nil
    @@script@@
  end

  if $0 == __FILE__
    args = nil

    if File.file? 'args.json'
      args = JSON.load IO.read('args.json')
    end

    json = script(args).to_json

    File.open 'json.json', 'w:utf-8' do |file|
      file.puts json
    end
  end
STR

module CommandLine
  module_function

  @@max = 0
  @@lock = Monitor.new

  def cmdline cmdline, logger = nil, opt = {}
    if opt[:env]
      env opt[:env], logger
    end

    if opt[:home]
      begin
        File.tmpdir do |tmpdir|
          name = OS.expandname File.join(tmpdir, File.basename(tmpdir)), false, true

          File.open name, 'w' do |file|
            file.puts OS.chdir(opt[:home])
            file.puts OS.expandname(cmdline, true)
          end

          cmdline = OS.shell name

          if logger
            logger.cmdline cmdline
          end

          stdin, stdout, stderr, wait_thr = Open3.popen3 cmdline.locale

          opt.each do |k, v|
            wait_thr[k] = v
          end

          cmdline_exec stdin, [stdout, stderr], wait_thr, logger do |line, io|
            if block_given?
              yield line, stdin, io == stdout, wait_thr
            end
          end
        end
      rescue
        if logger
          logger.exception $!
          logger.debug 'exit status: %s' % $!
        end

        false
      end
    else
      cmdline = OS.expandname cmdline, true

      if File.file? File.cmdline_split(cmdline).first
        cmdline = OS.shell cmdline, true
      end

      if logger
        logger.cmdline cmdline
      end

      begin
        stdin, stdout, stderr, wait_thr = Open3.popen3 cmdline.locale

        opt.each do |k, v|
          wait_thr[k] = v
        end

        cmdline_exec stdin, [stdout, stderr], wait_thr, logger do |line, io|
          if block_given?
            yield line, stdin, io == stdout, wait_thr
          end
        end
      rescue
        if logger
          logger.exception $!
          logger.debug 'exit status: %s' % $!
        end

        false
      end
    end
  end

  def cmdline2e cmdline, logger = nil, opt = {}
    if opt[:env]
      env opt[:env], logger
    end

    if opt[:home]
      begin
        File.tmpdir do |tmpdir|
          name = OS.expandname File.join(tmpdir, File.basename(tmpdir)), false, true

          File.open name, 'w' do |file|
            file.puts OS.chdir(opt[:home])
            file.puts OS.expandname(cmdline, true)
          end

          cmdline = OS.shell name

          if logger
            logger.cmdline cmdline
          end

          stdin, stdout_and_stderr, wait_thr = Open3.popen2e cmdline.locale

          opt.each do |k, v|
            wait_thr[k] = v
          end

          cmdline_exec stdin, stdout_and_stderr, wait_thr, logger do |line, io|
            if block_given?
              yield line, stdin, wait_thr
            end
          end
        end
      rescue
        if logger
          logger.exception $!
          logger.debug 'exit status: %s' % $!
        end

        false
      end
    else
      cmdline = OS.expandname cmdline, true

      if File.file? File.cmdline_split(cmdline).first
        cmdline = OS.shell cmdline, true
      end

      if logger
        logger.cmdline cmdline
      end

      begin
        stdin, stdout_and_stderr, wait_thr = Open3.popen2e cmdline.locale

        opt.each do |k, v|
          wait_thr[k] = v
        end

        cmdline_exec stdin, stdout_and_stderr, wait_thr, logger do |line, io|
          if block_given?
            yield line, stdin, wait_thr
          end
        end
      rescue
        if logger
          logger.exception $!
          logger.debug 'exit status: %s' % $!
        end

        false
      end
    end
  end

  def rubyscript string, logger = nil, opt = {}
    if opt[:env]
      env opt[:env], logger
    end

    begin
      File.tmpdir opt[:home], opt[:prefix], logger do |tmpdir|
        Dir.chdir tmpdir do
          if opt[:args]
            File.open 'args.json', 'w:utf-8' do |file|
              file << opt[:args].to_json
            end
          end

          str = RUBYSCRIPT.strip_lines
          str.gsub! '@@script@@', string.utf8.strip_lines(' ' * 2).strip

          File.open 'script.rb', 'w:utf-8' do |file|
            file << str
          end

          cmdline = 'ruby script.rb'

          if logger
            logger.cmdline cmdline
          end

          stdin, stdout_and_stderr, wait_thr = Open3.popen2e cmdline.locale

          opt.each do |k, v|
            wait_thr[k] = v
          end

          cmdline_exec stdin, stdout_and_stderr, wait_thr, logger do |line, io|
            if block_given?
              yield line, stdin, wait_thr
            end
          end

          if File.file? 'json.json'
            JSON.load IO.read('json.json', encoding: 'utf-8')
          else
            false
          end
        end
      end
    rescue
      if logger
        logger.exception $!
        logger.debug 'exit status: %s' % $!
      end

      false
    end
  end

  def parallel cmdlines, logger = nil, max = nil, &block
    if max.nil?
      max = OS.cpu_info[:size]
    else
      max = max.to_i
    end

    status = true

    cmdlines.to_array.each do |cmdline|
      if cmdline.is_a? Hash
        threads = []

        cmdline.each do |k, v|
          threads << Thread.new do
            if not parallel v || k, logger, max, &block
              status = false
            end
          end
        end

        threads.each do |thread|
          thread.join
        end
      else
        @@lock.synchronize do
          if max > 0
            loop do
              if @@max < max
                @@max += 1

                break
              end

              sleep 1
            end
          end
        end

        if block_given?
          begin
            if not yield cmdline
              status = false
            end
          rescue
            if logger
              logger.exception $!
            end

            status = false
          end
        else
          if 0 != cmdline2e(cmdline, logger)
            status = false
          end
        end

        @@lock.synchronize do
          @@max -= 1
        end
      end
    end

    status
  end

  def cmdline_exec stdin, ios, wait_thr, logger = nil
    status = nil

    begin
      threads = []

      ios.to_array.each do |io|
        threads << Thread.new do
          str = ''

          loop do
            if wait_thr[:async]
              break
            end

            eof = false

            thread = Thread.new do
              if io.eof?
                if not str.empty?
                  str = str.utf8.rstrip

                  if logger
                    logger.debug str
                  end

                  if block_given?
                    begin
                      yield str, io
                    rescue Errno::EPIPE => e
                    end
                  end

                  str = ''
                end

                eof = true
              end
            end

            if thread.join(1).nil?
              if not str.empty?
                str = str.utf8.rstrip

                if logger
                  logger.debug str
                end

                if block_given?
                  begin
                    yield str, io
                  rescue Errno::EPIPE => e
                  end
                end

                str = ''
              end
            end

            thread.join

            if eof
              break
            end

            str << io.readpartial(4096)
            lines = str.lines

            if lines.last =~ /[\r\n]$/
              str = ''
            else
              str = lines.pop.to_s
            end

            lines.each do |line|
              line = line.utf8.rstrip

              if logger
                logger.debug line
              end

              if block_given?
                begin
                  yield line, io
                rescue Errno::EPIPE => e
                end
              end
            end
          end
        end
      end

      loop do
        alive = false

        threads.each do |thread|
          thread.join 5

          if not wait_thr.alive?
            thread.exit
          end

          if thread.alive?
            alive = true
          end
        end

        if not alive
          break
        end
      end

      status = 0

      if not wait_thr[:async]
        begin
          status = wait_thr.value.exitstatus
        rescue
          if logger
            logger.exception $!
          end

          status = false
        end
      end
    ensure
      if not wait_thr.nil? and not wait_thr[:async]
        ([stdin] + ios.to_array).each do |io|
          if not io.closed?
            io.close
          end
        end

        wait_thr.join
      end
    end

    if logger
      logger.debug 'exit status: %s' % status
    end

    status
  end

  class << self
    private :cmdline_exec
  end
end

class Object
  include CommandLine
end