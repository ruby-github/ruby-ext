class Table
  attr_accessor :head, :rows, :foot
  attr_accessor :vertical, :horizontal, :boundary, :padding
  attr_accessor :head_align, :row_align, :foot_align

  def initialize
    @head = []
    @rows = []
    @foot = []

    @vertical   = '-'
    @horizontal = '|'
    @boundary   = '+'
    @padding    = 1

    @head_align = :center
    @row_align  = :left
    @foot_align = :right

    @max_size = 200
  end

  def rows index = nil
    if index.nil?
      @rows
    else
      @rows[index]
    end
  end

  def columns index_or_name = nil
    if index_or_name.nil?
      list = [[]] * columns_size

      @rows.each_with_index do |x, i|
        list[i] << x[i]
      end

      list
    else
      if index_or_name.is_a? Integer
        index = index_or_name
      else
        index = @head.index index_or_name
      end

      if index.nil?
        nil
      else
        list = []

        @rows.each do |x|
          list << x[index]
        end

        list
      end
    end
  end

  def uniq indexs = 0
    table = dclone

    pre = []

    table.rows.each do |x|
      x.each_index do |i|
        if not indexs.to_array.include? i
          next
        end

        if x[i].to_s == pre[i].to_s
          x[i] = nil
        else
          pre[i] = x[i]
        end
      end
    end

    table
  end

  def puts logger = nil, indent = INDENT
    logger ||= Logger.new

    widths = columns_width

    logger << "\n"
    logger << "%s%s\n" % [indent, @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary]

    if not @head.empty?
      column_line @head, widths, @head_align, logger, indent do |dev, message, i|
        if $settings[:colorize] and dev.respond_to? :colorize
          "<font color:cyan>%s</font>" % message
        else
          message
        end
      end

      logger << "%s%s\n" % [indent, @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary]
    end

    @rows.each do |x|
      column_line x, widths, @row_align, logger, indent do |dev, message, i|
        if i == widths.size - 1
          if $settings[:colorize] and dev.respond_to? :colorize
            case message.to_s.downcase.strip
            when 'true', 'ok'
              "<font color:green;highlight>%s</font>" % message
            when 'false', 'ng', 'nil', '*'
              "<font color:red;highlight>%s</font>" % message
            else
              message
            end
          else
            message
          end
        else
          message
        end
      end
    end

    logger << "%s%s\n" % [indent, @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary]

    if not @foot.empty?
      column_line @foot, widths, @head_align, logger, indent do |dev, message, i|
        if $settings[:colorize] and dev.respond_to? :colorize
          "<font color:cyan>%s</font>" % message
        else
          message
        end
      end

      logger << "%s%s\n" % [indent, @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary]
    end

    logger.flush
  end

  def to_s
    lines = []
    widths = columns_width

    lines << @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary

    if not @head.empty?
      lines << column_line(@head, widths, @head_align)
      lines << @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary
    end

    @rows.each do |x|
      lines << column_line(x, widths, @row_align)
    end

    lines << @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary

    if not @foot.empty?
      lines << column_line(@foot, widths, @head_align)
      lines << @boundary + widths.map {|size| @vertical * (size + @padding * 2)}.join(@boundary) + @boundary
    end

    lines.join "\n"
  end

  def to_array
    list = []

    if not @head.empty?
      list << @head
    end

    @rows.each do |x|
      list << x
    end

    if not @foot.empty?
      list << @foot
    end

    list
  end

  def to_excel file, index = nil, logger = nil
    begin
      application = Excel::Application.new

      if File.file? file
        wk = application.open file
        sht = wk.worksheets index || 1

        to_array.each_with_index do |row, i|
          row.each_with_index do |x, j|
            sht.Cells(i + 1, j + 1).Value = x.to_s.utf8.strip
          end
        end

        wk.save
      else
        if not File.directory? File.dirname(file)
          if not File.mkdir File.dirname(file), @logger
            return false
          end
        end

        wk = application.add
        sht = wk.worksheets index || 1

        to_array.each_with_index do |row, i|
          row.each_with_index do |x, j|
            sht.Cells(i + 1, j + 1).Value = x.to_s.utf8.strip
          end
        end

        wk.save file
      end

      wk.close

      true
    rescue
      if logger
        logger.exception $!
      end

      begin
        wk.close false
      rescue
      end

      false
    ensure
      application.quit
    end
  end

  def self.from_excel file, index = nil, logger = nil
    begin
      application = Excel::Application.new

      wk = application.open file
      sht = wk.worksheets index || 1

      table = Table.new

      if sht.UsedRange.Rows.Count > 0
        sht.UsedRange.Columns.Count.times do |i|
          table.head << sht.Cells(1, i + 1).Value.to_s.utf8.strip
        end

        (2..sht.UsedRange.Rows.Count).each do |i|
          row = []

          sht.UsedRange.Columns.Count.times do |j|
            row << sht.Cells(i, j + 1).Value.to_s.utf8.strip
          end

          table.rows << row
        end
      end

      wk.close false

      table
    rescue
      if logger
        logger.exception $!
      end

      begin
        wk.close false
      rescue
      end

      nil
    ensure
      application.quit
    end
  end

  def self.load file
    tables = []

    start = false
    lines = []

    IO.readlines(file).each do |line|
      line = line.utf8.strip

      if not start
        if line =~ /^\+(-+\+)+$/
          if not lines.empty?
            if lines.last.empty?
              lines.pop
            end

            if not lines.empty?
              table = Table.new

              if lines.first.size == 1
                table.head = lines.shift.first
              end

              if not lines.empty?
                table.rows = lines.shift
              end

              if not lines.empty?
                table.foot = lines.shift.first
              end

              tables << table
            end
          end

          start = true
          lines = [
            []
          ]
        end

        next
      end

      if line =~ /^\+(-+\+)+$/
        lines << []

        next
      end

      if line =~ /^\|(.+)\|/
        lines.last << $1.split('|').map {|x| x.utf8.strip.boolean}

        next
      end

      start = false
    end

    if not lines.empty?
      if lines.last.empty?
        lines.pop
      end

      if not lines.empty?
        table = Table.new

        if lines.first.size == 1
          table.head = lines.shift.first
        end

        if not lines.empty?
          table.rows = lines.shift
        end

        if not lines.empty?
          table.foot = lines.shift.first
        end

        tables << table
      end
    end

    tables
  end

  def self.load_action hash
    table = Table.new
    table.head = [:index, :action, :status]

    index = 1
    hash.each do |action, status|
      table.rows << [index, action, status]
      index += 1
    end

    table
  end

  private

  def columns_size
    ([@head, @foot] + @rows).map {|x| x.size}.max
  end

  def columns_width
    widths = []

    ([@head, @foot] + @rows).each do |x|
      x.each_index do |i|
        widths[i] = [[widths[i].to_i, x[i].to_s.widthsize].max, @max_size].min
      end
    end

    widths
  end

  def column_line values, widths, align, logger = nil, indent = INDENT
    if logger
      logger << indent

      widths.each_with_index do |size, i|
        logger << @horizontal

        logger.<< cell(values[i], size, align) do |dev, message|
          if block_given?
            yield dev, message, i
          else
            message
          end
        end
      end

      logger << "%s\n" % @horizontal
    else
      list = []

      widths.each_with_index do |size, i|
        list << cell(values[i], size, align)
      end

      @horizontal + list.join(@horizontal) + @horizontal
    end
  end

  def cell val, size, align
    val = cell_str val

    case align
    when :left
      space(@padding) + val + space(size - val.widthsize + @padding)
    when :right
      space(@padding + size - val.widthsize) + val + space(@padding)
    else
      space(@padding + (size - val.widthsize) / 2) + val + space((size - val.widthsize + 1) / 2 + @padding)
    end
  end

  def space size
    ' ' * size
  end

  def cell_str val
    lines = []

    val.to_s.each_line do |line|
      lines << line.strip
    end

    val = lines.join(' ').strip

    if val.widthsize > @max_size
      line = val.width_left @max_size - 4
      line + ' ...'
    else
      val
    end
  end
end

class Array
  def to_table head = true, foot = false
    table = Table.new

    if not empty?
      index = 0
      rindex = size - 1

      if head
        table.head = first
        index += 1
      end

      if foot
        if size > index
          table.foot = last
          rindex -= 1
        end
      end

      if rindex >= index
        table.rows = self[index..rindex]
      end
    end

    table
  end
end