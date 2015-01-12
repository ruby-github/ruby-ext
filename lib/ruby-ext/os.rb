Dir.chdir __dir__ do
  Dir.glob('os/**/*.rb').each do |name|
    require File.join('ruby-ext', File.dirname(name), File.basename(name, '.*'))
  end
end