Gem::Specification.new do |s|
  s.name                  = 'ruby-ext'
  s.version               = '0.0.1'
  s.authors               = 'jack'
  s.date                  = '2014-03-14'
  s.summary               = 'ruby extension'
  s.description           = 'ruby extension'

  s.files                 = Dir.glob('{bin,lib}/**/*') + ['README.md']
  s.executables           = ['auto_system', 'drb']
  s.require_path          = 'lib'
  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency('rubyzip', ['>= 1.1.6'])
end