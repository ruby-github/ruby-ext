Dir.chdir __dir__ do
  Dir.glob('ext/**/*.rb').each do |name|
    if File.basename(name, '.*') == 'java'
      autoload :Java, File.join('ruby-ext', File.dirname(name), File.basename(name, '.*'))
    else
      require File.join('ruby-ext', File.dirname(name), File.basename(name, '.*'))
    end
  end
end