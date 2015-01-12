module Excel
  class Application
    def initialize
      WIN32OLE.ole_initialize

      @application = WIN32OLE.new 'Excel.Application'
    end

    def add template = nil
      if template.nil?
        wk = @application.WorkBooks.Add
      else
        wk = @application.WorkBooks.Add File.os(File.expand_path(template))
      end

      WorkBook.new wk
    end

    def open file
      wk = @application.WorkBooks.Open File.os(File.expand_path(file))
      WorkBook.new wk
    end

    def quit
      begin
        @application.Quit
        @application.ole_free
      rescue
      end

      @application = nil
      GC.start
    end
  end

  class WorkBook
    def initialize workbook
      @workbook = workbook
    end

    def worksheets index = 1
      @workbook.WorkSheets index
    end

    def save file = nil
      if file.nil?
        @workbook.Save
      else
        extname = File.extname(file).downcase

        if not ['.xls', '.xlsx', nil].include? extname
          if @workbook.application.Version.to_i > 11
            file += '.xlsx'
          else
            file += '.xls'
          end
        end

        if File.file? file
          File.delete file
        end

        @workbook.SaveAs File.os(File.expand_path(file))
      end
    end

    def close save = true
      @workbook.Close save
    end
  end
end