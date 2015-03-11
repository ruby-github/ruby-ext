require 'rexml/document'

module REXML
  module Formatters
    class Pretty
      def initialize indentation = 2, ie_hack = false
        @indentation = indentation
        @level = 0
        @ie_hack = ie_hack
        @width = 80
        @compact = true
      end

      protected

      def write_element node, output
        output << ' ' * @level
        output << '<%s' % node.expanded_name

        node.attributes.each_attribute do |attr|
          output << ' '
          attr.write output
        end

        if node.children.empty?
          if @ie_hack
            output << ' '
          end

          output << '/'
        else
          output << '>'

          skip = false

          if compact
            if node.children.inject(true) { |s, c| s & c.is_a?(Text) }
              string = ''

              node.children.each do |child|
                write child, string
              end

              output << string
              skip = true
            end
          end

          unless skip
            output << "\n"
            @level += @indentation

            node.children.each do |child|
              if child.is_a? Text and child.to_s.strip.length == 0
                if child.to_s.gsub(/[\f\t ]+/, '').lines.size < 2
                  next
                end
              end

              write child, output
              output << "\n"
            end

            @level -= @indentation
            output << ' ' * @level
          end

          output << '</%s' % node.expanded_name
        end

        output << '>'
      end

      def write_text node, output
        lines = node.to_s.strip.lines.map { |line| line.rstrip }

        if lines.size > 1
          output << "\n"

          lines.each do |line|
            if $settings[:xml_text_indent]
              output << ' ' * (@level + @indentation)
            end

            output << line
            output << "\n"
          end

          output << ' ' * @level
        else
          output << lines.first.to_s
        end
      end

      def write_cdata node, output
        super
      end

      def write_comment node, output
        lines = node.to_s.strip.lines.map { |line| line.rstrip }

        if lines.size > 1
          output << ' ' * @level
          output << Comment::START
          output << "\n"

          lines.each_with_index do |line, index|
            line = line.rstrip

            if $settings[:xml_comment_indent] or index == 0
              output << ' ' * (@level + @indentation)
              output << line.lstrip
            else
              output << line
            end

            output << "\n"
          end

          output << ' ' * @level
          output << Comment::STOP
        else
          output << ' ' * @level
          output << ([Comment::START] + lines + [Comment::STOP]).join(' ')
        end
      end
    end
  end

  class Document
    def to_file file, encoding = nil
      if encoding.nil?
        xml_decl.encoding ||= 'UTF-8'
      else
        xml_decl.encoding = encoding
      end

      File.open file, 'w', encoding: xml_decl.encoding do |f|
        write f, 2
      end
    end

    def self.file file
      Document.new File.new(file)
    end

    private

    def build source
      begin
        Parsers::TreeParser.new(source, self).parse

        if self.root.nil?
          raise ParseException.new('no root tag')
        end
      ensure
        if source.is_a? IO
          source.close
        end
      end
    end
  end

  class IOSource
    def lines
      lines = []

      case
      when @er_source.is_a?(File)
        if File.file? @er_source.path
          IO.readlines(@er_source.path).each do |line|
            lines << line.force_encoding(@encoding)
          end
        end
      when @er_source.is_a?(StringIO)
        lines = @er_source.string.lines
      else
      end

      lines
    end

    def parse_exception
      exceptions = []

      lines.each_with_index do |line, index|
        if not line.valid_encoding?
          exceptions << [index, line]
        end
      end

      exceptions
    end
  end

  class ParseException
    def to_s
      lines = []

      if @continued_exception
        lines << @continued_exception.inspect
      end

      lines << super

      if @source and line > 0
        lines << 'Lineno: %s' % line
        lines << 'Position: %s' % position

        if @source.is_a? REXML::IOSource
          cur_line = @source.lines[line - 1]

          begin
            cur_line = cur_line.to_s.utf8.rstrip
          rescue
          end

          lines << 'Line: %s' % cur_line
        end
      end

      if @source.is_a? REXML::IOSource
        @source.parse_exception.each do |index, line|
          begin
            line = line.utf8.rstrip
          rescue
          end

          lines << '  %s line: %s' % [index + 1, line]
        end
      end

      lines.join "\n"
    end
  end

  class XMLDecl
    alias __write__ write
    alias __content__ content

    def write writer, indent = -1, transitive = false, ie_hack = false
      dowrite
      __write__ writer
      writer << "\n"
    end

    private

    def content enc
      @writeencoding = true
      __content__(enc).downcase
    end
  end

  class Element
    def to_hash
      hash = {}

      if has_text? and not text.strip.empty?
        hash[:text] = text.strip
      end

      if has_attributes?
        hash[:attributes] = {}

        attributes.each_attribute do |attr|
          hash[:attributes][attr.expanded_name] = attr.value
        end
      end

      if has_elements?
        hash[:elements] = {}

        each_element do |element|
          hash[:elements][element.expanded_name] ||= []
          hash[:elements][element.expanded_name] << element.to_hash
        end
      end

      hash
    end

    def from_hash hash
      if not hash.is_a? Hash
        return
      end

      if hash.has_key? :text
        self.text = hash[:text]
      end

      if hash.has_key? :attributes
        hash[:attributes].each do |k, v|
          self.attributes[k] = v
        end
      end

      if hash.has_key? :elements
        hash[:elements].each do |k, v|
          v.each do |x|
            e = REXML::Element.new k
            e.from_hash x
            self << e
          end
        end
      end
    end
  end
end