module Compile
  module_function

  def ant cmdline = nil, logger = nil, opt = {}
    if cmdline.to_s.include? 'build.bat'
      opt[:status] = true
    end

    cmdline cmdline || 'ant', :ant, logger, opt do |error|
      if block_given?
        yield error
      else
        true
      end
    end
  end

  def make cmdline = nil, logger = nil, opt = {}
    cmdline cmdline || 'make', :make, logger, opt do |error|
      if block_given?
        yield error
      else
        true
      end
    end
  end

  def mvn cmdline = nil, logger = nil, opt = {}
    if cmdline.to_s.include? 'build.bat'
      opt[:status] = true
    end

    cmdline cmdline || 'mvn deploy -fn', :mvn, logger, opt do |error|
      if block_given?
        yield error
      else
        true
      end
    end
  end

  def strip path, logger = nil
    status = true

    File.expands(path).each do |x|
      if File.directory? x
        next
      end

      dir, name = File.split x
      debuginfo = '%s.debuginfo' % name

      cmdlines = []
      debug = false

      case OS.name
      when :linux
        Dir.chdir dir do
          cmdline = 'objdump -h %s' % File.cmdline(name)

          if 0 != cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
              if line.include? '.debug_info'
                debug = true
              end
            end

            status = false
          end

          cmdlines << 'objcopy --only-keep-debug %s %s' % [File.cmdline(name), File.cmdline(debuginfo)]
          cmdlines << 'strip -g %s' % File.cmdline(name)
          cmdlines << 'objcopy --add-gnu-debuglink=%s %s' % [File.cmdline(debuginfo), File.cmdline(name)]
        end
      when :solaris
        pkg_dbglink = File.join gem_dir('ruby-ext'), 'bin/pkg_dbglink'

        begin
          File.chmod 0755, pkg_dbglink
        rescue
        end

        Dir.chdir dir do
          cmdline = 'gobjdump -h %s' % File.cmdline(name)

          if 0 != cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
              if line.include? '.debug_info'
                debug = true
              end
            end

            status = false
          end

          cmdlines << 'cp %s %s' % [File.cmdline(name), File.cmdline(debuginfo)]
          cmdlines << 'strip -x %s' % File.cmdline(name)
          cmdlines << '%s %s %s' % [File.cmdline(pkg_dbglink), File.cmdline(name), File.cmdline(debuginfo)]
        end
      when :aix
      end

      if debug
        Dir.chdir dir do
          cmdlines.each do |cmdline|
            if 0 != cmdline2e(cmdline, logger)
              status = false
            end
          end
        end
      end
    end

    status
  end

  def cmdline cmdline, name, logger = nil, opt = {}
    cmdline = cmdline.to_s.strip

    if opt[:home].nil?
      home = '.'
    else
      home = File.normalize opt[:home]
    end

    if File.directory? home
      Dir.chdir home do
        if not cmdline.include? 'mvn clean'
          cmdline = cmds cmdline, name, logger
        end

        if cmdline.nil?
          return false
        end

        status = true
        lines = []

        ret = cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
          lines << line

          if line =~ /(Press any key to continue|请按任意键继续)/
            stdin.puts
          end
        end

        if opt[:status]
          if not ret
            status = false
          end
        else
          if 0 != ret
            status = false
          end
        end

        error = Error.new name, lines, opt
        error.logger = logger

        if error.error?
          display = true

          if block_given?
            display = yield error
          end

          if display
            if logger
              error.puts
            end
          end

          status = false
        end

        status
      end
    else
      if logger
        logger.exception Exception.new('no such directory - %s' % home)
      end

      false
    end
  end

  def cmds cmdline, name, logger = nil
    case name
    when :ant
      if cmdline =~ /\s+(clean|cleanup)$/
        cmdline
      else
        case
        when ($settings[:cov_build] and $settings[:cov_dir])
          cmdline = OS.expandname cmdline, true
          dirname = File.join File.expand_path($settings[:cov_dir]), cmdline.gsub(/\s+/, '_')

          if File.file? File.cmdline_split(cmdline).first
            cmdline = OS.shell cmdline, true
          end

          'cov-build --dir %s %s' % [File.cmdline(dirname), cmdline]
        when ($settings[:klocwork_build] and $settings[:klocwork_dir])
          outfile = File.join File.expand_path($settings[:klocwork_dir]), 'kwinject', cmdline.gsub(/\s+/, '_'), 'kwinject.out'

          if not File.mkdir File.dirname(outfile), logger
            return nil
          end

          'kwant --output %s %s' % [File.cmdline(outfile), cmdline.strip.split(/\s+/, 2)[1]]
        else
          cmdline
        end
      end
    when :make
      if cmdline =~ /^make\s+clean$/
        cmdline
      else
        case
        when ($settings[:cov_build] and $settings[:cov_dir])
          cmdline = OS.expandname cmdline, true
          dirname = File.join File.expand_path($settings[:cov_dir]), cmdline.gsub(/\s+/, '_')

          if File.file? File.cmdline_split(cmdline).first
            cmdline = OS.shell cmdline, true
          end

          'cov-build --dir %s %s' % [File.cmdline(dirname), cmdline]
        when ($settings[:klocwork_build] and $settings[:klocwork_dir])
          outfile = File.join File.expand_path($settings[:klocwork_dir]), 'kwinject', cmdline.gsub(/\s+/, '_'), 'kwinject.out'

          if not File.mkdir File.dirname(outfile), logger
            return nil
          end

          if File.file? outfile
            'kwinject --update --output %s %s' % [File.cmdline(outfile), cmdline]
          else
            'kwinject --output %s %s' % [File.cmdline(outfile), cmdline]
          end
        else
          cmdline
        end
      end
    when :mvn
      if cmdline =~ /^mvn\s+clean$/
        cmdline
      else
        case
        when ($settings[:cov_build] and $settings[:cov_dir])
          cmdline = OS.expandname cmdline, true
          dirname = File.join File.expand_path($settings[:cov_dir]), cmdline.gsub(/\s+/, '_')

          if File.file? File.cmdline_split(cmdline).first
            cmdline = OS.shell cmdline, true
          end

          'cov-build --dir %s %s' % [File.cmdline(dirname), cmdline]
        when ($settings[:klocwork_build] and $settings[:klocwork_dir])
          outfile = File.join File.expand_path($settings[:klocwork_dir]), 'kwinject', cmdline.gsub(/\s+/, '_'), 'kwinject.out'

          if not File.mkdir File.dirname(outfile), logger
            return nil
          end

          if $settings[:klocwork_lang] == 'java'
            'kwmaven --output %s install' % File.cmdline(outfile)
          else
            'kwinject --output %s %s' % [File.cmdline(outfile), cmdline]
          end
        else
          cmdline
        end
      end
    else
      cmdline
    end
  end

  class << self
    private :cmdline, :cmds
  end
end

module Compile
  module_function

  def check_xml file, logger = nil, opt = {}
    if logger
      logger.check file
    end

    begin
      REXML::Document.file file

      true
    rescue
      if logger
        logger.exception $!.to_s
      end

      error = Error.new file, $!, opt
      error.logger = logger

      display = true

      if block_given?
        display = yield error
      end

      if display
        if logger
          error.puts
        end
      end

      false
    end
  end
end

module Compile
  class Error
    attr_accessor :info, :logger, :opt

    def initialize name, message, opt = {}
      @opt = {
        :admin                => $settings[:email_admin],
        :cc                   => $settings[:email_cc],
        :email_subject        => $settings[:email_subject],
        :email_threshold_file => $settings[:email_threshold_file],
        :email_threshold_day  => $settings[:email_threshold_day],
        :error_scm            => $settings[:error_scm]
      }.deep_merge opt

      @info = {
        :error    => {},
        :warning  => {},
        :summary  => [],
        :status   => true
      }

      @max_size = 20

      case name
      when :ant
        ant message
      when :make
        make message
      when :mvn
        @opt[:email_threshold_file] = nil
        @opt[:email_threshold_day] = nil

        mvn message
      else
        if File.extname(name.to_s).downcase == '.xml'
          check_xml name, message
        end

        @opt[:email_threshold_file] = nil
        @opt[:email_threshold_day] = nil
      end

      if not @opt[:account].nil?
        @opt[:email_threshold_file] = nil
        @opt[:email_threshold_day] = nil
        @opt[:error_scm] = false
      end

      scm_info
    end

    def error?
      not @info[:error].empty? or not @info[:summary].empty? or @info[:status] != true
    end

    def authors
      author_list = []

      @info[:error].each do |file, error_info|
        if not error_info[:scm].nil? and not error_info[:scm][:author].nil?
          author = error_info[:scm][:author]

          if author =~ /\((.+)\)/
            account = $`
            name = $1

            if name =~ /^\d+$/
              author = '%s_%s' % [account, name]
            else
              author = name
            end
          end

          author_list << author
        end
      end

      author_list.sort.uniq
    end

    def puts
      if @logger and $settings[:error_puts]
        @logger.debug ''
        @logger.debug '=' * 60
        @logger.debug ''

        @info[:error].each do |file, error_info|
          @logger.debug file

          if not error_info[:scm].nil? and not error_info[:scm][:author].nil?
            @logger.debug '责任人: %s' % error_info[:scm][:author]
            @logger.debug '版本: %s' % error_info[:scm][:rev]
            @logger.debug '日期: %s' % error_info[:scm][:date]
          end

          @logger.debug '-' * 60

          error_info[:list].each_with_index do |x, index|
            if index > 0
              @logger.debug ''
            end

            @logger.debug '%s行号: %s' % [INDENT, x[:lineno]]

            x[:message].each do |line|
              @logger.debug '%s%s' % [INDENT, line]
            end
          end

          @logger.debug ''
        end

        if not @info[:summary].empty?
          @logger.debug '=' * 60
          @logger.debug ''

          @info[:summary].each do |line|
            @logger.debug line
          end

          @logger.debug ''
        end

        @logger.debug '=' * 60
      end

      send_mail
    end

    private

    def ant lines
      cur_lines = []
      found = false
      failed = nil

      lines.each do |line|
        cur_lines << line.rstrip

        line.strip!

        if line == '^'
          file = nil
          lineno = nil
          msg_lines = []

          @max_size.times do |i|
            index = cur_lines.size - i - 1

            if index < 0
              break
            end

            if lines[index] =~ /:(\d+):/
              msg_lines << cur_lines[index]

              file = File.expand_path $`.strip
              lineno = $1.to_i

              break
            end

            msg_lines << cur_lines[index]
          end

          if msg_lines.last.to_s =~ /(warning|警告)(:|：)/
            @info[:warning][file] ||= {
              :list => []
            }

            @info[:warning][file][:list] << {
              lineno:   lineno,
              message:  cur_lines[-@max_size..-1] || cur_lines,
              build:    cur_lines
            }
          else
            @info[:error][file] ||= {
              :list => []
            }

            @info[:error][file][:list] << {
              lineno:   lineno,
              message:  cur_lines[-@max_size..-1] || cur_lines,
              build:    cur_lines
            }
          end

          found = true

          next
        end

        if ['BUILD SUCCESSFUL', 'BUILD FAILED'].include? line
          if line == 'BUILD FAILED'
            if not found
              failed = true
            end

            found = false
          else
            failed = false
          end
        end

        if line =~ /^Total\s+time\s*:/
          if failed
            file = nil
            lineno = nil

            @max_size.times do |i|
              index = lines.size - i - 1

              if index < 0
                break
              end

              if cur_lines[index] =~ /:(\d+):\s*(Compile\s+failed|.*\s+error\s+occurred)/
                file = File.dirname File.expand_path($`.strip)
                lineno = $1.to_i

                break
              end
            end

            if file.nil?
              if cur_lines[-2].to_s =~ /(build\.xml):(\d+):/
                file = File.dirname File.expand_path($` + $1)
                lineno = $2.to_i
              end
            end

            if not file.nil?
              @info[:error][file] ||= {
                :list => []
              }

              @info[:error][file][:list] << {
                lineno:   lineno,
                message:  cur_lines[-@max_size..-1] || cur_lines,
                build:    cur_lines
              }
            end
          end

          cur_lines = []
          failed = nil
        end
      end
    end

    def make lines
      cur_lines = []
      dirname = nil

      lines.each do |line|
        line.rstrip!
        cur_lines << line

        case line
        when /Entering\s+directory\s+`(.*)'/, /进入目录“(.*)”/
          cur_lines = []
          dirname = $1.strip
        when /Leaving\s+directory\s+`(.*)'/, /离开目录“(.*)”/
          cur_lines = []
          dirname = nil
        when /\((\d+)\)\s*:\s*(warning|警告)\s*\w*\d*:/, /,\s*第\s*(\d+)\s*行\s*:\s*警告\s*,/
          file = $`.strip
          lineno = $1.to_i

          if file =~ /^"(.+)"$/
            file = $1.strip
          end

          if File.relative? file
            file = File.join dirname || Dir.pwd, file
          end

          file = File.expand_path file

          @info[:warning][file] ||= {
            :list => []
          }

          @info[:warning][file][:list] << {
            lineno:   lineno,
            message:  [line],
            build:    cur_lines
          }
        when /\s*make(\[\d+\])?:\s+\*\*\*\s+\[.+\]\s+(Error|错误)\s+/
          file = nil
          lineno = nil
          msg_lines = []

          @max_size.times do |i|
            index = cur_lines.size - (i + 1) - 1

            if index < 0
              break
            end

            [
              /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*:/,
              /,\s*第\s*(\d+)\s*行\s*:\s*\w*\s*(error|错误)\s*\w*\d*:/
            ].each do |regexp|
              if cur_lines[index] =~ regexp
                file = $`.strip
                lineno = $1.to_i

                if file =~ /^"(.*)"$/
                  file = $1.strip
                end

                msg_lines = cur_lines[index..-1]

                break
              end
            end

            if not lineno.nil?
              break
            end
          end

          if file.nil?
            file = dirname || Dir.pwd.utf8

            if File.basename(file) == 'lib'
              file = File.dirname file
            end
          end

          if File.relative? file
            file = File.join dirname || Dir.pwd, file
          end

          file = File.expand_path file

          if msg_lines.empty?
            msg_lines = cur_lines[-@max_size..-1] || cur_lines
          end

          @info[:error][file] ||= {
            :list => []
          }

          @info[:error][file][:list] << {
            lineno:   lineno,
            message:  msg_lines,
            build:    cur_lines
          }
        end
      end
    end

    def mvn lines
      status = nil
      last_lines = []

      start = false

      file = nil
      lineno = nil
      error_lines = []
      cur_lines = []

      lines.each_with_index do |line, index|
        cur_lines << line.rstrip

        line.strip!

        if line =~ /^\[INFO\]\s+Reactor\s+Build\s+Order:$/
          if not file.nil?
            if cur_lines.first =~ /^\[INFO\]\s+----+$/
              cur_lines.shift
            end

            @info[:error][file] ||= {
              :list => []
            }

            @info[:error][file][:list] << {
              lineno:   lineno,
              message:  error_lines,
              build:    cur_lines
            }
          end

          start = true
          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        if line =~ /^\[INFO\]\s+Reactor\s+Summary:$/
          start = false
          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        if line =~ /^\[INFO\]\s+Building\s+/
          start = true
        end

        if line =~ /^\[INFO\]\s+BUILD\s+(SUCCESS|FAILURE)$/
          if $1 == 'SUCCESS'
            status ||= true
          else
            status = false

            last_lines = lines[index..-1]
          end
        end

        if line =~ /^\[INFO\]\s+Total\s+time\s*:/
          cur_lines.each do |tmp_line|
            tmp_line.strip!

            if tmp_line =~ /^\[INFO\]\s+.*\.+\s*FAILURE/
              @info[:summary] << tmp_line
            end
          end

          start = false
          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        if line =~ /^\[INFO\]\s+----+$/
          next
        end

        if start
          if line =~ /^\[INFO\]\s+Building\s+/
            file = nil
            lineno = nil
            error_lines = []
            cur_lines = [
              line
            ]

            if index > 1 and lines[index - 1] =~ /^\[INFO\]\s+----+$/
              cur_lines.insert 0, lines[index - 1].strip
            end

            next
          end

          if line =~ /^\[ERROR\]\s+(.+):\[(\d+),\d+\]/
            match_data = $~

            if not file.nil?
              if cur_lines.first =~ /^\[INFO\]\s+----+$/
                cur_lines.shift
              end

              @info[:error][file] ||= {
                :list => []
              }

              @info[:error][file][:list] << {
                lineno:   lineno,
                message:  error_lines,
                build:    cur_lines
              }
            end

            file = match_data[1].strip
            lineno = match_data[2].to_i
            error_lines = [
              line
            ]

            if OS.windows?
              if file.start_with? '/'
                file = file[1..-1]
              end
            end

            if file =~ /\/src\/testSrc\//
              test_file = File.join $`, 'testSrc', $'

              if File.exist? test_file
                file = test_file
              end
            end

            next
          end

          if line =~ /^\[INFO\]\s+\d+\s+(error|errors)$/
            if not file.nil?
              if cur_lines.first =~ /^\[INFO\]\s+----+$/
                cur_lines.shift
              end

              @info[:error][file] ||= {
                :list => []
              }

              @info[:error][file][:list] << {
                lineno:   lineno,
                message:  error_lines,
                build:    cur_lines
              }
            end

            file = nil
            lineno = nil
            error_lines = []
            cur_lines = []

            next
          end

          if line =~ /^Tests\s+run\s*:\s*(\d+)\s*,\s*Failures\s*:\s*(\d+)\s*,\s*Errors\s*:\s*(\d+)\s*,\s*Skipped\s*:\s*(\d+)$/
            if $2.to_i > 0 or $3.to_i > 0
              cur_lines.each_with_index do |tmp_line, i|
                tmp_line = tmp_line.strip

                if tmp_line =~ /Surefire\s+report\s+directory\s*:\s*(.*)[\/\\]target[\/\\]surefire-reports$/
                  file = $1

                  if file =~ /\/src\/testSrc\//
                    test_file = File.join $`, 'testSrc', $'

                    if File.exist? test_file
                      file = test_file
                    end
                  end

                  next
                end

                if i > 0 and cur_lines[i - 1].strip =~ /^T\s*E\s*S\s*T\s*S$/ and tmp_line =~ /^----+$/
                  error_lines = cur_lines[i + 1..-1]

                  break
                end
              end

              if not file.nil?
                @info[:error][file] ||= {
                  :list => []
                }

                @info[:error][file][:list] << {
                  lineno:   lineno,
                  message:  error_lines,
                  build:    cur_lines
                }
              end

              file = nil
              lineno = nil
              error_lines = []
              cur_lines = []
            end

            next
          end

          # linux
          #   /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
          #
          # solaris
          #   /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/
          #
          # windows
          #   /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
          #   /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
          if line =~ /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or
            line =~ /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/ or
            line =~ /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or line =~ /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
            file = $`.strip.nil
            lineno = $1.to_i

            if file =~ /^"(.*)"$/
              file = $1.strip.nil
            end

            if file =~ /\/src\/testSrc\//
              test_file = File.join $`, 'testSrc', $'

              if File.exist? test_file
                file = test_file
              end
            end

            if not file.nil?
              file = File.normalize file

              @info[:error][file] ||= {
                :list => []
              }

              if not @info[:error][file][:list].empty? and @info[:error][file][:list].last[:lineno] == lineno
                @info[:error][file][:list][-1][:message] << line
                @info[:error][file][:list][-1][:build] += cur_lines
              else
                @info[:error][file][:list] << {
                  lineno:   lineno,
                  message:  [line],
                  build:    cur_lines
                }
              end
            end

            file = nil
            lineno = nil
            error_lines = []
            cur_lines = []

            next
          end

          # linux
          #   /:\s*(\d+)\s*:\s*undefined\s+reference\s+/
          #   /collect2\s*:\s*ld\s+/
          #
          # solaris
          #   /\s*(\(|（)(符号范围指定本机绑定)(\)|）)/
          #   /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors.\s+No\s+output\s+written\s+to\s+/
          #
          # windows
          #   /:\s*error\s+LNK\d+\s*:/
          #   /\s*:\s*fatal\s+error\s+LNK\d+\s*:/

          if line =~ /collect2\s*:\s*ld\s+/ or
            line =~ /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors.\s+No\s+output\s+written\s+to\s+/ or
            line =~ /\s*:\s*fatal\s+error\s+LNK\d+\s*:/

            file = Dir.pwd

            error_lines = []

            cur_lines.each_with_index do |x, index|
              if x =~ /:\s*(\d+)\s*:\s*undefined\s+reference\s+/
                if index > 0
                  if cur_lines[index - 1] =~ /\s*:\s*In\s+function\s+.*:/
                    error_lines << cur_lines[index - 1]
                  end
                end

                error_lines << x

                next
              end

              if x =~ /\s*(\(|（)(符号范围指定本机绑定)(\)|）)/
                error_lines << x

                next
              end

              if x =~ /:\s*error\s+LNK\d+\s*:/ or x =~ /\s*:\s*fatal\s+error\s+LNK\d+\s*:/
                error_lines << x

                next
              end
            end

            if not file.nil?
              file = File.normalize file

              @info[:error][file] ||= {
                :list => []
              }

              if not @info[:error][file][:list].empty?
                @info[:error][file][:list][-1][:message] << line
                @info[:error][file][:list][-1][:build] += cur_lines
              else
                @info[:error][file][:list] << {
                  lineno:   nil,
                  message:  error_lines,
                  build:    cur_lines
                }
              end
            end

            file = nil
            lineno = nil
            error_lines = []
            cur_lines = []

            next
          end

          # daobuilder
          #   /^\[exec\].*\s+error\s*:\s*file\s*:\s*(.*\.xml)/
          if line =~ /^\[exec\].*\s+error\s*:\s*file\s*:\s*(.*\.xml)/
            file = $1.strip.nil

            if cur_lines.size <= 5
              error_lines = cur_lines
            else
              error_lines = cur_lines[-5..-1]
            end

            if not file.nil?
              file = File.normalize file

              @info[:error][file] ||= {
                :list => []
              }

              if not @info[:error][file][:list].empty?
                @info[:error][file][:list][-1][:message] += error_lines
                @info[:error][file][:list][-1][:build] += cur_lines
              else
                @info[:error][file][:list] << {
                  lineno:   nil,
                  message:  error_lines,
                  build:    cur_lines
                }
              end
            end

            file = nil
            lineno = nil
            error_lines = []
            cur_lines = []

            next
          end
        else
          if line =~ /^\[ERROR\]/
            error_lines << line

            if line =~ /\((.+)\)\s+has\s+\d+\s+error/
              file = $1
            end

            next
          end
        end

        if not error_lines.empty?
          error_lines << line
        end
      end

      if not file.nil?
        if cur_lines.first =~ /^\[INFO\]\s+----+$/
          cur_lines.shift
        end

        @info[:error][file] ||= {
          :list => []
        }

        @info[:error][file][:list] << {
          lineno:   lineno,
          message:  error_lines,
          build:    cur_lines
        }
      end

      map = artifactid_paths

      if not @info[:summary].empty?
        @info[:summary].each_with_index do |line, index|
          if line.strip =~ /^\[INFO\]\s+(.*?)\s+\.+/
            if map.has_key? $1
              @info[:summary][index] = '%s(%s)' % [line, File.relative_path(map[$1])]
            end
          end
        end
      end

      if status != true
        name = nil
        error_lines = []

        last_lines.each do |line|
          line.strip!

          if line =~ /^\[ERROR\]\s+Failed\s+to\s+execute\s+.*\s+on\s+project\s+([\w_-]+):/
            name = $1
          end

          if not name.nil?
            error_lines << line
          end

          if line =~ /^\[ERROR\]\s+.*->\s+\[Help\s+1\]$/
            if not name.nil?
              dirname = map[name]

              if not dirname.nil?
                found = false

                @info[:error].keys.each do |file|
                  if File.include? dirname, file
                    found = true

                    break
                  end
                end

                if not found
                  @info[:error][dirname] ||= {
                    :list => []
                  }

                  @info[:error][dirname][:list] << {
                    lineno:   nil,
                    message:  error_lines,
                    build:    error_lines
                  }
                end
              end
            end

            name = nil
            error_lines = []
          end
        end
      end

      @info[:status] = status
    end

    def check_xml file, parse_exception
      @info[:error][file] ||= {
        :list => []
      }

      lineno = nil
      lines = []

      parse_exception.to_s.lines do |line|
        line.rstrip!

        if line =~ /^Line:/
          lineno = $'.strip.to_i
        end

        lines << line
      end

      @info[:error][file][:list] << {
        lineno:   lineno,
        message:  lines
      }

      @info[:summary] << file
    end

    def scm_info
      if @opt[:error_scm]
        @info[:error].each do |file, error_info|
          info = SCM.info file, @logger

          if info.nil?
            scm_home = SCM.home

            if not scm_home.nil?
              info = SCM.info scm_home, @logger
            end
          end

          if info.nil?
            error_info[:scm] = {
              :author => nil,
              :rev    => nil,
              :date   => nil
            }

            if File.exists? file
              error_info[:scm][:date] = File.mtime file
            end
          else
            error_info[:scm] = info
            account = info[:author]

            if not account.nil? and $settings[:accounts]
              if $settings[:accounts].has_key? account
                name, email = $settings[:accounts][account].utf8

                error_info[:scm][:author] = '%s(%s)' % [account, name]
                error_info[:email] = email
              else
                email = nil

                if account =~ /<(.*)>/
                  account = $`.strip

                  if $1.include? '@'
                    email = $1.strip.split(/[\/\\]/).last
                  end
                end

                if $settings[:accounts].has_key? account
                  name, email = $settings[:accounts][account].utf8

                  error_info[:scm][:author] = '%s(%s)' % [account, name]
                  error_info[:email] = email
                else
                  error_info[:scm][:author] = '%s(%s)' % [account, nil]

                  if email.nil?
                    if account =~ /\d+$/
                      email = '%s@zte.com.cn' % $&.strip
                      error_info[:scm][:author] = '%s(%s)' % [account, $&.strip]
                    end
                  end

                  error_info[:email] = email
                end
              end
            end
          end
        end
      end

      true
    end

    def send_mail
      if @opt[:email_threshold_file].to_i > 0
        threshold_file = @opt[:email_threshold_file].to_i
      else
        threshold_file = nil
      end

      if @opt[:email_threshold_day].to_i > 0
        threshold_day = Time.now - @opt[:email_threshold_day].to_i * 24 * 3600
      else
        threshold_day = nil
      end

      map = {}
      index = 0

      @info[:error].each do |file, error_info|
        if not threshold_file.nil?
          if index > threshold_file
            break
          end
        end

        if not threshold_day.nil? and not error_info[:scm].nil?
          if error_info[:scm][:date].is_a? Time
            if error_info[:scm][:date] < threshold_day
              next
            end
          end
        end

        email = @opt[:account] || error_info[:email] || @opt[:email_admin]

        if not email.nil?
          map[email] ||= {}
          map[email][file] = error_info
        end

        index += 1
      end

      status = true

      map.each do |email, info|
        lines = []

        lines << '操作系统: <font color = "blue">%s</font><br>' % OS.name
        lines << '当前目录: <font color = "blue">%s</font><br>' % Dir.pwd.utf8
        lines << '<br>'

        build_info = {}

        info.each do |file, error_info|
          lines << '<h3><a href = "%s">%s</a></h3><br>' % [file, file]
          lines << '<pre>'

          if not error_info[:scm].nil? and not error_info[:scm][:author].nil?
            lines << '<b>责任人: <font color = "red">%s</font></b><br>' % error_info[:scm][:author]
            lines << '<b>版本: %s</b>' % error_info[:scm][:rev]
            lines << '<b>日期: %s</b>' % error_info[:scm][:date]
          end

          lines << ''

          message_info = []

          error_info[:list].each do |x|
            message_info << {
              :lineno   => x[:lineno],
              :message  => x[:message]
            }

            if x[:build]
              build_info[file] ||= []
              build_info[file] << x[:build]
            end
          end

          message_info.uniq.each do |message|
            lines << '<b>行号: %s</b>' % message[:lineno]
            lines << ''

            message[:message].each do |line|
              lines << line
            end

            lines << ''
          end

          lines << '</pre>'
          lines << '<br>'
        end

        if not Net::send_smtp '10.30.18.230', 'admin@zte.com.cn', email, @logger, @opt do |mail|
            if $settings[:x64]
              mail.subject = 'Subject: %s(%s-X64)' % [(@opt[:email_subject] || '<BUILD 通知>编译失败, 请尽快处理'), OS.name]
            else
              mail.subject = 'Subject: %s(%s)' % [(@opt[:email_subject] || '<BUILD 通知>编译失败, 请尽快处理'), OS.name]
            end

            mail.html = lines.join "\n"

            File.tmpdir do |dir|
              build_info.each do |k, v|
                filename = File.join dir, 'build(%s).log' % File.basename(k.to_s, '.*')

                File.open filename, 'w' do |file|
                  v.each_with_index do |build, index|
                    if index > 0
                      file.puts
                      file.puts '=' * 60
                      file.puts
                    end

                    file.puts build
                  end
                end

                mail.attach filename.locale
              end
            end
          end

          status = false
        end
      end

      status
    end

    def artifactid_paths dirname = nil
      dirname ||= '.'
      map = {}

      if File.file? File.join(dirname, 'pom.xml')
        Dir.chdir dirname do
          begin
            doc = REXML::Document.file 'pom.xml'

            REXML::XPath.each doc, '/project/artifactId' do |e|
              if OS.windows?
                map[e.text.to_s.strip.gsub('${prefix}', '')] = Dir.pwd
              else
                map[e.text.to_s.strip.gsub('${prefix}', 'lib')] = Dir.pwd
              end

              break
            end

            REXML::XPath.each doc, '//modules/module' do |e|
              map.deep_merge! artifactid_paths(e.text.to_s.strip)
            end
          rescue
          end
        end
      end

      map
    end
  end
end
