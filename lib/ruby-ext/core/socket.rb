require 'socket'

class Socket
  def self.ip ignores = nil
    ips = ip_address_list.select { |x| x.ipv4_private? }.map { |x| x.ip_address }.sort

    if ips.empty?
      '127.0.0.1'
    else
      first = ips.first

      if not ignores.nil?
        ignores = ignores.to_array

        ips.delete_if do |x|
          del = false

          ignores.each do |ignore|
            if x.start_with? ignore
              del = true
            end
          end

          del
        end
      end

      ips.first || first
    end
  end
end