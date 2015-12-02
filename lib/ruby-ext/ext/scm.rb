require 'time'

class SCM
  def self.checkout repos, path = nil, logger = nil, opt = {}
    case
    when repos.end_with?(':svn')
      SVN.checkout repos[0..-5], path, logger, opt
    when repos.end_with?(':git')
      GIT.clone repos[0..-5], path, logger, opt
    when repos.end_with?(':tfs')
      GIT_TFS.clone repos[0..-5], path, logger, opt
    else
      case
      when repos.include?('svn')
        SVN.checkout repos, path, logger, opt
      when repos.include?('git')
        GIT.clone repos, path, logger, opt
      when repos.include?('/$/')
        GIT_TFS.clone repos, path, logger, opt
      else
        nil
      end
    end
  end

  def self.update path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.update path, logger, opt
    when :git
      GIT.pull path, logger, opt
    when :tfs
      GIT_TFS.pull path, logger, opt
    else
      nil
    end
  end

  def self.commit path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.update(path, logger, opt) and SVN.commit(path, logger, opt)
    when :git
      GIT.commit(path, logger, opt) and GIT.pull(path, logger, opt) and GIT.push(path, logger, opt)
    when :tfs
      GIT_TFS.commit(path, logger, opt) and GIT_TFS.pull(path, logger, opt) and GIT_TFS.push(path, logger, opt)
    else
      nil
    end
  end

  def self.log path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.log path, logger, opt
    when :git
      GIT.log path, logger, opt
    when :tfs
      GIT_TFS.log path, logger, opt
    else
      nil
    end
  end

  def self.info path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.info path, logger, opt
    when :git
      GIT.info path, logger, opt
    when :tfs
      GIT_TFS.info path, logger, opt
    else
      nil
    end
  end

  def self.add path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.add path, logger, opt
    when :git
      GIT.add path, logger
    when :tfs
      GIT_TFS.add path, logger
    else
      nil
    end
  end

  def self.delete path = nil, logger = nil, opt = {}
    case scm(path)
    when :svn
      SVN.delete path, logger, opt
    when :git
      GIT.rm path, logger
    when :tfs
      GIT_TFS.rm path, logger
    else
      nil
    end
  end

  def self.cleanup path = nil, logger = nil
    case scm(path)
    when :svn
      SVN.cleanup path, logger
    when :git
      true
    when :tfs
      true
    else
      nil
    end
  end

  def self.revert path = nil, logger = nil
    case scm(path)
    when :svn
      SVN.revert path, logger
    when :git
      GIT.reset(path, logger) and GIT.checkout(path, logger)
    when :tfs
      GIT_TFS.reset(path, logger) and GIT_TFS.checkout(path, logger)
    else
      nil
    end
  end

  # ----------------------------------------------------------------------------

  def self.scm path = nil
    scm_home = home path

    if not scm_home.nil?
      if File.directory? File.join(scm_home, '.svn') or File.directory? File.join(scm_home, '_svn')
        return :svn
      end

      if File.directory? File.join(scm_home, '.git')
        if GIT.config(scm_home, 'git-tf.server.collection').nil?
          return :git
        else
          return :tfs
        end
      end
    end

    nil
  end

  def self.home path = nil
    path ||= '.'
    path = File.expand_path path

    loop do
      if File.directory? File.join(path, '.svn') or File.directory? File.join(path, '_svn')
        return path
      end

      if File.directory? File.join(path, '.git')
        return path
      end

      if File.dirname(path) == path
        break
      end

      path = File.dirname path
    end

    nil
  end
end

class SVN
  def self.checkout repos, path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn checkout'

    if not args.nil?
      cmdline += ' %s' % args
    end

    username = opt[:username] || $settings[:svn_username]
    password = opt[:password] || $settings[:svn_password]

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username.utf8, password.utf8]
    end

    cmdline += ' %s' % File.cmdline(File.expand_path(repos))

    if not path.nil?
      cmdline += ' %s' % File.cmdline(path)
    end

    0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
      authorization line, stdin
    end
  end

  def self.update path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn update --force'

    if not args.nil?
      cmdline += ' %s' % args
    end

    username = opt[:username] || $settings[:svn_username]
    password = opt[:password] || $settings[:svn_password]

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username.utf8, password.utf8]
    end

    if not path.nil?
      path.to_array.each do |x|
        cmdline += ' %s' % File.cmdline(x)
      end
    end

    lines = []

    if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
        authorization line, stdin
        lines << line.rstrip
      end

      status = true
    else
      status = false
    end

    map = {}
    path = nil

    lines.each do |line|
      if line =~ /(Updating|正在升级)\s+'(.*)'(:|：)$/
        path = File.expand_path $2.strip

        map[path] = {
          :rev  => nil,
          :info => []
        }

        next
      end

      if not path.nil?
        if line =~ /(s+revision|更新到版本)\s+(\d+)(.|。)$/
          map[path][:rev] = $2.to_i
          path = nil

          next
        end

        if line =~ /^[ADUCGER]\s+.*/
          map[path][:info] << line.split(/\s+/, 2)
        end
      end
    end

    $updated = {}

    map.each do |k, v|
      if v[:info].empty?
        next
      end

      v[:info].each do |flag, name|
        if not ['A', 'D'].include? flag
          flag = 'U'
        end

        $updated[flag] ||= []
        $updated[flag] << File.expand_path(name)
      end
    end

    File.open 'updates.txt', 'w' do |file|
      map.each do |k, v|
        if v[:info].empty?
          next
        end

        file.puts '%s: %s' % [k, v[:rev]]
        file.puts '=' * 60

        v[:info].each do |flag, name|
          if not ['A', 'D'].include? flag
            flag = 'U'
          end

          file.puts '  %s %s' % [flag, File.expand_path(name)]
        end

        file.puts
      end
    end

    status
  end

  def self.commit path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn commit'

    if not args.nil?
      cmdline += ' %s' % args
    end

    if not opt[:file].nil?
      cmdline += ' --encoding utf-8 --file %s' % File.cmdline(opt[:file])
    else
      message = opt[:message] || $settings[:svn_message]

      if message.nil?
        message = 'auto commit'
      end

      cmdline += ' -m %s' % File.cmdline(message.to_s)
    end

    username = opt[:username] || $settings[:svn_username]
    password = opt[:password] || $settings[:svn_password]

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username.utf8, password.utf8]
    end

    if not path.nil?
      path.to_array.each do |x|
        cmdline += ' %s' % File.cmdline(x)
      end
    end

    0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
      authorization line, stdin
    end
  end

  def self.log path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn log'

    if not args.nil?
      cmdline += ' %s' % args
    end

    username = opt[:username] || $settings[:svn_username]
    password = opt[:password] || $settings[:svn_password]

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username.utf8, password.utf8]
    end

    if not path.nil?
      cmdline += ' %s' % File.cmdline(path)
    end

    lines = []

    if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
        authorization line, stdin
        lines << line.strip
      end

      list = []

      lines.split { |line| line =~ /^-+$/ }.each do |x|
        if x.shift =~ /^r(\d+)\s+\|\s+(.+)\s+\|\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+[+-]\d{4})\s+.*/
          rev = $1.strip
          author = $2.strip

          begin
            date = Time.parse $3.to_s.strip[0..24]
          rescue
            if logger
              logger.exception $!
            end

            date = nil
          end

          change_files = {}
          comment = []

          start = false
          x.each do |line|
            if not start
              if ['Changed paths:', '改变的路径:'].include? line
                start = true

                next
              end
            end

            if start
              if line.empty?
                start = false
              else
                if line =~ /^\s*([A-Z])\s+(.*)$/
                  flag = $1.strip
                  name = $2.strip

                  if name.start_with? '/'
                    name = name[1..-1]
                  end

                  if name =~ /\(from\s+.*:\d+\)$/
                    name = $`.strip
                  end

                  case flag
                  when 'A'
                    change_files[:add] ||= []
                    change_files[:add] << name
                  when 'D'
                    change_files[:delete] ||= []
                    change_files[:delete] << name
                  else
                    change_files[:update] ||= []
                    change_files[:update] << name
                  end
                end
              end
            else
              comment << line
            end
          end

          list << {
            rev:          rev,
            author:       author,
            date:         date,
            change_files: change_files,
            comment:      comment
          }
        end
      end

      list.sort { |x, y| x[:rev].to_i <=> y[:rev].to_i }
    else
      nil
    end
  end

  def self.info path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn info'

    if not args.nil?
      cmdline += ' %s' % args
    end

    username = opt[:username] || $settings[:svn_username]
    password = opt[:password] || $settings[:svn_password]

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username.utf8, password.utf8]
    end

    if not path.nil?
      cmdline += ' %s' % File.cmdline(path)
    end

    info = {}

    if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
        authorization line, stdin
        line = line.strip

        case
        when line =~ /^(URL)(:|：)/
          info[:url] = $'.strip.gsub '%20', ' '
        when line =~ /^(Repository Root|版本库根)(:|：)/
          info[:root] = $'.strip.gsub '%20', ' '
        when line =~ /^(Last Changed Author|最后修改的作者)(:|：)/
          info[:author] = $'.strip
        when line =~ /^(Last Changed Rev|最后修改的版本|最后修改的修订版)(:|：)/
          info[:rev] = $'.strip
        when line =~ /^(Last Changed Date|最后修改的时间)(:|：)/
          begin
            info[:date] = Time.parse $'.strip[0..24]
          rescue
            if logger
              logger.exception $!
            end

            info[:date] = nil
          end
        end
      end

      info
    else
      nil
    end
  end

  def self.add path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn add --force --parents'

    if not args.nil?
      cmdline += ' %s' % args
    end

    cmdline += ' %s' % File.cmdline(path || '.')

    cmdline2e(cmdline, logger).zero?
  end

  def self.delete path = nil, logger = nil, opt = {}
    args = (opt[:svn_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'svn delete --force'

    if not args.nil?
      cmdline += ' %s' % args
    end

    cmdline += ' %s' % File.cmdline(path || '.')

    cmdline2e(cmdline, logger).zero?
  end

  def self.cleanup path = nil, logger = nil
    cmdline = 'svn cleanup'

    if not path.nil?
      cmdline += ' %s' % File.cmdline(path)
    end

    cmdline2e(cmdline, logger).zero?
  end

  def self.revert path = nil, logger = nil
    cmdline = 'svn revert -R %s' % File.cmdline(path || '.')

    cmdline2e(cmdline, logger).zero?
  end

  # ----------------------------------------------------------------------------

  def self.authorization line, stdin
    case line
    when /\(p\)(ermanently|永远接受)(\?|？)/
      stdin.puts 'p'
    when /\(yes\/no\)\?/
      stdin.puts 'yes'
    when /\(mc\)\s*(mine-conflict|我的版本)\s*,\s*\(tc\)\s*(theirs-conflict|他人的版本)/
      sleep 1
      stdin.puts 'tc'
    end
  end

  class << self
    private :authorization
  end
end

class GIT
  def self.clone repos, path = nil, logger = nil, opt = {}
    args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

    branch = nil

    if repos =~ /@/
      repos = $`
      branch = $'.nil
    end

    cmdline = 'git clone'

    if not branch.nil?
      cmdline += ' -b %s' % branch
    end

    if not args.nil?
      cmdline += ' %s' % args
    end

    if opt.has_key? :depth
      if not opt[:depth].nil?
        cmdline += ' --depth %s' % opt[:depth]
      end
    end

    username = opt[:username] || $settings[:git_username]
    password = opt[:password] || $settings[:git_password]

    if not username.nil? and not password.nil?
      case
      when repos =~ /^(http|https):\/\//
        repos = '%s%s:%s@%s' % [$&, username, password, $']
      when repos =~ /^ssh:\/\//
        repos = '%s%s@%s' % [$&, username, $']
      end
    end

    if not args.nil?
      cmdline += ' -- %s' % repos
    else
      cmdline += ' %s' % repos
    end

    if not path.nil?
      cmdline += ' %s' % File.normalize(path)
    end

    0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
      authorization line, stdin, username, password
    end
  end

  def self.pull path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git pull'

        if not args.nil?
          cmdline += ' %s' % args
        end

        username = opt[:username] || $settings[:git_username]
        password = opt[:password] || $settings[:git_password]

        if 0 != cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
            authorization line, stdin, username, password
          end

          return false
        end

        if not opt[:revision].nil?
          cmdline = 'git checkout %s' % opt[:revision]

          if path.nil?
            cmdline += ' -- %s' % File.expand_path(path)
          end

          if 0 != cmdline2e(cmdline, logger)
            return false
          end
        end

        true
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.fetch path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git fetch'

        if not args.nil?
          cmdline += ' %s' % args
        end

        username = opt[:username] || $settings[:git_username]
        password = opt[:password] || $settings[:git_password]

        0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
          authorization line, stdin, username, password
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.push path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git push'

        if not args.nil?
          cmdline += ' %s' % args
        end

        username = opt[:username] || $settings[:git_username]
        password = opt[:password] || $settings[:git_password]

        0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
          authorization line, stdin, username, password
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.checkout branch = nil, path = nil, logger = nil, opt = {}
    paths = path.to_array.map { |x| File.expand_path x || '.' }
    dir = home paths.first

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git checkout'

        if not branch.nil?
          cmdline += ' %s' % branch
        end

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not path.nil? and branch.nil?
          cmdline += ' --'

          paths.each do |x|
            cmdline += ' %s' % File.cmdline(x)
          end
        end

        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % paths.first
      end

      false
    end
  end

  def self.commit path = nil, logger = nil, opt = {}
    paths = path.to_array.map { |x| File.expand_path x || '.' }
    dir = home paths.first

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git commit'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not opt[:file].nil?
          cmdline += ' --file=%s' % File.cmdline(opt[:file])
        else
          message = opt[:message] || $settings[:git_message]

          if message.nil?
            message = 'auto commit'
          end

          cmdline += ' -m %s' % File.cmdline(message.to_s)
        end

        if not path.nil?
          cmdline += ' --'

          paths.each do |x|
            cmdline += ' %s' % File.cmdline(x)
          end
        end

        [0, 1].include? cmdline2e(cmdline, logger)
      end
    else
      if logger
        logger.exception '%s is outside repository' % paths.first
      end

      false
    end
  end

  def self.reset path = nil, logger = nil, opt = {}
    paths = path.to_array.map { |x| File.expand_path x || '.' }
    dir = home paths.first

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git reset'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not path.nil?
          cmdline += ' --'

          paths.each do |x|
            cmdline += ' %s' % File.cmdline(x)
          end
        end

        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % paths.first
      end

      false
    end
  end

  def self.log path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      path = File.expand_path path || '.'

      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        if opt.has_key? :stat
          stat = opt[:stat]
        else
          stat = true
        end

        cmdline = 'git log'

        if stat
          cmdline += ' --stat=256'
        end

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not path.nil?
          cmdline += ' -- %s' % File.normalize(path)
        end

        lines = []

        if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
            lines << line.strip
          end

          list = []

          lines.split(true) { |line| line =~ /^commit\s+[0-9a-fA-F]+$/ }.each do |x|
            if x.shift =~ /^commit\s+([0-9a-fA-F]+)$/
              rev = $1.strip
              author = nil
              date = nil

              loop do
                line = x.shift

                if line.nil? or line.empty?
                  break
                end

                if line =~ /^Author:/
                  author = $'.strip

                  next
                end

                if line =~ /^Date:/
                  begin
                    date = Time.parse $'.strip
                  rescue
                    if logger
                      logger.exception $!
                    end

                    date = nil
                  end

                  next
                end
              end

              comment = []

              loop do
                line = x.shift

                if line.nil? or line.empty?
                  break
                end

                comment << line
              end

              change_files = {}

              x.each do |line|
                if line =~ /\|\s+(\d+\s+([+-]*)|Bin\s+(\d+)\s+->\s+(\d+)\s+bytes)$/
                  name = $`.strip
                  match_data = $~

                  if name =~ /^\.{3}\//
                    name = File.expands(File.join('**', $')).first.to_s
                  end

                  if match_data[2].nil?
                    if match_data[3] == '0'
                      change_files[:add] ||= []
                      change_files[:add] << name
                    else
                      if match_data[4] == '0'
                        change_files[:delete] ||= []
                        change_files[:delete] << name
                      else
                        change_files[:update] ||= []
                        change_files[:update] << name
                      end
                    end
                  else
                    if match_data[2].include? '+' and match_data[2].include? '-'
                      change_files[:update] ||= []
                      change_files[:update] << name
                    else
                      if match_data[2].include? '+'
                        change_files[:add] ||= []
                        change_files[:add] << name
                      else
                        change_files[:delete] ||= []
                        change_files[:delete] << name
                      end
                    end
                  end
                end
              end

              list << {
                rev:          rev,
                author:       author,
                date:         date,
                change_files: change_files,
                comment:      comment
              }
            end
          end

          list.reverse
        else
          nil
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      nil
    end
  end

  def self.config path = nil, name = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git config'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not name.nil?
          cmdline += ' -- %s' % name.utf8
        else
          cmdline += ' --list'
        end

        info = {}

        if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
            if line.empty?
              next
            end

            k, v = line.split('=', 2).map { |x| x.strip }

            if v.nil?
              info[name.utf8] = k
            else
              info[k] = v
            end
          end

          if not name.nil?
            info[name.utf8]
          else
            info
          end
        else
          nil
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.add path = nil, logger = nil
    dir = home path

    if not dir.nil?
      path = File.expand_path path || '.'

      Dir.chdir dir do
        cmdline = 'git add %s' % File.cmdline(path || '.')

        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.rm path = nil, logger = nil
    dir = home path

    if not dir.nil?
      path = File.expand_path path || '.'

      Dir.chdir dir do
        cmdline = 'git rm --ignore-unmatch'

        if File.directory? path
          cmdline += ' -r'
        end

        cmdline += ' %s' % File.normalize(path)

        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.diff_changes path = nil, ver = nil, diff_ver = nil, logger = nil
    dir = home path

    if not dir.nil?
      path = File.expand_path path || '.'
      ver ||= 'HEAD'
      diff_ver ||= 'HEAD^'

      Dir.chdir dir do
        cmdline = 'git diff --name-status'

        cmdline += ' %s %s' % [ver, diff_ver]
        cmdline += ' -- %s' % File.normalize(path)

        lines = []

        if 0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
            lines << line.strip
          end

          changes = []

          lines.each do |line|
            if line =~ /^[ADM]\s+.*/
              flag, name = line.split /\s+/, 2

              changes << [flag, File.expand_path(name)]
            end
          end

          changes
        else
          nil
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      nil
    end
  end

  def self.home path = nil
    path ||= '.'

    loop do
      if File.directory? File.join(path, '.git')
        return path
      end

      if File.dirname(path) == path
        break
      end

      path = File.dirname path
    end

    nil
  end

  # ----------------------------------------------------------------------------

  def self.info path = nil, logger = nil, opt = {}
    logs = log path, logger, args: '-1'

    if not logs.nil? and not logs.empty?
      info = logs.first

      info.delete :change_files
      info.delete :comment

      info[:url] = config path, 'remote.origin.url', logger
      info[:root] = home path

      info
    else
      nil
    end
  end

  def self.authorization line, stdin, username = nil, password = nil
    case line
    when /^Username.*:$/
      stdin.puts username
    when /^Password.*:$/
      stdin.puts password
    end
  end

  class << self
    private :authorization
  end
end

class GIT_TFS < GIT
  def self.clone repos, path = nil, logger = nil, opt = {}
    args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

    cmdline = 'git-tf clone'

    if not args.nil?
      cmdline += ' %s' % args
    end

    if opt.has_key? :depth
      if not opt[:depth].nil?
        cmdline += ' --depth %s' % opt[:depth]
      end
    end

    if repos =~ /\/\$\//
      cmdline += ' %s %s' % [$`, '$/%s' % $']
    else
      return nil
    end

    if not path.nil?
      cmdline += ' %s' % File.normalize(path)
    end

    username = opt[:username] || $settings[:git_username]
    password = opt[:password] || $settings[:git_password]

    if 0 != cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
        authorization line, stdin, username, password
      end

      return false
    end

    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        if not File.delete File.expands('*') - ['.git']
          return false
        end

        cmdline = 'git checkout -f'
        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.pull path = nil, logger = nil, opt = {}
    if not fetch path, logger, opt
      return false
    end

    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        cmdline = 'git merge FETCH_HEAD'
        cmdline2e(cmdline, logger).zero?
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.fetch path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git-tf fetch'

        if not args.nil?
          cmdline += ' %s' % args
        end

        username = opt[:username] || $settings[:git_username]
        password = opt[:password] || $settings[:git_password]

        0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
          authorization line, stdin, username, password
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end

  def self.push path = nil, logger = nil, opt = {}
    dir = home path

    if not dir.nil?
      Dir.chdir dir do
        args = (opt[:git_args] || opt[:args]).to_s.utf8.nil

        cmdline = 'git-tf checkin'

        if not args.nil?
          cmdline += ' %s' % args
        end

        username = opt[:username] || $settings[:git_username]
        password = opt[:password] || $settings[:git_password]

        0 == cmdline2e(cmdline, logger) do |line, stdin, wait_thr|
          authorization line, stdin, username, password
        end
      end
    else
      if logger
        logger.exception '%s is outside repository' % (path || Dir.pwd.utf8)
      end

      false
    end
  end
end