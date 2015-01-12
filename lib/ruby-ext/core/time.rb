class Time
  def to_s_with_usec
    '%s %s' % [strftime('%Y-%m-%d %H:%M:%S'), usec]
  end
end