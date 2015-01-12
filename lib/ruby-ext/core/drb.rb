require 'drb'
require 'monitor'

module DRb
  class Object
    attr_accessor :logger
    attr_reader :server

    include DRbUndumped

    def connect ip = nil, port = nil
      begin
        if DRb.thread.nil?
          DRb.start_service DRb.druby(Socket.ip, 0)
        end

        @server = DRbObject.new nil, DRb.druby(ip || '127.0.0.1', port)
        @server.connect?
      rescue
        if @logger
          @logger.exception $!
        end

        @server = nil

        false
      end
    end

    def connect?
      if not @server.nil?
        begin
          @server.connect?
        rescue
          if @logger
            @logger.exception $!
          end

          false
        end
      else
        false
      end
    end

    def close service = false
      if service
        DRb.stop_service
      end

      @server = nil
    end

    def uri
      '%s:%s' % [DRb.uri, object_id]
    end
  end

  class Server
    def connect?
      true
    end

    def self.start ip = nil, port = nil, config = nil
      url = DRb.druby ip, port
      DRb.start_service url, Server.new, config

      if block_given?
        yield url
      end

      DRb.thread.join
    end
  end

  def self.druby ip = nil, port = nil
    'druby://%s:%s' % [ip || '0.0.0.0', port || 9000]
  end
end

module DRb
  class Object
    def cmdline cmdline, opt = {}
      @server.cmdline cmdline, @logger, opt do |line, stdin, is_stdout, wait_thr|
        if block_given?
          yield line, stdin, is_stdout, wait_thr
        end
      end
    end

    def cmdline2e cmdline, opt = {}
      @server.cmdline2e cmdline, @logger, opt do |line, stdin, wait_thr|
        if block_given?
          yield line, stdin, wait_thr
        end
      end
    end

    def rubyscript string, opt = {}
      @server.rubyscript string, @logger, opt do |line, stdin, wait_thr|
        if block_given?
          yield line, stdin, wait_thr
        end
      end
    end

    def copy_file src, dest
      if hostname == Socket.gethostname
        if src.nil?
          status = File.delete dest, @logger
        else
          status = File.copy src, dest, @logger
        end

        return status
      end

      dest = File.normalize dest

      if src.nil?
        map = {
          dest  => nil
        }

        if @logger
          @logger.cmdline 'drb delete %s' % dest
        end
      else
        src = File.normalize src
        map = File.copy_map src, dest

        if @logger
          @logger.cmdline 'drb copy %s, %s' % [src, dest]
        end
      end

      begin
        map.each do |dest_file, src_file|
          if src_file.nil?
            if @logger
              @logger.debug dest_file
            end

            if not @server.copy_file dest_file, -1, nil, @logger
              raise IOError, dest_file
            end
          else
            if @logger
              @logger.debug '%s, %s' % [src_file, dest_file]
            end

            if File.directory? src_file
              if not @server.copy_file dest_file, 0, nil, @logger
                raise IOError, src_file
              end
            else
              File.open src_file, 'rb' do |file|
                index = 0

                loop do
                  data = file.read 4096

                  if not @server.copy_file dest_file, index, data, @logger
                    raise IOError, src_file
                  end

                  if data.nil?
                    break
                  end

                  index += 1
                end
              end
            end
          end
        end

        true
      rescue
        if @logger
          @logger.exception $!
        end

        false
      end
    end

    def os_name
      @server.os_name
    end

    def hostname
      @server.hostname
    end

    def reboot
      @server.reboot @logger
    end

    def time
      @server.time
    end

    def get_var name
      @server.get_var name
    end

    def set_var name, value
      @server.set_var name, value
    end
  end

  class Server
    attr_reader :handle, :variables

    @@lock = Monitor.new

    def initialize
      @handle = {}
      @variables = {}
    end

    def cmdline cmdline, logger = nil, opt = {}
      if opt[:sync]
        @@lock.synchronize do
          CommandLine.cmdline cmdline, logger, opt do |line, stdin, is_stdout, wait_thr|
            if block_given?
              yield line, stdin, is_stdout, wait_thr
            end
          end
        end
      else
        CommandLine.cmdline cmdline, logger, opt do |line, stdin, is_stdout, wait_thr|
          if block_given?
            yield line, stdin, is_stdout, wait_thr
          end
        end
      end
    end

    def cmdline2e cmdline, logger = nil, opt = {}
      if opt[:sync]
        @@lock.synchronize do
          CommandLine.cmdline2e cmdline, logger, opt do |line, stdin, wait_thr|
            if block_given?
              yield line, stdin, wait_thr
            end
          end
        end
      else
        CommandLine.cmdline2e cmdline, logger, opt do |line, stdin, wait_thr|
          if block_given?
            yield line, stdin, wait_thr
          end
        end
      end
    end

    def rubyscript string, logger = nil, opt = {}
      if opt[:sync]
        @@lock.synchronize do
          CommandLine.rubyscript string, logger, opt do |line, stdin, wait_thr|
            if block_given?
              yield line, stdin, wait_thr
            end
          end
        end
      else
        CommandLine.rubyscript string, logger, opt do |line, stdin, wait_thr|
          if block_given?
            yield line, stdin, wait_thr
          end
        end
      end
    end

    def copy_file filename, index = -1, data = nil, logger = nil
      @@lock.synchronize do
        filename = File.normalize filename

        case index
        when -1
          File.delete filename, logger
        when 0
          if data.nil?
            if not File.directory? filename
              File.mkdir filename, logger
            else
              true
            end
          else
            file = File.open filename, 'wb'
            file << data

            @handle[filename] = file
          end
        else
          if not @handle[filename].nil?
            file = @handle[filename]

            if data.nil?
              file.close

              @handle.delete filename
            else
              file << data
            end
          end
        end

        true
      end
    end

    def os_name
      OS.name
    end

    def hostname
      Socket.gethostname
    end

    def reboot logger = nil
      OS.reboot nil, logger
    end

    def time
      Time.now
    end

    def get_var name
      @variables[name]
    end

    def set_var name, value = nil
      @@lock.synchronize do
        if value.nil?
          @variables.delete name
        else
          @variables[name] = value
        end
      end
    end

    def clear
      @@lock.synchronize do
        @handle.each do |name, file|
          file.close
        end

        @handle = {}
      end
    end
  end
end