module JavaMixin
  module JavaProxy
    def klass
      getClass
    end

    def java_constants
      klass.java_constants
    end

    def java_variables
      klass.java_variables
    end

    def asn1_variables
      klass.asn1_variables
    end

    def get_field name
      klass.getField(name).get self
    end

    def to_s
      begin
        toString
      rescue
        super
      end
    end
  end

  module JavaClass
    def java_constants
      constants = {}

      modifier = Java::import 'java.lang.reflect.Modifier'

      fields.each do |field|
        if modifier.isFinal field.modifiers
          constants[field.name] = field.type
        end
      end

      constants
    end

    def java_variables
      variables = {}

      modifier = Java::import 'java.lang.reflect.Modifier'

      fields.each do |field|
        if not modifier.isFinal field.modifiers
          variables[field.name] = field.type
        end
      end

      variables
    end

    def asn1_variables
      variables = java_variables

      variables.delete_if do |name, type|
        name == 'value' and type.java_variables.empty?
      end

      variables
    end

    def superclass_names
      names = []

      klass = self

      loop do
        klass = klass.superclass

        if klass.nil? or klass.name.nil?
          break
        end

        names << klass.name
      end

      names
    end

    def number?
      klasses = [
        'byte', 'short', 'int', 'long', 'float', 'double', 'java.lang.Number'
      ]

      klasses.include? name or superclass_names.include? 'java.lang.Number'
    end

    def fields
      getFields
    end

    def name
      getName
    end
  end
end

if RUBY_PLATFORM =~ /java/
  module Java
    def self.include file
      require file
    end

    def self.import classname
      java_import(classname).first
    end
  end

  class JavaProxy
    include JavaMixin::JavaProxy
  end

  class Class
    include JavaMixin::JavaClass

    def name
      if respond_to? :java_class
        java_class.to_s.nil
      else
        super
      end
    end

    def fields
      if respond_to? :java_class
        java.lang.Class.forName(java_class.to_s).getFields
      else
        []
      end
    end
  end

  module Java
    module JavaLang
      class Class
        include JavaMixin::JavaClass
      end
    end
  end
else
  require 'rjb'

  module Java
    def self.include file
      file = File.expand_path file

      if File.extname(file).empty?
        file += '.jar'
      end

      if File.file? file
        if not Rjb::loaded?
          Rjb::load
        end

        Rjb::add_jar file
      else
        false
      end
    end

    def self.import classname
      Rjb::import classname
    end

    [
      'java.lang.Boolean',
      'java.lang.Character',
      'java.lang.Byte',
      'java.lang.Short',
      'java.lang.Integer',
      'java.lang.Long',
      'java.lang.Float',
      'java.lang.Double'
    ].each do |classname|
      import classname
    end
  end

  module Rjb
    class Rjb_JavaProxy
      include JavaMixin::JavaProxy
    end

    class Rjb_JavaClass
      include JavaMixin::JavaClass
    end
  end
end