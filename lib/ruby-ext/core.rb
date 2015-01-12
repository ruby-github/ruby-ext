require 'rexml/document'

Dir.chdir __dir__ do
  Dir.glob('core/**/*.rb').each do |name|
    require '%s/%s/%s' % ['ruby-ext', File.dirname(name), File.basename(name, '.*')]
  end
end