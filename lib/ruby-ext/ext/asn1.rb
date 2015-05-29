require 'stringio'
require 'yaml'

module ASN1
  class Any
    attr_accessor :classname, :path, :ignore, :match
    attr_accessor :value

    def == other_any
      if @ignore
        true
      else
        if other_any.nil?
          set_state nil, nil

          false
        else
          if @classname != other_any.classname
            set_state false, nil
            other_any.set_state false, nil

            false
          else
            if @value == other_any.value
              set_state true, nil
              other_any.set_state true, nil

              true
            else
              set_state false, nil
              other_any.set_state false, nil

              false
            end
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if force
        @ignore = true
      else
        if not @path.nil?
          if @path.to_s.gsub(/\[\d+\]/, '') == path
            if condition.nil?
              @ignore = true
            else
              @ignore = true ###
            end
          end
        end
      end
    end

    def set_sort_keys sort_keys
      if @value.respond_to? :set_sort_keys
        @value.set_sort_keys sort_keys
      end
    end

    def get key
      if @value.is_a? Sequence
        @value.get key
      else
        nil
      end
    end

    def to_string
      @value.to_string
    end

    def to_html
      if @value.respond_to? :to_html
        str = @value.to_html
      else
        str = @value.to_string
      end

      if @ignore
        '<font color = "gray">%s</font>' % str
      else
        if @match.nil?
          '<font color = "blue">%s</font>' % str
        else
          if @match
            str
          else
            '<font color = "red">%s</font>' % str
          end
        end
      end
    end
  end

  class Choice
    attr_accessor :classname, :path, :ignore
    attr_accessor :klass, :name, :value

    def == other_choice
      if @ignore
        true
      else
        if other_choice.nil?
          set_state nil, nil

          false
        else
          if @classname != other_choice.classname
            set_state false, nil
            other_choice.set_state false, nil

            false
          else
            if @name != other_choice.name
              set_state false, nil
              other_choice.set_state false, nil

              false
            else
              @value == other_choice.value
            end
          end
        end
      end
    end

    def set_state match, ignore
      @value.set_state match, ignore
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      @value.set_ignore path, condition, force
    end

    def set_sort_keys sort_keys
      @value.set_sort_keys sort_keys
    end

    def to_string
      lines = [
        '{ -- CHOICE -- %s' % @classname
      ]

      ('%s = %s' % [@name.to_string, @value.to_string]).each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = [
        '{ -- CHOICE -- <font color = "white">%s</font>' % @classname
      ]

      ('%s = %s' % [@name.to_string, @value.to_html]).each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*CHOICE\s*--/
        classname = $'.strip
      end

      lines.pop

      depth = 0

      name = nil
      value = nil
      asn = nil

      asn_lines = []

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end

            if $` =~ /\s*=/
              name = $`.strip
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              value = asn.load asn_lines.join("\n")
            end
          end
        end
      end

      {
        :type       => :choice,
        :classname  => classname,
        :name       => name,
        :value      => value
      }
    end
  end

  class Sequence < Hash
    attr_accessor :classname, :path, :ignore

    def == other_sequence
      if @ignore
        true
      else
        if other_sequence.nil?
          set_state nil, nil

          false
        else
          if @classname != other_sequence.classname
            set_state false, nil
            other_sequence.set_state false, nil

            false
          else
            status = true

            each do |k, v|
              if v != other_sequence[k]
                status = false
              end
            end

            other_sequence.each do |k, v|
              if has_key? k
                next
              end

              v.set_state nil, nil
              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |k, v|
        v.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      each do |k, v|
        v.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
      each do |k, v|
        v.set_sort_keys sort_keys
      end
    end

    def get key
      name, key = key.split '.', 2

      if has_key? name
        if key.nil?
          self[name]
        else
          if self[name].respond_to? :get
            self[name].get key
          else
            nil
          end
        end
      else
        nil
      end
    end

    def to_string
      lines = []

      each do |k, v|
        list = []

        ('%s = %s' % [k.to_string, v.to_string]).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE -- %s' % @classname
      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = []

      each do |k, v|
        list = []

        ('%s = %s' % [k.to_string, v.to_html]).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE -- <font color = "white">%s</font>' % @classname
      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*SEQUENCE\s*--/
        classname = $'.strip
      end

      lines.pop

      hash = {}
      depth = 0

      asn_lines = []
      asn = nil
      asn_name = nil

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end

            if $` =~ /\s*=/
              asn_name = $`.strip
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              hash[asn_name] = asn.load asn_lines.join("\n")
            end
          end
        end

        if depth == 0
          if line =~ /\s*=\s*/
            hash[$`.strip] = $'.strip.chomp ','
          end
        end
      end

      {
        :type       => :sequence,
        :classname  => classname,
        :hash       => hash
      }
    end
  end

  class SequenceList < Array
    attr_accessor :classname, :path, :ignore, :sort_key

    def == other_sequence_list
      if @ignore
        true
      else
        if other_sequence_list.nil?
          set_state nil, nil

          false
        else
          if @classname != other_sequence_list.classname
            set_state false, nil
            other_sequence_list.set_state false, nil

            false
          else
            if not empty? and @sort_key and not first.get(@sort_key).nil?
              is_numeric = false

              klass = Java.import first.get(@sort_key).classname

              if klass.number?
                is_numeric = true
              else
                if not klass.java_variables['value'].nil? and klass.java_variables['value'].number?
                  is_numeric = true
                end
              end

              map = {}

              each do |sequence|
                if is_numeric
                  value = sequence.get(@sort_key).to_s.to_f
                else
                  value = sequence.get(@sort_key).to_string
                end

                map[value] ||= []
                map[value] << sequence
              end

              other_map = {}

              other_sequence_list.each do |sequence|
                if is_numeric
                  value = sequence.get(@sort_key).to_s.to_f
                else
                  value = sequence.get(@sort_key).to_string
                end

                other_map[value] ||= []
                other_map[value] << sequence
              end

              self.clear
              other_sequence_list.clear

              map.keys.sort.each do |k|
                list = map[k]
                other_list = other_map[k]

                if other_list.nil?
                  next
                end

                size = [list.size, other_list.size].min

                size.times do
                  self << list.shift
                  other_sequence_list << other_list.shift
                end

                if list.empty?
                  map.delete k
                end

                if other_list.empty?
                  other_map.delete k
                end
              end

              map.keys.sort.each do |k|
                map[k].each do |sequence|
                  self << sequence
                end
              end

              other_map.keys.sort.each do |k|
                other_map[k].each do |sequence|
                  other_sequence_list << sequence
                end
              end
            end

            status = true

            each_with_index do |sequence, index|
              if sequence != other_sequence_list[index]
                status = false
              end
            end

            if size < other_sequence_list.size
              other_sequence_list[size..-1].each do |sequence|
                sequence.set_state nil, nil
              end

              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |sequence|
        sequence.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      each do |sequence|
        sequence.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
      if not empty?
        sequence_classname = first.classname

        sort_keys.each do |classname, path|
          if sequence_classname == classname
            @sort_key = path

            break
          end
        end
      end

      each do |sequence|
        sequence.set_sort_keys sort_keys
      end
    end

    def to_string
      lines = []

      each do |sequence|
        if sequence.kind_of? Sequence
          prefix = INDENT
        else
          prefix = ''
        end

        list = []

        (prefix + sequence.to_string).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE OF -- %s' % @classname
      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = []

      each do |sequence|
        if sequence.kind_of? Sequence
          prefix = INDENT
        else
          prefix = ''
        end

        list = []

        (prefix + sequence.to_html).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE OF -- <font color = "white">%s</font>' % @classname
      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*SEQUENCE\s*OF\s*--/
        classname = $'.strip
      end

      lines.pop

      array = []
      depth = 0

      asn_lines = []
      asn = nil

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              array << asn.load(asn_lines.join("\n"))
            end
          end
        end
      end

      {
        :type       => :sequence_of,
        :classname  => classname,
        :array      => array
      }
    end
  end

  class LineSequenceList < SequenceList
    def to_string
      lines = []

      each do |any|
        list = []

        any.to_string.each_line do |line|
          list << line.rstrip
        end

        lines << list.join("\n")
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      each do |any|
        list = []

        any.to_html.each_line do |line|
          list << line.rstrip
        end

        lines << list.join("\n")
      end

      lines.join "\n"
    end

    def load str
      str.lines.map { |line| line.rstrip }
    end
  end

  class CliSequenceList < LineSequenceList
    def to_string
      lines = ['[']

      super.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << ']'

      lines.join "\n"
    end

    def to_html
      lines = ['[']

      super.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << ']'

      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift
      lines.pop

      lines
    end
  end

  class Asn1
    attr_reader :classname, :opt
    attr_accessor :logger

    @@tags = {}

    # opt
    #     :name
    #     :ne
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = (@opt[:data].join(' ').split(/\s/) - ['']).map {|x| x.to_i 16}
      @classname = get_classname

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end

      @asn1 = nil
      @java_asn1 = nil

      @match = nil
      @ignore = nil
      @ignore_paths = nil
      @sort_keys = nil
    end

    def validate?
      if @classname.nil?
        if @logger
          @logger.debug 'not found classname'
        end

        @asn1 = line_sequence @data
      else
        @java_asn1 = decode

        if @java_asn1.nil?
          if @logger
            @logger.debug 'not parse asn1 data - %s' % @classname
          end

          @asn1 = line_sequence @data
        end
      end

      true
    end

    def asn1
      if @asn1.nil? and not @java_asn1.nil?
        @asn1 = to_ruby @java_asn1

        if not @match.nil? or not @ignore.nil?
          set_state @match, @ignore
        end

        if not @ignore_paths.nil?
          set_ignore @ignore_paths
        end

        if not @sort_keys.nil?
          set_sort_keys @sort_keys
        end
      end

      @asn1
    end

    def == other_asn1
      if other_asn1.nil?
        set_state nil, nil

        false
      else
        if @classname != other_asn1.classname
          set_state false, nil
          other_asn1.set_state false, nil

          false
        else
          asn1 == other_asn1.asn1
        end
      end
    end

    def set_state match, ignore
      if @asn1.nil?
        @match = match
        @ignore = ignore
      else
        @asn1.set_state match, ignore

        @match = nil
        @ignore = nil
      end
    end

    def set_ignore paths_info
      if @asn1.nil?
        @ignore_paths = paths_info
      else
        paths_info.each do |path, condition|
          @asn1.set_ignore path, condition
        end

        @ignore_paths = nil
      end
    end

    def set_sort_keys sort_keys
      if @asn1.nil?
        @sort_keys = sort_keys
      else
        @asn1.set_sort_keys sort_keys

        @sort_keys = nil
      end
    end

    def ne
      @opt[:ne] || @opt[:name]
    end

    def cmdcode
      @opt[:cmdcode] || @classname
    end

    def to_string
      asn1.to_string
    end

    def to_html
      if asn1.respond_to? :to_html
        asn1.to_html
      else
        asn1.to_string
      end
    end

    def self.load str
      depth = 0
      lines = []

      info = nil
      asn = nil

      str.lines.each do |line|
        line.rstrip!

        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end
          end

          depth += 1
        end

        if depth > 0
          lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              info = asn.load lines.join("\n")
            end
          end
        end
      end

      info
    end

    def self.import paths, clear = false, asn = true
      if clear
        @@tags = {}
      end

      if asn
        Java.include File.join(gem_dir('ruby-ext'), 'bin/asn.jar')
      end

      paths.to_array.each do |path|
        path = File.normalize path
        Java.include path

        ZipFile.new(path).entries.each do |name|
          name = name.to_s

          if File.extname(name) != '.class'
            next
          end

          name = File.basename name.gsub('/', '.'), '.class'

          begin
            tag = Java.import(name).new.getT.to_i

            if tag > 0
              @@tags[tag] = name
            end
          rescue
          end
        end
      end
    end

    private

    def get_classname
      classname = nil

      if @data.size > 2
        tag = @data[0] * 256 + @data[1]
        classname = @@tags[tag]
      end

      classname
    end

    def decode
      java_asn1 = nil

      begin
        decoder = Java.import('com.ibm.asn1.ASN1TlvDecoder').new @data

        java_asn1 = Java.import(@classname).new
        java_asn1.qxdecode decoder
      rescue
        if @logger
          @logger.debug @classname
          @logger.exception $!
        end

        #java_asn1 = nil
      end

      java_asn1
    end

    def to_ruby asn1, klass = nil, path = nil
      if asn1.nil?
        any = Any.new
        any.path = path

        if klass.is_a? Rjb::Rjb_JavaClass
          any.classname = klass.name
        end

        return any
      end

      klass ||= asn1.klass

      if klass.asn1_variables.empty?
        if Java.import('java.util.List').isInstance asn1
          # SequenceList

          sequence_list = SequenceList.new
          sequence_list.classname = klass.name
          sequence_list.path = path

          _klass = nil
          asn1.size.times do |i|
            _asn1 = asn1.get i

            if _asn1
              _klass = _asn1.klass
              sequence = to_ruby _asn1, _klass, '%s[%s]' % [sequence_list.path, i]
              sequence_list << sequence
            else
              sequence = Sequence.new
              sequence.classname = nil
              sequence.path = '%s[%s]' % [sequence_list.path, i]

              sequence_list << sequence
            end
          end

          sequence_list
        else
          # Any

          any = Any.new
          any.classname = klass.name
          any.path = path

          if asn1.is_a? Rjb::Rjb_JavaProxy
            begin
              any.value = asn1.to_string
            rescue
              any.value = nil
            end
          else
            any.value = asn1
          end

          any
        end
      else
        if klass.asn1_variables['choiceId'].class.to_s == 'Rjb::Int'
          # Choice

          choice = Choice.new
          choice.classname = klass.name
          choice.path = path

          if choice.path.nil?
            choice_path = ''
          else
            choice_path = choice.path + '.'
          end

          klass.java_constants.each do |name, _klass|
            if asn1.get_field(name).to_s == asn1.choiceId.to_s
              choice_cid = name

              klass.java_variables.each do |name, _klass|
                if name.downcase + '_cid' == choice_cid.downcase
                  choice.klass = _klass
                  choice.name = name
                  choice.value = to_ruby asn1.get_field(choice.name), choice.klass, choice_path + choice.name

                  break
                end
              end

              break
            end
          end

          choice
        else
          # Sequence

          sequence = Sequence.new
          sequence.classname = klass.name
          sequence.path = path

          if sequence.path.nil?
            sequence_path = ''
          else
            sequence_path = sequence.path + '.'
          end

          klass.asn1_variables.each do |name, _klass|
            sequence[name] = to_ruby asn1.get_field(name), _klass, sequence_path + name
          end

          sequence
        end
      end
    end

    def line_sequence lines
      cur_lines = []

      line = []
      lines.each_with_index do |x, i|
        if i % 10 == 0
          if not line.empty?
            cur_lines << line.join(' ')
          end

          line = []
        end

        line << x.to_s(16).rjust(2, '0')
      end

      if not line.empty?
        cur_lines << line.join(' ')
      end

      asn1 = LineSequenceList.new

      cur_lines.each do |line|
        any = Any.new
        any.value = line.to_s.strip

        asn1 << any
      end

      asn1
    end
  end

  class Cli < Asn1
    # opt
    #     :name
    #     :ne
    #     :classname
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = @opt[:data]
      @classname = @opt[:classname] || 'commandline'

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end
    end

    def validate?
      @asn1 = to_ruby @data

      true
    end

    def set_sort_keys sort_keys
      nil
    end

    def self.load str
      depth = 0
      lines = []

      info = nil
      asn = nil

      str.lines.each do |line|
        line.rstrip!

        if line.empty?
          next
        end

        if line.strip == '['
          if depth == 0
            lines = []

            asn = CliSequenceList.new
          end

          depth += 1
        end

        if depth > 0
          lines << line
        end

        if line.strip == ']'
          depth -= 1

          if depth == 0
            if not asn.nil?
              info = asn.load lines.join("\n")
            end
          end
        end
      end

      info
    end

    private

    def to_ruby lines
      asn1 = CliSequenceList.new

      lines.each do |line|
        any = Any.new

        if line.is_a? Array
          any.value = line.first.to_s
        else
          any.value = line.to_s.strip
        end

        asn1 << any
      end

      asn1
    end
  end

  class Asn1Compare < Hash
    attr_accessor :name, :ignore, :sort_keys, :logger

    def initialize
      @ignore = {}
      @sort_keys = {}
    end

    def compare asn1, other_asn1
      if asn1.nil? or other_asn1.nil?
        if not asn1.nil? or not other_asn1.nil?
          self[@name] ||= []
          self[@name] << [false, asn1, other_asn1]

          false
        else
          true
        end
      else
        if asn1.classname == other_asn1.classname
          dup_asn1 = asn1.dclone
          dup_other_asn1 = other_asn1.dclone

          @ignore.each do |classname, paths_info|
            if classname == asn1.classname
              dup_asn1.set_ignore paths_info
              dup_other_asn1.set_ignore paths_info
            end
          end

          dup_asn1.set_sort_keys @sort_keys
          dup_other_asn1.set_sort_keys @sort_keys

          if dup_asn1 == dup_other_asn1
            self[@name] ||= []
            self[@name] << [true, dup_asn1, dup_other_asn1]

            true
          else
            self[@name] ||= []
            self[@name] << [false, dup_asn1, dup_other_asn1]

            false
          end
        else
          self[@name] ||= []
          self[@name] << [false, asn1, other_asn1]

          false
        end
      end
    end

    def compare_list asn1_list, other_asn1_list
      asn1_hash = list2hash asn1_list
      other_asn1_hash = list2hash other_asn1_list

      asn1_hash.each do |ne, cmdcode_list|
        other_cmdcode_list = other_asn1_hash[ne]

        if other_cmdcode_list.nil?
          cmdcode_list.each do |cmdcode, list|
            list.each do |asn1|
              compare asn1, nil
            end
          end
        else
          cmdcode_list.each do |cmdcode, list|
            other_list = other_cmdcode_list[cmdcode]

            if other_list.nil?
              list.each do |asn1|
                compare asn1, nil
              end
            else
              list.each_with_index do |asn1, index|
                compare asn1, other_list[index]
              end

              if other_list.size > list.size
                other_list[list.size..-1].each do |asn1|
                  compare nil, asn1
                end
              end
            end
          end
        end
      end

      (other_asn1_hash.keys - asn1_hash.keys).each do |ne|
        cmdcode_list = other_asn1_hash[ne]

        cmdcode_list.each do |cmdcode, list|
          list.each do |asn1|
            compare nil, asn1
          end
        end
      end
    end

    def save filename = nil, home = nil, template = false
      filename ||= 'qxnew.log'
      home ||= '.'

      if not File.mkdir home
        return false
      end

      Dir.chdir home do
        each do |name, list|
          if list.empty?
            next
          end

          file = File.join name, filename

          File.open file, 'w' do |f|
            list.each do |status, asn1, other_asn1|
              if template
                if asn1.nil?
                  next
                end

                f.puts asn1.opt[:lines].locale
              else
                if other_asn1.nil?
                  next
                end

                f.puts other_asn1.opt[:lines].locale
              end

              f.puts
            end
          end
        end
      end

      true
    end

    def load_ignore file
      begin
        map = YAML.load_file file

        if map.kind_of? Hash
          @ignore = map
        end

        true
      rescue
        if @logger
          @logger.exception $!
        end

        false
      end
    end

    def load_sort_keys file
      begin
        map = YAML.load_file file

        if map.kind_of? Hash
          @sort_keys = map
        end

        true
      rescue
        if @logger
          @logger.exception $!
        end

        false
      end
    end

    def to_html file
      File.open file, 'w' do |f|
        # head
        f.puts '<html>'
        f.puts '%s<head>' % INDENT
        f.puts '%s<title>ASN1 Compare</title>' % (INDENT * 2)
        f.puts '%s<style type = "text/css">' % (INDENT * 2)

        css =<<-STR
      table caption {
        text-align    : left;
        font-weight   : bold;
        font-size     : 15px;
      }

      table th {
        text-align    : left;
        vertical-align: top;
        font-weight   : 100;
        font-style    : italic;
        font-size     : 15px;
      }

      table td {
        text-align    : left;
        vertical-align: top;
        font-size     : 15px;
      }

      table pre {
        width         : 580px;
        margin        : 10px 0px 10px 0px;
        padding       : 10px;
        border        : 1px dashed #666;
        font-size     : 13px;
      }
        STR

        f.puts INDENT * 3 + css.strip
        f.puts '%s</style>' % (INDENT * 2)
        f.puts '%s</head>' % INDENT

        # body
        f.puts '%s<body>' % INDENT

        # summary
        index = 1

        each do |name, list|
          if not name.nil?
            if index > 1
              f.puts
            end

            f.puts '%s<h4>%s</h4><br/>' % [INDENT * 2, name.to_s.escapes]
          end

          f.puts '%s<table>' % (INDENT * 2)

          list.each_with_index do |asn1_info, idx|
            if idx > 0
              f.puts
            end

            status, asn1, other_asn1 = asn1_info

            ne = nil
            classname = nil
            cmdcode = nil
            time = nil

            if not asn1.nil?
              ne = asn1.opt[:name].to_s
              classname = asn1.classname
              cmdcode = asn1.opt[:cmdcode]

              if not asn1.opt[:time].nil?
                time = asn1.opt[:time].to_s_with_usec
              end
            end

            if not other_asn1.nil?
              classname ||= other_asn1.classname
              cmdcode ||= other_asn1.opt[:cmdcode]

              if ne != other_asn1.opt[:name]
                ne = '%s(%s)' % [ne, other_asn1.opt[:name]]
              end

              if not other_asn1.opt[:time].nil?
                time = '%s(%s)' % [time.to_s, other_asn1.opt[:time].to_s_with_usec]
              else
                time = time.to_s
              end
            end

            if not cmdcode.nil?
              cmdcode = '0x%s(%s)' % [cmdcode.to_s(16), cmdcode]
            end

            str = [ne, classname.to_s.split('.').last, cmdcode, time].join(', ').escapes

            f.puts '%s<tr><td>' % (INDENT * 3)

            if status
              f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :black, str]
            else
              if asn1.nil? or other_asn1.nil?
                if asn1.nil?
                  f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :teal, str]
                else
                  f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :blue, str]
                end
              else
                f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :red, str]
              end
            end

            f.puts '%s</td></tr>' % (INDENT * 3)

            index += 1
          end

          f.puts '%s</table>' % (INDENT * 2)
        end

        f.puts
        f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)

        # detail
        index = 1

        each do |name, list|
          list.each do |status, asn1, other_asn1|
            f.puts

            f.puts '%s<table>' % (INDENT * 2)

            # caption
            f.puts '%s<caption><a name = "asn1_%s">ASN1: %s</a>  <a href = "#s_asn1_%s"><font color = "blue">back</font></a></caption>' % [INDENT * 3, index, index, index]
            f.puts

            f.puts '%s<tr>' % (INDENT * 3)
            f.puts '%s<th>' % (INDENT * 4)
            f.puts '<pre>'

            if asn1.nil?
              f.puts '-'
            else
              f.puts 'ne        : %s' % asn1.opt[:name]
              f.puts 'classname : %s' % asn1.classname

              if not asn1.opt[:cmdcode].nil?
                f.puts 'cmdcode   : 0x%s(%s)' % [asn1.opt[:cmdcode].to_s(16),  asn1.opt[:cmdcode]]
              else
                f.puts 'cmdcode   : '
              end

              if not asn1.opt[:time].nil?
                f.puts 'time      : %s' % asn1.opt[:time].to_s_with_usec
              else
                f.puts 'time      : '
              end

              if not asn1.opt[:file].nil?
                lines = File.normalize(asn1.opt[:file]).wrap 70
                f.puts 'file      : %s' % lines.shift

                lines.each do |line|
                  f.puts '            %s' % line
                end
              end
            end

            f.puts '</pre>'
            f.puts '%s</th>' % (INDENT * 4)

            f.puts

            f.puts '%s<th>' % (INDENT * 4)
            f.puts '<pre>'

            if other_asn1.nil?
              f.puts '-'
            else
              f.puts 'ne        : %s' % other_asn1.opt[:name]
              f.puts 'classname : %s' % other_asn1.classname

              if not other_asn1.opt[:cmdcode].nil?
                f.puts 'cmdcode   : 0x%s(%s)' % [other_asn1.opt[:cmdcode].to_s(16), other_asn1.opt[:cmdcode]]
              else
                f.puts 'cmdcode   : '
              end

              if not other_asn1.opt[:time].nil?
                f.puts 'time      : %s' % other_asn1.opt[:time].to_s_with_usec
              else
                f.puts 'time      : '
              end

              if not other_asn1.opt[:file].nil?
                lines = File.normalize(other_asn1.opt[:file]).wrap 70
                f.puts 'file      : %s' % lines.shift

                lines.each do |line|
                  f.puts '            %s' % line
                end
              end
            end

            f.puts '</pre>'
            f.puts '%s</th>' % (INDENT * 4)
            f.puts '%s</tr>' % (INDENT * 3)

            f.puts

            f.puts '%s<tr>' % (INDENT * 3)
            f.puts '%s<td>' % (INDENT * 4)
            f.puts '<pre>'

            if not asn1.nil?
              f.puts asn1.to_html
            end

            f.puts '</pre>'
            f.puts '%s</td>' % (INDENT * 4)

            f.puts

            f.puts '%s<td>' % (INDENT * 4)
            f.puts '<pre>'

            if not other_asn1.nil?
              f.puts other_asn1.to_html
            end

            f.puts '</pre>'
            f.puts '%s</td>' % (INDENT * 4)
            f.puts '%s</tr>' % (INDENT * 3)

            f.puts '%s</table>' % (INDENT * 2)

            index += 1
          end
        end

        f.puts '%s</body>' % INDENT

        # tail
        f.puts '</html>'
      end

      GC.start

      true
    end

    private

    def list2hash asn1_list
      asn1_hash = {}

      asn1_list.each do |asn1|
        asn1_hash[asn1.ne] ||= {}
        asn1_hash[asn1.ne][asn1.cmdcode] ||= []
        asn1_hash[asn1.ne][asn1.cmdcode] << asn1
      end

      asn1_hash
    end
  end
end

module ASN1
  # xml
  # 1) get
  #
  #    <get>
  #      <filter type="subtree">
  #        ....
  #      </filter>
  #    </get>
  #
  #    <get-config>
  #      <filter type="subtree">
  #        ....
  #      </filter>
  #    </get-config>
  #
  #    <get-next xmlns="http://www.zte.com.cn/zxr10/netconf/protocol/ns">
  #      <filter type="subtree">
  #        ....
  #      </filter>
  #    </get-next>
  #
  # 2) set
  #
  #    <edit-config>
  #      <config>
  #        ....
  #      </config>
  #    </edit-config>
  #
  # 3) action
  #
  #    <action xmlns="http://www.zte.com.cn/zxr10/netconf/protocol/ns">
  #      <object>
  #        ...
  #      </object>
  #    </action>
  class XML < Asn1
    # opt
    #     :name
    #     :ne
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = nil
      @classname = get_classname

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end

      @hash_asn1 = nil
      @asn1 = nil

      @match = nil
      @ignore = nil
      @ignore_paths = nil
      @sort_keys = nil
    end

    def validate?
      if not @data.nil?
        @hash_asn1 = @data.to_hash
      end

      true
    end

    def asn1
      if @asn1.nil? and not @hash_asn1.nil?
        @asn1 = to_ruby File.basename(@classname), @hash_asn1, File.dirname(@classname)

        if not @match.nil? or not @ignore.nil?
          set_state @match, @ignore
        end

        if not @ignore_paths.nil?
          set_ignore @ignore_paths
        end

        if not @sort_keys.nil?
          set_sort_keys @sort_keys
        end
      end

      @asn1
    end

    def == other_asn1
      if other_asn1.nil?
        set_state nil, nil

        false
      else
        if @classname != other_asn1.classname
          set_state false, nil
          other_asn1.set_state false, nil

          false
        else
          asn1 == other_asn1.asn1
        end
      end
    end

    def set_state match, ignore
      if @asn1.nil?
        @match = match
        @ignore = ignore
      else
        @asn1.set_state match, ignore

        @match = nil
        @ignore = nil
      end
    end

    def set_ignore paths_info
      if @asn1.nil?
        @ignore_paths = paths_info
      else
        paths_info.each do |path, condition|
          @asn1.set_ignore path, condition
        end

        @ignore_paths = nil
      end
    end

    def set_sort_keys sort_keys
      if @asn1.nil?
        @sort_keys = sort_keys
      else
        @asn1.set_sort_keys sort_keys

        @sort_keys = nil
      end
    end

    def to_string
      asn1.to_string
    end

    def to_html
      if asn1.respond_to? :to_html
        asn1.to_html
      else
        asn1.to_string
      end
    end

    private

    def get_classname
      classname = nil

      if @opt[:data].size > 4
        begin
          doc = REXML::Document.new @opt[:data].join("\n")

          REXML::XPath.each doc, '/*/config | /*/filter | /*/object' do |e|
            e.each_element do |element|
              @data = element

              break
            end

            break
          end
        rescue
        end
      end

      if not @data.nil?
        classname = '%s/%s' % [@data.attributes['xmlns'], @data.name]
      end

      classname
    end

    def to_ruby name, hash, path = nil
      xml_element = XMLElement.new name

      if path.nil?
        xml_element.path = name
      else
        xml_element.path = '%s.%s' % [path, name]
      end

      if not hash[:elements].nil? and not hash[:elements].empty?
        hash[:elements].each do |k, v|
          xml_element_list = XMLElementList.new k
          xml_element_list.path = '%s.%s' % [xml_element.path, k]

          v.each do |x|
            xml_element_list << to_ruby(k, x, xml_element.path)
          end

          xml_element.elements[k] = xml_element_list
        end
      end

      if not hash[:attributes].nil? and not hash[:attributes].empty?
        xml_element.attributes = XMLAttributes.new
        xml_element.attributes.path = xml_element.path

        hash[:attributes].each do |k, v|
          xml_element.attributes[k] = XMLText.new v
          xml_element.attributes[k].path = '%s.%s' % [xml_element.path, k]
        end
      end

      if not hash[:text].nil?
        xml_element.text = XMLText.new hash[:text]
        xml_element.text.path = xml_element.path
      end

      xml_element
    end
  end

  class XMLElement
    attr_reader :name
    attr_accessor :elements, :attributes, :text
    attr_accessor :path, :ignore, :match

    def initialize name
      @name = name

      @elements = {}
      @attributes = nil
      @text = nil
    end

    def == other_element
      if @ignore
        true
      else
        if other_element.nil?
          set_state nil, nil

          false
        else
          if @name != other_element.name
            set_state false, nil
            other_element.set_state false, nil

            false
          else
            status = true

            @elements.each do |k, v|
              if v != other_element.elements[k]
                status = false
              end
            end

            other_element.elements.each do |k, v|
              if @elements.has_key? k
                next
              end

              v.set_state nil, nil
              status = false
            end

            if @attributes != other_element.attributes
              status = false
            end

            if @text != other_element.text
              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if not @path.nil?
        if @path.to_s == path
          @ignore = true
        end
      end
    end

    def set_sort_keys sort_keys
      @elements.each do |k, v|
        if v.is_a? XMLElementList
          v.set_sort_keys sort_keys
        end
      end
    end

    def to_string
      lines = []

      str = @name

      if not @attributes.nil?
        str += ' ' + @attributes.to_string
      end

      if @elements.empty?
        lines << '<%s>%s</%s>' % [str, @text.to_string, @name]
      else
        lines << '<%s>' % str

        @elements.keys.sort.each do |k|
          @elements[k].to_string.each_line do |line|
            lines << (INDENT + line).rstrip
          end
        end

        lines << '</%s>' % @name
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      str = @name

      if not @attributes.nil?
        str += ' ' + @attributes.to_html
      end

      if @elements.empty?
        lines << '<'.escapes + str + '>'.escapes + @text.to_html + '</'.escapes + @name + '>'.escapes
      else
        lines << '<'.escapes + str + '>'.escapes

        @elements.keys.sort.each do |k|
          @elements[k].to_html.each_line do |line|
            lines << (INDENT + line).rstrip
          end
        end

        lines << '</'.escapes + @name + '>'.escapes
      end

      lines.join "\n"
    end

    def get key
      name, key = key.split '.', 2

      if name == @name
        if key.nil?
          if @text.nil?
            return to_string
          else
            return @text
          end
        end

        if not @attributes.nil?
          @attributes.each do |k, v|
            if key == k
              return v
            end
          end
        end

        @elements.each do |k, v|
          val = v.get key

          if not val.nil?
            return val
          end
        end
      end

      nil
    end
  end

  class XMLElementList < Array
    attr_reader :name
    attr_accessor :path, :ignore, :match, :sort_key

    def initialize name
      @name = name
    end

    def == other_element_list
      if @ignore
        true
      else
        if other_element_list.nil?
          set_state nil, nil

          false
        else
          if @name != other_element_list.name
            set_state false, nil
            other_element_list.set_state false, nil

            false
          else
            if not empty? and not @sort_key.nil?
              map = {}

              each do |element|
                value = element.get @sort_key

                map[value] ||= []
                map[value] << element
              end

              other_map = {}

              other_element_list.each do |element|
                value = element.get @sort_key

                other_map[value] ||= []
                other_map[value] << element
              end

              self.clear
              other_element_list.clear

              map.keys.sort.each do |k|
                list = map[k]
                other_list = other_map[k]

                if other_list.nil?
                  next
                end

                size = [list.size, other_list.size].min

                size.times do
                  self << list.shift
                  other_element_list << other_list.shift
                end

                if list.empty?
                  map.delete k
                end

                if other_list.empty?
                  other_map.delete k
                end
              end

              map.keys.sort.each do |k|
                map[k].each do |element|
                  self << element
                end
              end

              other_map.keys.sort.each do |k|
                other_map[k].each do |element|
                  other_element_list << element
                end
              end
            end

            status = true

            each_with_index do |element, index|
              if element != other_element_list[index]
                status = false
              end
            end

            if size < other_element_list.size
              other_element_list[size..-1].each do |element|
                element.set_state nil, nil
              end

              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |element|
        element.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end

      each do |element|
        element.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
      if not empty?
        sort_keys.each do |path, key|
          if @path == path
            @sort_key = key

            break
          end
        end
      end

      each do |element|
        element.set_sort_keys sort_keys
      end
    end

    def to_string
      lines = []

      each do |element|
        element.to_string.each_line do |line|
          lines << line.rstrip
        end
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      each do |element|
        element.to_html.each_line do |line|
          lines << line.rstrip
        end
      end

      lines.join "\n"
    end

    def get key
      name, key = key.split '.', 2

      if name == @name
        if key.nil?
          return to_string
        else
          each do |element|
            return element.get(key)
          end
        end
      end

      nil
    end
  end

  class XMLAttributes < Hash
    attr_accessor :path, :ignore

    def initialize
    end

    def == other_attributes
      if @ignore
        true
      else
        if other_attributes.nil?
          set_state nil, nil

          false
        else
          status = true

          each do |k, v|
            if v != other_attributes[k]
              status = false
            end
          end

          other_attributes.each do |k, v|
            if has_key? k
              next
            end

            v.set_state nil, nil
            status = false
          end

          status
        end
      end
    end

    def set_state match, ignore
      each do |k, v|
        v.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end

      each do |k, v|
        v.set_ignore path, condition, force
      end
    end

    def to_string
      str = ''
      size = 0

      keys.sort.each do |k|
        line = "%s = '%s'" % [k.to_string, self[k].to_string]
        size += line.bytesize

        str += ' %s' % line

        if size >= 60
          str += "\n  "
          size = 0
        end
      end

      str.rstrip
    end

    def to_html
      str = ''
      size = 0

      keys.sort.each do |k|
        line = "%s = '%s'" % [k.to_string, self[k].to_html]
        size += line.bytesize

        str += ' %s' % line

        if size >= 60
          str += "\n  "
          size = 0
        end
      end

      str.rstrip
    end
  end

  class XMLText
    attr_reader :value
    attr_accessor :path, :ignore, :match

    def initialize value
      @value = value
    end

    def == other_text
      if @ignore
        true
      else
        if other_text.nil?
          set_state nil, nil

          false
        else
          if @value == other_text.value
            set_state true, nil
            other_text.set_state true, nil

            true
          else
            set_state false, nil
            other_text.set_state false, nil

            false
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if force
        @ignore = true
      else
        if not @path.nil?
          if @path.to_s == path
            @ignore = true
          end
        end
      end
    end

    def to_string
      @value.to_string
    end

    def to_html
      str = @value.to_string

      if @ignore
        '<font color = "gray">%s</font>' % str
      else
        if @match.nil?
          '<font color = "blue">%s</font>' % str
        else
          if @match
            str
          else
            '<font color = "red">%s</font>' % str
          end
        end
      end
    end
  end
end