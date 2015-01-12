class QuickTest
  attr_reader :application, :expired, :last_run_results
  attr_accessor :opt, :logger

  def initialize opt = {}
    @opt = {
      :addins               => ['java'],
      :results_location     => nil,
      :resources_libraries  => [],
      :recovery             => {},
      :run_settings         => {
        :iteration_mode     => 'rngAll',
        :start_iteration    => 1,
        :end_iteration      => 1,
        :on_error           => 'NextStep'
      }
    }.deep_merge(opt)
  end

  def open
    if @application.nil?
      if @logger
        @logger.cmdline 'quicktest open'
      end

      begin
        WIN32OLE.ole_initialize

        @application = WIN32OLE.new 'QuickTest.Application'
        sleep 3

        true
      rescue
        if @logger
          @logger.exception $!
        end

        false
      end
    else
      true
    end
  end

  def exec path, sec = nil
    path = File.expand_path path
    sec ||= 0

    if sec > 0
      sec += $settings[:quicktest_expired].to_i
    end

    @expired = false
    @last_run_results = {
      :begin    => Time.now,
      :end      => nil,
      :passed   => nil,
      :failed   => nil,
      :warnings => nil
    }

    if not validate? path
      if @logger
        @logger.error 'it is not a valid quicktest case - %s' % path
      end

      return false
    end

    if @logger
      @logger.cmdline 'quicktest exec %s' % path
    end

    if not open
      return false
    end

    begin
      if @application.Launched
        @application.Quit
      end

      # addins
      if not @opt[:addins].nil?
        @application.SetActiveAddins @opt[:addins].sort.uniq, 'set active addins fail'
      end

      # launch
      @application.Launch
      @application.Visible = true
      @application.Options.Run.RunMode = 'Fast'
      @application.Open path, false, false

      # test
      sleep 3
      test = @application.Test
      sleep 3

      # resources_libraries
      if not @opt[:resources_libraries].nil?
        libs = []

        @opt[:resources_libraries].each do |library_path|
          File.expands(library_path).each do |lib|
            libs << File.expand_path(lib)
          end
        end

        test.Settings.Resources.Libraries.RemoveAll

        libs.sort.uniq.each do |lib|
          test.Settings.Resources.Libraries.Add lib, -1
        end

        test.Settings.Resources.Libraries.SetAsDefault
      end

      # recovery
      if not @opt[:recovery].nil?
        test.Settings.Recovery.RemoveAll

        @opt[:recovery].each do |scenario_file, scenario_name|
          test.Settings.Recovery.Add File.expand_path(scenario_file), scenario_name, -1
        end

        test.Settings.Recovery.Count.times do |i|
          test.Settings.Recovery.Item(i + 1).Enabled = true
        end

        test.Settings.Recovery.Enabled = true
        test.Settings.Recovery.SetActivationMode 'OnEveryStep'
        test.Settings.Recovery.SetAsDefault
      end

      # run_settings
      if not @opt[:run_settings].nil?
        if not @opt[:run_settings][:iteration_mode].nil?
          test.Settings.Run.IterationMode = @opt[:run_settings][:iteration_mode]
        end

        if not @opt[:run_settings][:start_iteration].nil?
          test.Settings.Run.StartIteration = @opt[:run_settings][:start_iteration]
        end

        if not @opt[:run_settings][:end_iteration].nil?
          test.Settings.Run.EndIteration = @opt[:run_settings][:end_iteration]
        end

        if not @opt[:run_settings][:on_error].nil?
          test.Settings.Run.OnError = @opt[:run_settings][:on_error]
        end
      end

      test.Save
      sleep 3

      # run_results_options
      run_results_options = WIN32OLE.new 'QuickTest.RunResultsOptions'
      if not @opt[:results_location].nil?
        run_results_options.ResultsLocation = File.expand_path @opt[:results_location]
      end

      sleep 3
      test.Run run_results_options, false, nil
      sleep 3

      while test.IsRunning
        duration = Time.now - @last_run_results[:begin]

        if sec > 0 and duration > sec
          if @logger
            @logger.exception Exception.new('execution expired - %s' % sec)
          end

          test.Stop
          Image::Capture.desktop File.join(path, 'expired.png'), @logger

          @expired = true
        end

        sleep 1
      end

      if block_given?
        yield test
      end

      path = test.LastRunResults.Path
      status = test.LastRunResults.Status

      test.Close
      @application.Quit

      @last_run_results[:end] = Time.now

      begin
        doc = REXML::Document.file File.join(path, 'Report/Results.xml')

        REXML::XPath.each(doc, '/Report/Doc/Summary') do |e|
          @last_run_results[:passed] = e.attributes['passed'].to_i
          @last_run_results[:failed] = e.attributes['failed'].to_i
          @last_run_results[:warnings] = e.attributes['warnings'].to_i

          break
        end
      rescue
        if @logger
          @logger.exception $!
        end
      end

      if @logger
        @logger.debug '=' * 60

        @last_run_results.each do |k, v|
          @logger.debug '%s%s%s:%s' % [INDENT, k, ' ' * (18 - k.to_s.bytesize), v]
        end

        @logger.debug '=' * 60
        @logger.flush
      end

      if status == 'Passed'
        true
      else
        Image::Capture.desktop File.join(path, 'fail.png'), @logger

        false
      end
    rescue Interrupt => e
      if @logger
        @logger << "%s<font color:cyan>quicktest interrupt:%s</font>\n" % [INDENT, path]
        @logger.flush
      end

      close

      raise
    rescue
      if @logger
        @logger.exception $!
        @logger.flush
      end

      close

      Image::Capture.desktop File.join(path, 'exception.png'), @logger

      false
    end
  end

  def create path, src = nil, expand = false
    path = File.expand_path path

    if @logger
      @logger.cmdline 'quicktest create %s' % path
    end

    if not src.nil?
      if File.same_path? path, src, true
        return true
      end
    end

    if not open
      return false
    end

    status = true

    begin
      if @application.Launched
        @application.Quit
      end

      @application.Launch
      @application.New false

      if File.mkdir path, @logger
        @application.Test.SaveAs File.os(path)
      else
        status = false
      end

      @application.Quit
    rescue
      if @logger
        @logger.exception $!
      end

      close

      File.delete path, @logger

      status = false
    end

    if status
      if not src.nil?
        if File.directory? src
          if not File.copy File.join(src, '*'), path, @logger
            status = false
          end

          if expand
            if not File.copy File.join(src, '../*.{xls,xlsx}'), File.dirname(path), @logger
              status = false
            end
          end
        else
          if @logger
            @logger.error 'no such directory - %s' % src
          end

          status = false
        end
      end
    end

    if @logger
      @logger.flush
    end

    status
  end

  def table_external_editors list
    begin
      if @logger
        @logger.cmdline 'quicktest table_external_editors: %s' % list.join(' ')
      end

      @application.Launch
      @application.Options.Java.TableExternalEditors = list.join ' '
      @application.Quit

      true
    rescue
      if @logger
        @logger.exception $!
      end

      false
    end
  end

  def datatable path
    Table.from_excel File.join(path, 'Default.xls'), nil, @logger
  end

  def validate? path
    File.file? File.join(path, 'Action1/Script.mts')
  end

  def close
    if not @application.nil?
      if @logger
        @logger.cmdline 'quicktest close'
      end

      begin
        if @application.Launched
          @application.Test.Stop
          @application.Test.Close
          @application.Quit
        end

        true
      rescue
        if @logger
          @logger.exception $!
        end

        QuickTest.kill @logger

        false
      ensure
        begin
          @application.ole_free
        rescue
        end

        if @logger
          @logger.flush
        end

        @application = nil
        GC.start
        sleep 3
      end
    else
      true
    end
  end

  def self.kill logger = nil
    OS.kill logger do |pid, info|
      ['QTAutomationAgent.exe', 'QTPro.exe'].include? info[:name]
    end
  end
end