module Counter
  class Counter
    attr_reader :counters

    def initialize
      @counters = []
    end

    def counter file
      counter_lines IO.readlines(file), File.extname(file)
    end

    def counter_lines lines, extname
      language extname

      @comment      = false
      @comment_flag = true
      @quote1       = false
      @quote2       = false

      @counters = []

      lines.each do |line|
        line = line.utf8

        @counters << [counter_line(line), line]

        if not @continue_quote
          if @continue_line
            if line[-@continue_line.size..-1] != @continue_line
              @quote1 = false
              @quote2 = false
            end
          else
            @quote1 = false
            @quote2 = false
          end
        end
      end

      count
    end

    def count counters = @counters
      total_lines = counters.size
      code_lines = 0
      comment_lines = 0
      empty_lines = 0

      counters.each do |x|
        case x.first
        when :code_line
          code_lines += 1
        when :comment_line
          comment_lines += 1
        when :code_comment_line
          code_lines += 1
          comment_lines += 1
        when :empty_line
          empty_lines += 1
        else
          code_lines += 1
        end
      end

      [total_lines, code_lines, comment_lines, empty_lines]
    end

    private

    def counter_line line
      line.strip!

      if line.empty?
        if not @continue_quote
          @quote1 = false
          @quote2 = false
        end

        :empty_line
      else
        if @comment
          if @comment_flag
            comment_pos = line.index @comment_off
          else
            comment_pos = line.index @comment_off2
          end

          if comment_pos
            @comment = false

            line = line[comment_pos + @comment_off.size .. -1].strip

            if not line.empty?
              if [:code_line, :code_comment_line].include? counter_line(line)
                return :code_comment_line
              end
            end
          end

          :comment_line
        else
          if @quote1 or @quote2
            if @quote1
              pos = line.index @quotation1

              if pos
                if @escape
                  if pos == 0 or line[pos - 1 .. pos - 1] != @escape
                    @quote1 = false
                  end
                else
                  @quote1 = false
                end

                line = line[pos + @quotation1.size .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? counter_line(line)
                    return :code_comment_line
                  end
                end
              end
            else
              pos = line.index @quotation2

              if pos
                if @escape
                  if pos == 0 or line[pos - 1 .. pos - 1] != @escape
                    @quote2 = false
                  end
                else
                  @quote2 = false
                end

                line = line[pos + @quotation2.size .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? counter_line(line)
                    return :code_comment_line
                  end
                end
              end
            end

            :code_line
          else
            comment_pos = nil
            comment_line_flag = false
            comment_len = 0

            if @line_comment and line.index(@line_comment)
              comment_pos = line.index @line_comment
              comment_line_flag = true
              comment_len = @line_comment.size
            end

            if @line_comment2 and line.index(@line_comment2)
              comment_pos = line.index @line_comment2
              comment_line_flag = true
              comment_len = @line_comment2.size
            end

            if @comment_on and line.index(@comment_on)
              tmp_comment_pos = line.index @comment_on

              if not comment_pos or tmp_comment_pos < comment_pos
                comment_pos = tmp_comment_pos
                @comment_flag = true
                comment_len = @comment_on.size
              end
            end

            if @comment_on2 and line.index(@comment_on2)
              tmp_comment_pos = line.index @comment_on2

              if not comment_pos or tmp_comment_pos < comment_pos
                comment_pos = tmp_comment_pos
                @comment_flag = false
                comment_len = @comment_on2.size
              end
            end

            quote_pos = nil
            quote1_flag = false
            quote_len = 0

            if @quotation1 and line.index(@quotation1)
              quote_pos = line.index @quotation1
              quote1_flag = true
              quote_len = @quotation1.size
            end

            if @quotation2 and line.index(@quotation2)
              tmp_quote_pos = line.index @quotation2

              if not quote_pos or tmp_quote_pos < quote_pos
                quote_pos = tmp_quote_pos
                quote1_flag = false
                quote_len = @quotation2.size
              end
            end

            if comment_pos
              if quote_pos and quote_pos < comment_pos
                if quote1_flag
                  @quote1 = true
                else
                  @quote2 = true
                end

                line = line[quote_pos + quote_len .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? counter_line(line)
                    return :code_comment_line
                  end
                end

                :code_line
              else
                if not comment_line_flag
                  @comment = true

                  line = line[comment_pos + comment_len .. -1].strip

                  if not line.empty?
                    if [:code_line, :code_comment_line].include? counter_line(line)
                      return :code_comment_line
                    end
                  end
                end

                if comment_pos > 0
                  :code_comment_line
                else
                  :comment_line
                end
              end
            else
              if quote_pos
                if quote1_flag
                  @quote1 = true
                else
                  @quote2 = true
                end

                line = line[quote_pos + quote_len .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? counter_line(line)
                    return :code_comment_line
                  end
                end
              end

              :code_line
            end
          end
        end
      end
    end

    def language extname
      extname.downcase!

      @line_comment   = nil
      @line_comment2  = nil
      @comment_on     = nil
      @comment_off    = nil
      @comment_on2    = nil
      @comment_off2   = nil
      @quotation1     = nil
      @quotation2     = nil
      @continue_quote = false
      @continue_line  = nil
      @escape         = nil
      @case           = true

      case extname
      when
        # ASM
        '.asm'
        @line_comment   = ';'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = false
      when
        # C#
        '.cs',
        # C/C++
        '.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.hxx',
        # IDL
        '.idl', '.odl',
        # Java
        '.java',
        # JavaFX
        '.fx',
        # JavaScript
        '.es', '.js',
        # RC
        '.rc', '.rc2'
        @line_comment   = '//'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @continue_line  = '\\'
        @escape         = '\\'
        @case           = true
      when
        # HTML
        '.htm', '.html', '.shtml'
        @comment_on     = '<!--'
        @comment_off    = '-->'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = false
      when
        # Lua
        '.lua'
        @line_comment   = '--'
        @comment_on     = '--[['
        @comment_off    = ']]'
        @comment_on2    = '--[=['
        @comment_off2   = ']=]'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Pascal
        '.pas'
        @line_comment   = '//'
        @comment_on     = '(*'
        @comment_off    = '*)'
        @comment_on2    = '{'
        @comment_off2   = '}'
        @quotation1     = '\''
        @continue_quote = false
        @case           = false
      when
        # Perl
        '.pl', '.pm'
        @line_comment   = '--'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Python
        '.py', '.pyw'
        @line_comment   = '#'
        @comment_on     = '"""'
        @comment_off    = '"""'
        @comment_on2    = "'''"
        @comment_off2   = "'''"
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Ruby
        '.rake', '.rb', '.rbw'
        @line_comment   = '#'
        @comment_on     = '=begin'
        @comment_off    = '=end'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # SQL
        '.sql'
        @line_comment   = '--'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = false
      when
        # Tcl/Tk
        '.itcl', '.tcl'
        @line_comment   = '#'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @escape         = '\\'
        @case           = true
      when
        # VB
        '.bas', '.vb',
        # VBScript
        '.vbs'
        @line_comment   = '\''
        @line_comment2  = 'rem'
        @quotation1     = '"'
        @escape         = '\\'
        @case           = false
      when
        # VHDL
        '.vhd', '.vhdl'
        @line_comment   = '--'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = false
      when
        # Verilog
        '.v', '.vh'
        @line_comment   = '//'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Windows Script Batch
        '.bat'
        @line_comment   = 'rem'
        @line_comment2  = '@rem'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @case           = false
      when
        # XML
        '.axl', '.dtd', '.rdf', '.svg', '.xml', '.xrc', '.xsd', '.xsl', '.xslt', '.xul'
        @comment_on     = '<!--'
        @comment_off    = '-->'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = true
      end
    end
  end

  class Diff
    attr_reader :diffs, :discard
    attr_accessor :context_line

    def initialize
      @diffs = {}
      @discard = []
      @context_line = 3
    end

    def diff file, diff_file
      diff_lines IO.readlines(file), IO.readlines(diff_file), file, diff_file
    end

    def diff_lines file_lines, diff_file_lines = nil, name = nil, diff_name = nil
      @diffs = {
        :names    => [
          name, diff_name
        ],
        :lines    => {},
        :discard  => []
      }

      lcs = diff_lcs file_lines, diff_file_lines

      a_index = 0
      b_index = 0

      @discard = []

      while b_index < lcs.size
        a_cur_index = lcs[b_index]

        if a_cur_index
          while a_index < a_cur_index
            discard_a a_index, file_lines[a_index]
            a_index += 1
          end

          match
          a_index += 1
        else
          discard_b b_index, diff_file_lines[b_index]
        end

        b_index += 1
      end

      while b_index < diff_file_lines.size
        discard_b b_index, diff_file_lines[b_index]
        b_index += 1
      end

      while a_index < file_lines.size
        discard_a a_index, file_lines[a_index]
        a_index += 1
      end

      match

      lcs.each_with_index do |i, index|
        if not i.nil?
          @diffs[:lines][index] = [i, diff_file_lines[index]]
        end
      end

      add_count = 0
      change_count = 0
      del_count = 0

      @diffs[:discard].each do |discard|
        add_lines = 0
        del_lines = 0

        discard.each do |action, index, line|
          case action
          when '+'
            add_lines += 1
          when '-'
            del_lines += 1
          end
        end

        change_count += [add_lines, del_lines].min

        if add_lines >= del_lines
          add_count += add_lines - del_lines
        else
          del_count += del_lines - add_lines
        end
      end

      [add_count, change_count, del_count]
    end

    def to_diff
      string_io = StringIO.new
      offset = 0

      @diffs[:discard].each do |discard|
        action = discard[0][0]
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          string_io.puts diff_range(first + 1, first + del_count) + 'd' + (first + offset).to_s
        elsif del_count == 0
          string_io.puts (first - offset).to_s + 'a' + diff_range(first + 1, first + add_count)
        else
          string_io.puts diff_range(first + 1, first + del_count) + 'c' + diff_range(first + offset + 1, first + offset + add_count)
        end

        if action == '-'
          last_del = true
        else
          last_del = false
        end

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            string_io.print '< '
          elsif action == '+'
            offset += 1

            if last_del
              last_del = false
              string_io.puts '---'
            end

            string_io.print '> '
          end

          string_io.print line
        end
      end

      string_io.string.strip
    end

    def to_diff_context
      string_io = StringIO.new

      file, diff_file = @diffs[:names]

      if File.file? file
        string_io.puts '*** ' + file + "\t" + File.mtime(file).to_s
      else
        string_io.puts '*** ' + file.to_s
      end

      if File.file? diff_file
        string_io.puts '--- ' + diff_file + "\t" + File.mtime(diff_file).to_s
      else
        string_io.puts '--- ' + diff_file.to_s
      end

      offset = 0
      keys = @diffs[:lines].keys

      @diffs[:discard].each do |discard|
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          a_start = first + 1
          b_start = first + offset + 1
        elsif del_count == 0
          a_start = first - offset + 1
          b_start = first + 1
        else
          a_start = first + 1
          b_start = first + offset + 1
        end

        a_count = del_count
        b_count = add_count

        prefix_lines = []
        suffix_lines = []

        (a_start - 1).times.to_a.reverse.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          prefix_lines.unshift @diffs[:lines][i].last
        end

        ((a_start + a_count - 1)..keys.last).to_a.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          suffix_lines.push @diffs[:lines][i].last
        end

        string_io.puts '***************'

        a_lines = []
        b_lines = []

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            a_lines << line
          elsif action == '+'
            offset += 1
            b_lines << line
          end
        end

        if a_lines.empty? or b_lines.empty?
          action = nil
        else
          action = '! '
        end

        string_io.puts "*** #{a_start - prefix_lines.size},#{a_start + a_count - 1 + suffix_lines.size} ****"

        if not a_lines.empty?
          prefix_lines.each do |line|
            string_io.print '  ' + line
          end

          a_lines.each do |line|
            string_io.print (action || '- ') + line
          end

          suffix_lines.each do |line|
            string_io.print '  ' + line
          end
        end

        if not ["\r", "\n"].include? string_io.string[-1]
          string_io.puts
        end

        string_io.puts "--- #{b_start - prefix_lines.size},#{b_start + b_count - 1 + suffix_lines.size} ----"

        if not b_lines.empty?
          prefix_lines.each do |line|
            string_io.print '  ' + line
          end

          b_lines.each do |line|
            string_io.print (action || '+ ') + line
          end

          suffix_lines.each do |line|
            string_io.print '  ' + line.rstrip
          end
        end
      end

      string_io.string.strip
    end

    def to_diff_unified
      string_io = StringIO.new

      file, diff_file = @diffs[:names]

      if File.file? file
        string_io.puts '--- ' + file + "\t" + File.mtime(file).to_s
      else
        string_io.puts '--- ' + file.to_s
      end

      if File.file? diff_file
        string_io.puts '+++ ' + diff_file + "\t" + File.mtime(diff_file).to_s
      else
        string_io.puts '+++ ' + diff_file.to_s
      end

      offset = 0
      keys = @diffs[:lines].keys

      @diffs[:discard].each do |discard|
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          a_start = first + 1
          b_start = first + offset + 1
        elsif del_count == 0
          a_start = first - offset + 1
          b_start = first + 1
        else
          a_start = first + 1
          b_start = first + offset + 1
        end

        a_count = del_count
        b_count = add_count

        prefix_lines = []
        suffix_lines = []

        (a_start - 1).times.to_a.reverse.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          prefix_lines.unshift @diffs[:lines][i].last
        end

        ((a_start + a_count - 1)..keys.last).to_a.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          suffix_lines.push @diffs[:lines][i].last
        end

        string_io.puts "@@ -#{a_start - prefix_lines.size},#{a_count + prefix_lines.size + suffix_lines.size} +#{b_start - prefix_lines.size},#{b_count + prefix_lines.size + suffix_lines.size} @@"

        prefix_lines.each do |line|
          string_io.print ' ' + line
        end

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            string_io.print '-'
          elsif action == '+'
            offset += 1
            string_io.print '+'
          end

          string_io.print line
        end

        suffix_lines.each do |line|
          string_io.print ' ' + line
        end
      end

      string_io.string.strip
    end

    private

    def diff_lcs a, b
      a_start = 0
      a_finish = a.size - 1

      b_start = 0
      b_finish = b.size - 1

      lcs = []

      while a_start <= b_finish and b_start <= b_finish and a[a_start] == b[b_start]
        lcs[b_start] = a_start

        a_start += 1
        b_start += 1
      end

      while a_start <= a_finish and b_start <= b_finish and a[a_finish] == b[b_finish]
        lcs[b_finish] = a_finish

        a_finish -= 1
        b_finish -= 1
      end

      a_matches = reverse_hash a, a_start..a_finish
      thresh = []
      links = []

      (b_start..b_finish).each do |i|
        if not a_matches.has_key? b[i]
          next
        end

        index = nil

        a_matches[b[i]].reverse.each do |j|
          if index and thresh[index] > j and thresh[index - 1] < j
            thresh[index] = j
          else
            index = replace_next_larger thresh, j, index
          end

          if not index.nil?
            if index == 0
              links[index] = [nil, i, j]
            else
              links[index] = [links[index - 1], i, j]
            end
          end
        end
      end

      if not thresh.empty?
        link = links[thresh.size - 1]

        while link
          lcs[link[1]] = link[2]
          link = link[0]
        end
      end

      lcs
    end

    def diff_range a, b
      if a == b
        a.to_s
      else
        [a, b].join ','
      end
    end

    def reverse_hash obj, range = nil
      map = {}
      range ||= 0...obj.size

      range.each do |i|
        map[obj[i]] ||= []
        map[obj[i]] << i
      end

      map
    end

    def replace_next_larger obj, val, high = nil
      high ||= obj.size

      if obj.empty? or val > obj[-1]
        obj << val

        return high
      end

      low = 0

      while low < high
        index = (low + high) / 2
        found = obj[index]

        if val == found
          return nil
        end

        if val > found
          low = index + 1
        else
          high = index
        end
      end

      obj[low] = val

      low
    end

    def discard_a index, line
      @discard << ['+', index, line]
    end

    def discard_b index, line
      @discard << ['-', index, line]
    end

    def match
      if not @discard.empty?
        @diffs[:discard] << @discard
      end

      @discard = []
    end
  end

  module CodeCounter
    # :code
    #   - total_lines
    #   - code_lines
    #   - comment_lines
    #   - empty_lines
    #
    # :diff
    #   - [total_add_lines, total_change_lines, total_delete_lines]
    #   - [code_add_lines, code_change_lines, code_delete_lines]
    #   - [comment_add_lines, comment_change_lines, comment_delete_lines]
    #   - [empty_add_lines, empty_change_lines, empty_delete_lines]
    def self.count file, diff_file = nil
      if diff_file.nil?
        lines = nil
      else
        lines = IO.readlines diff_file
      end

      count_lines IO.readlines(file), file, lines, diff_file
    end

    def self.count_lines lines, name = nil, diff_lines = nil, diff_name = nil
      counter = Counter.new

      map = {
        :code => counter.counter_lines(lines, File.extname(name.to_s))
      }

      if not diff_lines.nil?
        counters = counter.counters

        diff = Diff.new
        diff.diff_lines lines, diff_lines, name, diff_name

        if not diff.diffs[:discard].empty?
          counter.counter_lines diff_lines, File.extname(diff_name.to_s)
          diff_counters = counter.counters

          diff_info = [
            [0, 0, 0],
            [0, 0, 0],
            [0, 0, 0],
            [0, 0, 0]
          ]

          diff.diffs[:discard].each do |discard|
            add_lines = []
            del_lines = []

            discard.each do |action, index, line|
              case action
              when '+'
                add_lines << [counters[index].first, line]
              when '-'
                del_lines << [diff_counters[index].first, line]
              end
            end

            if add_lines.size >= del_lines.size
              add_info = counter.count add_lines[del_lines.size..-1]
              change_info = counter.count add_lines[0...del_lines.size]
              del_info = [0, 0, 0, 0]
            else
              add_info = [0, 0, 0, 0]
              change_info = counter.count del_lines[0...add_lines.size]
              del_info = counter.count del_lines[add_lines.size..-1]
            end

            diff_info[0][0] += add_info[0]
            diff_info[0][1] += change_info[0]
            diff_info[0][2] += del_info[0]

            diff_info[1][0] += add_info[1]
            diff_info[1][1] += change_info[1]
            diff_info[1][2] += del_info[1]

            diff_info[2][0] += add_info[2]
            diff_info[2][1] += change_info[2]
            diff_info[2][2] += del_info[2]

            diff_info[3][0] += add_info[3]
            diff_info[3][1] += change_info[3]
            diff_info[3][2] += del_info[3]
          end

          map[:diff] = diff_info
        end
      end

      map
    end

    # ver
    #   :code
    #     - total_lines
    #     - code_lines
    #     - comment_lines
    #     - empty_lines
    #
    #   :diff
    #     - [total_add_lines, total_change_lines, total_delete_lines]
    #     - [code_add_lines, code_change_lines, code_delete_lines]
    #     - [comment_add_lines, comment_change_lines, comment_delete_lines]
    #     - [empty_add_lines, empty_change_lines, empty_delete_lines]
    #
    #   :info
    #     name
    #       :flag
    #         - A: add, M: change, D: delete, nil: none
    #
    #       :ver
    #         - [author, ver, time]
    #         - [diff_author, diff_ver, diff_time]
    #
    #       :code
    #         - total_lines
    #         - code_lines
    #         - comment_lines
    #         - empty_lines
    #
    #       :diff
    #         - [total_add_lines, total_change_lines, total_delete_lines]
    #         - [code_add_lines, code_change_lines, code_delete_lines]
    #         - [comment_add_lines, comment_change_lines, comment_delete_lines]
    #         - [empty_add_lines, empty_change_lines, empty_delete_lines]
    def self.code_count path, diff_path = nil, opt = nil, logger = nil, &block
      path = File.normalize path

      opt ||= {}

      info = nil

      if diff_path.nil?
        case opt[:scm]
        when :git
          info = diff_count_git path, logger, opt, &block
        when :svn
          info = diff_count_svn path, logger, opt, &block
        else
          info = diff_count path, logger, &block
        end
      else
        diff_path = File.normalize diff_path

        if (File.file? path and File.file? diff_path) or (File.directory? path and File.directory? diff_path)
          info = diff_count_path path, diff_path, logger, &block
        else
          if logger
            logger.error 'path and diff_path do not match, it must file or directory at the same time'
          end
        end
      end

      if not info.nil?
        map = {}

        pre_code_info = nil

        info.keys.sort.each do |revision|
          if info[revision].nil? or info[revision].empty?
            next
          end

          if pre_code_info.nil?
            map[revision] = {
              :code => [0, 0, 0, 0]
            }
          else
            map[revision] = {
              :code => pre_code_info
            }
          end

          info[revision].each do |name, x|
            if x.nil?
              next
            end

            if not x[:diff].nil?
              map[revision][:diff] ||= [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]
              ]

              map[revision][:diff].deep_merge! x[:diff]
            end

            if pre_code_info.nil? and not opt[:inc]
              map[revision][:code].deep_merge! x[:code]
            end
          end

          if not map[revision][:diff].nil?
            map[revision][:code].deep_merge! [
              map[revision][:diff][0][0] - map[revision][:diff][0][2],
              map[revision][:diff][1][0] - map[revision][:diff][1][2],
              map[revision][:diff][2][0] - map[revision][:diff][2][2],
              map[revision][:diff][3][0] - map[revision][:diff][3][2]
            ]
          end

          map[revision][:info] = info[revision]
          pre_code_info = map[revision][:code].dclone
        end

        map
      else
        nil
      end
    end

    def self.to_excel info, file, scm_map = nil, logger = nil
      scm_map ||= {}

      if not File.directory? File.dirname(file)
        if not File.mkdir File.dirname(file), logger
          return false
        end
      end

      map = {
        :ext        => {},
        :author     => {},
        :division   => {},
        :department => {},
        :project    => {}
      }

      info[:info].each do |url, revisions|
        if revisions.nil?
          next
        end

        revisions.each do |revision, revision_info|
          if revision_info.nil?
            next
          end

          revision_info.each do |name, x|
            if x.nil?
              next
            end

            ext = File.extname(name).downcase
            map[:ext][ext] ||= [
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0]
            ]

            author = nil

            if not x[:ver].nil? and not x[:ver].first.nil?
              author = x[:ver].first.first
            end

            if not x[:diff].nil?
              map[:ext][ext].deep_merge! x[:diff]

              map[:author][author] ||= {
                :code => [0, 0, 0, 0],
                :diff => [
                  [0, 0, 0],
                  [0, 0, 0],
                  [0, 0, 0],
                  [0, 0, 0]
                ]
              }

              map[:author][author][:diff].deep_merge! x[:diff]
            end

            map[:author][author] ||= {
              :code => [0, 0, 0, 0],
              :diff => [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]
              ]
            }

            map[:author][author][:code].deep_merge! x[:code]
          end
        end
      end

      map[:author].each do |author, author_info|
        employee_id, employee_name, division, department, project = scm_map[author] || []

        if division.nil?
          division = '未知'
        end

        if department.nil?
          department = '未知'
        else
          #department = division.to_s + ':' + department
        end

        if project.nil?
          project = '未知'
        end

        # division
        map[:division][division] ||= {
          :code => [0, 0, 0, 0],
          :diff => [
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0]
            ]
        }

        map[:division][division][:code].deep_merge! author_info[:code]
        map[:division][division][:diff].deep_merge! author_info[:diff]

        # department
        map[:department][department] ||= {
          :code => [0, 0, 0, 0],
          :diff => [
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0]
            ]
        }

        map[:department][department][:code].deep_merge! author_info[:code]
        map[:department][department][:diff].deep_merge! author_info[:diff]

        # project
        map[:project][project] ||= {
          :code => [0, 0, 0, 0],
          :diff => [
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0],
              [0, 0, 0]
            ]
        }

        map[:project][project][:code].deep_merge! author_info[:code]
        map[:project][project][:diff].deep_merge! author_info[:diff]
      end

      begin
        application = Excel::Application.new

        wk = application.add File.join(gem_dir('rspec-auto'), 'doc/counter_template.xlt')

        # 汇总信息
        sht = wk.worksheets 1

        sht.Cells(1, 4).Value = info[:code][0]
        sht.Cells(2, 4).Value = info[:code][1]
        sht.Cells(3, 4).Value = info[:code][2]
        sht.Cells(4, 4).Value = info[:code][3]

        diff = info[:diff]

        if diff.nil?
          diff = [
            [0, 0, 0],
            [0, 0, 0],
            [0, 0, 0],
            [0, 0, 0]
          ]
        end

        sht.Cells(5, 4).Value = diff[0][0]
        sht.Cells(6, 4).Value = diff[0][1]
        sht.Cells(7, 4).Value = diff[0][2]

        sht.Cells(8, 4).Value = diff[1][0]
        sht.Cells(9, 4).Value = diff[1][1]
        sht.Cells(10, 4).Value = diff[1][2]

        sht.Cells(11, 4).Value = diff[2][0]
        sht.Cells(12, 4).Value = diff[2][1]
        sht.Cells(13, 4).Value = diff[2][2]

        index = 4

        map[:ext].each do |extname, diff|
          sht.Cells(14, index).Value = extname

          sht.Cells(15, index).Value = diff[0][0]
          sht.Cells(16, index).Value = diff[0][1]
          sht.Cells(17, index).Value = diff[0][2]

          sht.Cells(18, index).Value = diff[1][0]
          sht.Cells(19, index).Value = diff[1][1]
          sht.Cells(20, index).Value = diff[1][2]

          sht.Cells(21, index).Value = diff[2][0]
          sht.Cells(22, index).Value = diff[2][1]
          sht.Cells(23, index).Value = diff[2][2]

          index += 1
        end

        # 人员统计信息
        sht = wk.worksheets 2

        index = 4

        map[:author].each do |author, author_info|
          if not scm_map[author].nil?
            employee_id, employee_name, division, department, project = scm_map[author]
            author = (employee_name || author).to_s + '(' + employee_id.to_s + ')'
          end

          sht.Cells(index, 1).Value = author

          sht.Cells(index, 2).Value = author_info[:code][0]
          sht.Cells(index, 3).Value = author_info[:code][1]
          sht.Cells(index, 4).Value = author_info[:code][2]
          sht.Cells(index, 5).Value = author_info[:code][3]

          sht.Cells(index, 6).Value = author_info[:diff][0][0]
          sht.Cells(index, 7).Value = author_info[:diff][0][1]
          sht.Cells(index, 8).Value = author_info[:diff][0][2]

          sht.Cells(index, 9).Value = author_info[:diff][1][0]
          sht.Cells(index, 10).Value = author_info[:diff][1][1]
          sht.Cells(index, 11).Value = author_info[:diff][1][2]

          sht.Cells(index, 12).Value = author_info[:diff][2][0]
          sht.Cells(index, 13).Value = author_info[:diff][2][1]
          sht.Cells(index, 14).Value = author_info[:diff][2][2]

          index += 1
        end

        # 部门统计信息
        sht = wk.worksheets 3

        index = 4

        map[:division].each do |division, division_info|
          sht.Cells(index, 1).Value = division

          sht.Cells(index, 2).Value = division_info[:code][0]
          sht.Cells(index, 3).Value = division_info[:code][1]
          sht.Cells(index, 4).Value = division_info[:code][2]
          sht.Cells(index, 5).Value = division_info[:code][3]

          sht.Cells(index, 6).Value = division_info[:diff][0][0]
          sht.Cells(index, 7).Value = division_info[:diff][0][1]
          sht.Cells(index, 8).Value = division_info[:diff][0][2]

          sht.Cells(index, 9).Value = division_info[:diff][1][0]
          sht.Cells(index, 10).Value = division_info[:diff][1][1]
          sht.Cells(index, 11).Value = division_info[:diff][1][2]

          sht.Cells(index, 12).Value = division_info[:diff][2][0]
          sht.Cells(index, 13).Value = division_info[:diff][2][1]
          sht.Cells(index, 14).Value = division_info[:diff][2][2]

          index += 1
        end

        # 科室统计信息
        sht = wk.worksheets 4

        index = 4

        map[:department].each do |department, department_info|
          sht.Cells(index, 1).Value = department

          sht.Cells(index, 2).Value = department_info[:code][0]
          sht.Cells(index, 3).Value = department_info[:code][1]
          sht.Cells(index, 4).Value = department_info[:code][2]
          sht.Cells(index, 5).Value = department_info[:code][3]

          sht.Cells(index, 6).Value = department_info[:diff][0][0]
          sht.Cells(index, 7).Value = department_info[:diff][0][1]
          sht.Cells(index, 8).Value = department_info[:diff][0][2]

          sht.Cells(index, 9).Value = department_info[:diff][1][0]
          sht.Cells(index, 10).Value = department_info[:diff][1][1]
          sht.Cells(index, 11).Value = department_info[:diff][1][2]

          sht.Cells(index, 12).Value = department_info[:diff][2][0]
          sht.Cells(index, 13).Value = department_info[:diff][2][1]
          sht.Cells(index, 14).Value = department_info[:diff][2][2]

          index += 1
        end

        # 项目统计信息
        sht = wk.worksheets 5

        index = 4

        map[:project].each do |project, project_info|
          sht.Cells(index, 1).Value = project

          sht.Cells(index, 2).Value = project_info[:code][0]
          sht.Cells(index, 3).Value = project_info[:code][1]
          sht.Cells(index, 4).Value = project_info[:code][2]
          sht.Cells(index, 5).Value = project_info[:code][3]

          sht.Cells(index, 6).Value = project_info[:diff][0][0]
          sht.Cells(index, 7).Value = project_info[:diff][0][1]
          sht.Cells(index, 8).Value = project_info[:diff][0][2]

          sht.Cells(index, 9).Value = project_info[:diff][1][0]
          sht.Cells(index, 10).Value = project_info[:diff][1][1]
          sht.Cells(index, 11).Value = project_info[:diff][1][2]

          sht.Cells(index, 12).Value = project_info[:diff][2][0]
          sht.Cells(index, 13).Value = project_info[:diff][2][1]
          sht.Cells(index, 14).Value = project_info[:diff][2][2]

          index += 1
        end

        # 变更文件统计信息
        sht = wk.worksheets 6

        index = 4

        info[:info].each do |url, revisions|
          if revisions.nil?
            next
          end

          revisions.each do |revision, revision_info|
            if revision_info.nil?
              next
            end

            revision_info.each do |name, x|
              if x.nil?
                next
              end

              if x[:flag].nil?
                next
              end

              sht.Cells(index, 1).Value = name
              sht.Cells(index, 2).Value = x[:flag]

              if not x[:ver].nil? and not x[:ver].first.nil?
                sht.Cells(index, 3).Value = x[:ver].first[0]
                sht.Cells(index, 4).Value = x[:ver].first[1]
                sht.Cells(index, 5).Value = x[:ver].first[2]
              end

              sht.Cells(index, 6).Value = x[:code][0]
              sht.Cells(index, 7).Value = x[:code][1]
              sht.Cells(index, 8).Value = x[:code][2]
              sht.Cells(index, 9).Value = x[:code][3]

              if not x[:diff].nil?
                sht.Cells(index, 10).Value = x[:diff][0][0]
                sht.Cells(index, 11).Value = x[:diff][0][1]
                sht.Cells(index, 12).Value = x[:diff][0][2]

                sht.Cells(index, 13).Value = x[:diff][1][0]
                sht.Cells(index, 14).Value = x[:diff][1][1]
                sht.Cells(index, 15).Value = x[:diff][1][2]

                sht.Cells(index, 16).Value = x[:diff][2][0]
                sht.Cells(index, 17).Value = x[:diff][2][1]
                sht.Cells(index, 18).Value = x[:diff][2][2]
              end

              index += 1
            end
          end
        end

        wk.save file
        wk.close

        true
      rescue Exception => e
        if logger
          logger.exception e
        end

        begin
          wk.close false
        rescue Exception => e
        end

        false
      ensure
        application.quit
      end
    end

    private

    def self.diff_count path, logger = nil, &block
      map = {
        nil => {}
      }

      File.expands(File.join(path, '*')).each do |name|
        if block_given?
          if not yield name
            next
          end
        end

        if File.file? name
          if logger
            logger.puts name
          end

          counter_info = count name

          map[nil][name] = {
            :code => counter_info[:code]
          }
        else
          diff_count(name, logger, &block).each do |ver, info|
            map[ver] ||= {}
            map[ver].merge! info
          end
        end
      end

      map
    end

    def self.diff_count_path path, diff_path, logger = nil, &block
      map = {
        nil => {}
      }

      if not path.nil?
        continue = true

        if block_given?
          continue = yield path
        end

        if continue
          if File.file? path
            if logger
              logger.puts path
            end

            counter_info = count path, diff_path

            if diff_path.nil?
              counter_info[:flag] = 'A'
              counter_info[:diff] = [
                [counter_info[:code][0], 0, 0],
                [counter_info[:code][1], 0, 0],
                [counter_info[:code][2], 0, 0],
                [counter_info[:code][3], 0, 0]
              ]
            else
              if counter_info[:diff].nil?
                counter_info[:flag] = nil
              else
                counter_info[:flag] = 'M'
              end
            end

            map[nil][path] = {
              :flag => counter_info[:flag],
              :code => counter_info[:code],
              :diff => counter_info[:diff]
            }
          else
            File.expands(File.join(path, '*')).each do |name|
              if diff_path.nil?
                diff_name = nil
              else
                diff_name = File.join diff_path, File.basename(name)

                if not File.exist? diff_name
                  diff_name = nil
                end
              end

              diff_count_path(name, diff_name, logger, &block).each do |ver, info|
                map[ver] ||= {}
                map[ver].merge! info
              end
            end

            if not diff_path.nil?
              File.expands(File.join(diff_path, '*')).each do |diff_name|
                name = File.join path, File.basename(diff_name)

                if not File.exist? name
                  diff_count_path(nil, diff_name, logger, &block).each do |ver, info|
                    map[ver] ||= {}
                    map[ver].merge! info
                  end
                end
              end
            end
          end
        end
      else
        if not diff_path.nil?
          continue = true

          if block_given?
            continue = yield diff_path
          end

          if continue
            if File.file? path
              if logger
                logger.puts diff_path
              end

              counter_info = count diff_path

              map[nil][diff_path] = {
                :flag => 'D',
                :code => [0, 0, 0, 0],
                :diff => [
                  [0, 0, counter_info[:code][0]],
                  [0, 0, counter_info[:code][1]],
                  [0, 0, counter_info[:code][2]],
                  [0, 0, counter_info[:code][3]]
                ]
              }
            else
              File.expands(File.join(diff_path, '*')).each do |diff_name|
                diff_count_path(nil, diff_name, logger, &block).each do |ver, info|
                  map[ver] ||= {}
                  map[ver].merge! info
                end
              end
            end
          end
        end
      end

      map
    end

    def self.diff_count_git path, logger = nil, opt = nil, &block
      nil
    end

    def self.diff_count_svn path, logger = nil, opt = nil, &block
      opt ||= {}

      if opt[:all_change].nil?
        opt[:all_change] = true
      end

      if opt[:inc].nil?
        opt[:inc] = true
      end

      if File.directory? path
        cur_path = path
      else
        if opt[:url].nil?
          if logger
            logger.error 'url is nil - ' + path
          end

          return nil
        end

        cur_path = opt[:url]
      end

      case
      when (not opt[:start_revision].nil?)
        start_revision = opt[:start_revision].to_s
      when (not opt[:start_time].nil?)
        start_revision = '{' + opt[:start_time].strftime('%Y-%m-%d') + '}'
      else
        start_revision = '1'
      end

      case
      when (not opt[:finish_revision].nil?)
        finish_revision = opt[:finish_revision].to_s
      when (not opt[:finish_time].nil?)
        finish_revision = '{' + opt[:finish_time].strftime('%Y-%m-%d') + '}'
      else
        finish_revision = 'HEAD'
      end

      opt[:svn_args] = nil

      info = SVN.info cur_path, logger, opt

      if info.nil?
        return nil
      end

      url = info[:url]
      repos = info[:root]
      repos_path = File.relative_path url, repos

      opt[:svn_args] = '--verbose --quiet --revision ' + start_revision + ':' + finish_revision
      logs = SVN.log cur_path, logger, opt

      GC.start

      if logs.nil?
        return nil
      end

      start_revision = nil
      start_time     = nil

      loop do
        if logs.empty?
          break
        end

        found = false
        cur = logs.first

        cur[:change_files].each do |k, v|
          v.each do |name|
            if File.include? repos_path, name
              found = true

              break
            end
          end
        end

        if found
          start_revision = cur[:rev]
          start_time     = cur[:date]

          break
        end

        logs.shift
      end

      if logs.empty?
        return {}
      end

      opt[:svn_args] = '--revision ' + start_revision.to_s

      if File.directory? path
        if not SVN.cleanup path, logger or not SVN.revert path, logger
          return nil
        end

        if not SVN.update path, logger, opt
          return nil
        end
      else
        if not SVN.checkout opt[:url], path, logger, opt
          return nil
        end
      end

      GC.start

      prev_revision = false

      case
      when (not opt[:start_revision].nil?)
        if start_revision > opt[:start_revision]
          prev_revision = true
        end
      when (not opt[:start_time].nil?)
        if start_time > opt[:start_time]
          prev_revision = true
        end
      end

      if prev_revision
        opt[:svn_args] = '--revision PREV'

        if not SVN.update path, logger, opt
          return nil
        end
      else
        logs.shift
      end

      if logs.empty?
        return {}
      end

      changes = {}

      if opt[:all_change]
        cur_changes = {
          :rev    => nil,
          :change => [],
          :logs   => {}
        }

        logs.each do |x|
          merge = true
          change_files = []

          x[:change_files].each do |k, v|
            v.delete_if {|name| not File.include?(repos_path, name)}

            v.each do |name|
              if cur_changes[:change].include? name
                merge = false
              end

              change_files << name
            end
          end

          if change_files.empty?
            next
          end

          rev = x[:rev]

          if not merge
            changes[cur_changes[:rev]] = cur_changes[:logs]

            cur_changes = {
              :rev    => nil,
              :change => [],
              :logs   => {}
            }
          end

          cur_changes[:rev] = rev
          cur_changes[:change] += change_files
          cur_changes[:logs][rev] = {
            :author       => x[:author],
            :date         => x[:date],
            :change_files => x[:change_files]
          }
        end

        if not cur_changes[:logs].empty?
          changes[cur_changes[:rev]] = cur_changes[:logs]
        end
      else
        finish_revision = logs.last[:rev]

        changes[finish_revision] = {}

        changes[finish_revision] = {
          finish_revision => {
            :author       => logs.last[:author],
            :date         => logs.last[:date],
            :change_files => {}
          }
        }

        pre_change_files = {}

        logs.each do |x|
          x[:change_files].each do |k, v|
            v.each do |name|
              if not pre_change_files.has_key? name
                pre_change_files[name] = k
              end
            end
          end
        end

        change_files = []

        logs.reverse_each do |x|
          x[:change_files].each do |k, v|
            v.delete_if {|name| not File.include?(repos_path, name)}

            rev = x[:rev]

            v.each do |name|
              if change_files.include? name
                next
              end

              change_files << name

              case k
              when :add
                if pre_change_files[name] != :add
                  k = :update
                end
              when :delete
                if pre_change_files[name] == :add
                  next
                end
              else
                if pre_change_files[name] == :add
                  k = :add
                end
              end

              changes[finish_revision][rev] ||= {
                :author       => x[:author],
                :date         => x[:date],
                :change_files => {}
              }

              changes[finish_revision][rev][:change_files][k] ||= []
              changes[finish_revision][rev][:change_files][k] << name
            end
          end
        end
      end

      GC.start

      map = {}

      start_revision_info = [
        info[:author], info[:rev], info[:date]
      ]

      pre_revision_info = {}

      if not opt[:inc]
        status = SVN.status path, logger

        if status.nil?
          return nil
        end

        map[start_revision] = {}

        status.each do |name, status_info|
          if status_info.first == ' '
            if not File.file? name
              next
            end

            if block_given?
              if not yield name
                next
              end
            end

            file = File.join url, File.relative_path(name, path)

            if logger
              logger.puts file
            end

            counter_info = count name

            map[start_revision][file] = {
              :flag => nil,
              :ver  => [
                [status_info[10], status_info[9], start_time],
                nil
              ],
              :code => counter_info[:code]
            }
          end
        end
      end

      GC.start

      tmpdir = File.tmpname

      changes.each do |revision, revision_info|
        revision_info.each do |rev, rev_info|
          rev_info[:change_files].each do |k, v|
            if k == :add
              next
            end

            v.each_with_index do |name, i|
              file = File.join path, File.relative_path(name, repos_path)

              if block_given?
                if not yield file
                  v[i] = nil

                  next
                end
              end

              if File.file? file
                File.copy file, File.join(tmpdir, revision.to_s, name), logger
              end
            end

            v.delete nil
          end
        end

        opt[:svn_args] = '--revision ' + revision.to_s

        if SVN.update path, logger, opt
          revision_info.each do |rev, rev_info|
            author = rev_info[:author]
            date = rev_info[:date]

            rev_info[:change_files].each do |k, v|
              v.each do |name|
                case k
                when :add
                  file = File.join path, File.relative_path(name, repos_path)

                  if block_given?
                    if not yield file
                      next
                    end
                  end
                when :delete
                  file = File.join tmpdir, revision.to_s, name
                else
                  file = File.join path, File.relative_path(name, repos_path)
                end

                if File.directory? file
                  next
                end

                file_url = File.join repos, name

                if logger
                  logger.puts file_url
                end

                if pre_revision_info.has_key? file
                  pre_revision = pre_revision_info[file]
                else
                  opt[:svn_args] = '--revision PREV'
                  cur_info = SVN.info file, logger, opt

                  if cur_info.nil?
                    pre_revision = nil
                  else
                    pre_revision = [
                      cur_info[:author], cur_info[:rev], cur_info[:date]
                    ]
                  end
                end

                map[rev] ||= {}

                case k
                when :add
                  if File.file? file
                    counter_info = count file

                    map[rev][file_url] = {
                      :flag => 'A',
                      :ver  => [
                        [author, rev, date],
                        nil
                      ],
                      :code => counter_info[:code],
                      :diff => [
                        [counter_info[:code][0], 0, 0],
                        [counter_info[:code][1], 0, 0],
                        [counter_info[:code][2], 0, 0],
                        [counter_info[:code][3], 0, 0]
                      ]
                    }
                  end
                when :delete
                  if File.file? file
                    counter_info = count file

                    map[rev][file_url] = {
                      :flag => 'D',
                      :ver  => [
                        [author, rev, date],
                        pre_revision
                      ],
                      :code => [0, 0, 0, 0],
                      :diff => [
                        [0, 0, counter_info[:code][0]],
                        [0, 0, counter_info[:code][1]],
                        [0, 0, counter_info[:code][2]],
                        [0, 0, counter_info[:code][3]]
                      ]
                    }
                  else
                    map[rev][file_url] = nil
                  end
                else
                  diff_file = File.join tmpdir, revision.to_s, name

                  if File.file? file
                    if File.file? diff_file
                      counter_info = count file, diff_file

                      map[rev][file_url] = {
                        :flag => 'M',
                        :ver  => [
                          [author, rev, date],
                          pre_revision
                        ],
                        :code => counter_info[:code],
                        :diff => counter_info[:diff]
                      }
                    else
                      map[rev][file_url] = nil
                    end
                  else
                    if File.file? diff_file
                      counter_info = count diff_file

                      map[rev][file_url] = {
                        :flag => 'D',
                        :ver  => [
                          [author, rev, date],
                          pre_revision
                        ],
                        :code => [0, 0, 0, 0],
                        :diff => [
                          [0, 0, counter_info[:code][0]],
                          [0, 0, counter_info[:code][1]],
                          [0, 0, counter_info[:code][2]],
                          [0, 0, counter_info[:code][3]]
                        ]
                      }
                    else
                      map[rev][file_url] = nil
                    end
                  end
                end

                pre_revision_info[file] = [
                  author, rev, date
                ]
              end
            end
          end
        else
          revision_info.keys.each do |rev|
            map[rev] = nil
          end

          SVN.cleanup path, logger
        end

        GC.start
      end

      File.delete tmpdir, logger

      map
    end
  end
end

class CIC
  attr_reader :config_info, :counter_info
  attr_accessor :logger

  def initialize name, file
    @name = name.to_s
    @config_info = configure name, file
    @counter_info = nil
    @revisions = {}

    @table = Table.new
    @table.head = [
      'runid',
      'DepartmentID',
      'ProjectID',
      'fromType',
      'language_type',
      'url',
      'FileName',
      'flag',
      'EmployeeID',
      'CodeChurnID',
      'timekey',
      'diff_author',
      'diff_ver',
      'diff_time',
      'total_lines',
      'code_lines',
      'comment_lines',
      'empty_lines',
      'LinesAdded',
      'LinesModified',
      'LinesDeleted',
      'code_add_lines',
      'code_change_lines',
      'code_delete_lines',
      'comment_add_lines',
      'comment_change_lines',
      'comment_delete_lines',
      'empty_add_lines',
      'empty_change_lines',
      'empty_delete_lines',
      'account',
      'updPerson',
      'updDate'
    ]
  end

  def revisions database = true, opt = nil
    opt ||= {}

    if @config_info.nil?
      return nil
    end

    if database
      begin
        sqlserver = SqlServer.new
        sqlserver.logger = @logger

        if not sqlserver.open @config_info[:database][:ip], @config_info[:database][:username], @config_info[:database][:password]
          raise 'not connection database server - %s' % @config_info[:database][:ip]
        end

        if not sqlserver.database @config_info[:database][:database]
          raise 'not open database - %s' % @config_info[:database][:database]
        end

        table = sqlserver.execute 'select url, codechurnid from tbl_codecounterurl'

        @revisions = {}

        table.rows.each do |url, ver|
          @revisions[url] = ver.to_s
        end

        @revisions
      rescue Exception => e
        if @logger
          @logger.exception e
        end

        nil
      ensure
        sqlserver.close
      end
    else
      map = {}

      if opt[:start_revision].nil? and opt[:start_time].nil?
        if File.directory? @config_info[:counter][:home]
          Dir.chdir @config_info[:counter][:home] do
            @config_info[:counter][:dirs].each do |dir, url|
              if File.exists? dir
                info = SCM.info dir, @logger

                if not info.nil?
                  map[url] = info[:rev]
                end
              end
            end
          end
        end
      end

      map
    end
  end

  def count all_change = true, inc = true, revisions = nil, opt = nil
    revisions ||= {}
    opt ||= {}

    if @config_info.nil?
      return false
    end

    if not File.directory? @config_info[:counter][:home]
      return false
    end

    opt[:all_change] = all_change
    opt[:inc] = inc

    info = {
      :code => [0, 0, 0, 0],
      :diff => [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0]
      ],
      :info  => {}
    }

    Dir.chdir @config_info[:counter][:home] do
      @config_info[:counter][:dirs].each do |dir, url_info|
        dup_opt = opt.dclone

        if revisions[url_info.first]
          dup_opt[:start_revision] = revisions[url_info.first]
        end

        dup_opt[:url] = url_info.first
        dup_opt[:scm] = url_info.last

        cur_info = Counter::CodeCounter.code_count dir, nil, dup_opt, @logger do |name|
          continue = true

          @config_info[:counter][:ignores].each do |x|
            if File.include? x, name
              continue = false
            end
          end

          if File.file? name
            if not @config_info[:counter][:ext_names].include? File.extname(name).downcase
              continue = false
            end
          end

          continue
        end

        if cur_info.nil? or cur_info.empty?
          next
        end

        last_revision = cur_info.keys.sort.last

        info[:code].deep_merge! cur_info[last_revision][:code]
        info[:info][url_info.first] = {}

        cur_info.each do |k, v|
          info[:info][url_info.first][k] = v[:info]

          if v[:diff].nil?
            next
          end

          info[:diff].deep_merge! v[:diff]
        end
      end
    end

    table_info info
    @counter_info = info

    true
  end

  def to_file file = nil
    if not @counter_info.nil?
      if file.nil?
        file = @name.downcase + '_' + Time.now.strftime('%Y%m%d%H%M%S') + '.txt'
      end

      File.open file, 'w' do |f|
        f.puts @table
        f.puts
        f.puts @counter_info[:code].to_s
        f.puts @counter_info[:diff].to_s
      end

      true
    else
      false
    end
  end

  def to_excel user_file = nil, file = nil
    if @counter_info.nil?
      return false
    end

    if not OS.windows?
      return true
    end

    if file.nil?
      file = @name.downcase + '_' + Time.now.strftime('%Y%m%d%H%M%S')
    end

    map = {}

    if not user_file.nil? and File.file? user_file
      table = Table.from_excel user_file, nil, @logger

      table.rows.each do |employee_name, employee_id, division, department, svn_account, project|
        map[svn_account] = [employee_id, employee_name, division, department, project]
      end
    end

    Counter::CodeCounter.to_excel @counter_info, file, map, @logger
  end

  def from_file file
    if not File.file? file
      return false
    end

    table = Table.load(file).first

    if not table.nil? and table.head == @table.head
      @table.rows = table.rows

      indexs_time = [@table.head.index('timekey'), @table.head.index('diff_time'), @table.head.index('updDate')]
      indexs_int = [@table.head.index('CodeChurnID'), @table.head.index('diff_ver')] + (@table.head.index('total_lines')..@table.head.index('empty_delete_lines')).to_a

      @table.rows.each do |x|
        indexs_time.each do |i|
          if x[i].strip.empty?
            x[i] = nil
          else
            begin
              x[i] = Time.parse x[i]
            rescue Exception => e
              if @logger
                @logger.exception e
              end

              return false
            end
          end
        end

        indexs_int.each do |i|
          if x[i].strip.empty?
            x[i] = nil
          else
            x[i] = x[i].to_i
          end
        end
      end

      true
    else
      false
    end
  end

  def database
    if @config_info.nil?
      return false
    end

    if @revisions.empty?
      if revisions.nil?
        return false
      end
    end

    begin
      sqlserver = SqlServer.new
      sqlserver.logger = @logger

      if not sqlserver.open @config_info[:database][:ip], @config_info[:database][:username], @config_info[:database][:password]
        raise 'not connection database server - %s' % @config_info[:database][:ip]
      end

      if not sqlserver.database @config_info[:database][:database]
        raise 'not open database - %s' % @config_info[:database][:database]
      end

      revision_map = {}

      cur_account_index = @table.head.index 'EmployeeID'
      diff_account_index = @table.head.index 'diff_author'
      account_index = @table.head.index 'account'

      @table.rows.each do |x|
        cur_account = x[cur_account_index]
        diff_account = x[diff_account_index]

        if not cur_account.nil?
          if cur_account =~ /\d+$/
            x[cur_account_index] = $&
          end
        else
          x[cur_account_index] = ''
        end

        if not diff_account.nil?
          if diff_account =~ /\d+$/
            x[diff_account_index] = $&
          end
        else
          x[diff_account_index] = ''
        end

        x[account_index] = cur_account

        url = x[@table.head.index('url')]
        codechurnid = x[@table.head.index('CodeChurnID')]
        revision_map[url] = [revision_map[url].to_i, codechurnid.to_i].max
      end

      table = sqlserver.execute 'select ProjectID, FileName, CodeChurnID from tbl_codecounter where ProjectID = \'' + @config_info[:counter][:id].to_s + '\''

      if table.nil?
        raise 'query tbl_codecounter failed'
      end

      map = {}

      table.rows.each do |x|
        map[x[1].to_s + ':' + x[2].to_s] = x[0]
      end

      filename_index = @table.head.index 'EmployeeID'
      codechurnid_index = @table.head.index 'CodeChurnID'

      @table.rows.delete_if do |x|
        map.has_key? x[filename_index].to_s + ':' + x[codechurnid_index].to_s
      end

      if not sqlserver.insert_table 'tbl_codecounter', @table
        raise 'insert data to tbl_codecounter failed'
      end

      revision_map.each do |url, ver|
        if @revisions.has_key? url
          sql = 'update tbl_codecounterurl set codechurnid = ' + sqlserver.format(ver).to_s + ' where url = ' + sqlserver.format(url)
        else
          sql = 'insert into tbl_codecounterurl (url, codechurnid) values (' + [sqlserver.format(url), sqlserver.format(ver)].join(', ') + ')'
        end

        if sqlserver.execute(sql).nil?
          raise 'insert or update data to tbl_codecounterurl failed'
        end
      end

      true
    rescue Exception => e
      if @logger
        @logger.exception e
      end

      false
    ensure
      sqlserver.close
    end
  end

  private

  def configure name, file
    info = {}

    begin
      doc = REXML::Document.file file
    rescue Exception => e
      if @logger
        @logger.exception e
      end

      return nil
    end

    info[:database] = {
      :ip       => doc.root.attributes['ip'].to_s.strip.nil,
      :username => doc.root.attributes['username'].to_s,
      :password => doc.root.attributes['password'].to_s,
      :database => doc.root.attributes['database'].to_s.strip
    }

    e = nil

    REXML::XPath.each(doc, '/cic/counter[@name="' + name.to_s + '"]') do |element|
      e = element

      break
    end

    if e.nil?
      if @logger
        @logger.error 'not found %s' % name.utf8
      end

      return nil
    end

    info[:counter] = {
      :id           => e.attributes['id'].to_s.strip,
      :name         => e.attributes['name'].to_s.strip,
      :ext_names    => e.attributes['ext_names'].to_s.split(',').map {|x| x.strip.downcase},
      :home         => e.attributes['home'].to_s.strip,
      :domain_name  => e.attributes['domain_name'].to_s.strip,
      :update_person=> e.attributes['update_person'].to_s.strip,
      :dirs         => {},
      :ignores      => []
    }

    REXML::XPath.each(e, 'dirs/attr').each do |element|
      attr_name = File.normalize element.attributes['name'].to_s.strip
      attr_url = File.normalize element.attributes['url'].to_s.strip
      attr_scm = element.attributes['scm'].to_s.strip.nil || 'svn'

      if not attr_name.empty?
        info[:counter][:dirs][attr_name] = [attr_url, attr_scm.to_sym]
      end
    end

    REXML::XPath.each(e, 'ignores/attr').each do |element|
      attr_name = File.normalize element.attributes['name'].to_s.strip

      if not attr_name.empty?
        info[:counter][:ignores] << attr_name
      end
    end

    info[:counter][:ignores].uniq!

    info
  end

  def table_info info
    time = Time.now
    runid = time.strftime('%Y%m%d%H%M%S')

    @table.rows = []

    info[:info].each do |url, revisions|
      if revisions.nil?
        next
      end

      revisions.each do |revision, revision_info|
        if revision_info.nil?
          next
        end

        revision_info.each do |name, x|
          if x.nil?
            next
          end

          row = [runid, nil, @config_info[:counter][:id], '01', File.extname(name).downcase]

          ver, diff_ver = x[:ver].to_a.dclone

          if ver.nil?
            ver = ['admin', -1, nil]
          end

          if ver.last.nil?
            ver[-1] = time
          end

          if diff_ver.nil?
            diff_ver = [nil, nil, nil]
          end

          account = ver.first

          row += [url, name, x[:flag]]
          row += ver
          row += diff_ver

          row += x[:code]

          if x[:diff].nil?
            row += [0] * 12
          else
            row += x[:diff][0].map {|count| count.to_i}
            row += x[:diff][1].map {|count| count.to_i}
            row += x[:diff][2].map {|count| count.to_i}
            row += x[:diff][3].map {|count| count.to_i}
          end

          row += [account, @config_info[:counter][:update_person], Time.now]

          @table.rows << row
        end
      end
    end

    true
  end
end