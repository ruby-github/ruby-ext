require 'net/smtp'

module Net
  module_function

  # opt
  #   admin
  #   authtype
  #   bcc
  #   cc
  #   file
  #   html
  #   port
  #   password
  #   subject
  #   text
  #   username
  def send_smtp address, from_addr, to_addrs, logger = nil, opt = {}
    if not $settings[:email_send]
      return true
    end

    opt = {
      username: $settings[:smtp_username] || 'ZhouYanQing181524',
      password: $settings[:smtp_password] || 'smtp@2013',
      cc: $settings[:email_cc],
      admin: $settings[:email_admin]
    }.merge opt

    begin
      SMTP.start address, opt[:port] || 25, '127.0.0.1', opt[:username], opt[:password], opt[:authtype] || :login do |smtp|
        mail = MailFactory.new
        mail.from = from_addr.to_s
        mail.subject = opt[:subject].to_s

        if not opt[:text].nil?
          mail.text = opt[:text].to_s
        end

        if not opt[:html].nil?
          mail.html = opt[:html].to_s
        end

        addrs = []

        if not to_addrs.nil?
          addrs += to_addrs.to_array
          mail.to = addrs.join ', '
        end

        if not opt[:cc].nil?
          addrs += opt[:cc].to_array
          mail.cc = opt[:cc].to_array.join ', '
        end

        if not opt[:bcc].nil?
          addrs += opt[:bcc].to_array
          mail.bcc = opt[:bcc].to_array.join ', '
        end

        addrs.uniq!

        if addrs.empty?
          if not opt[:admin].nil?
            addrs = opt[:admin].to_array
          end

          if addrs.empty?
            return true
          end
        end

        if not opt[:file].nil?
          opt[:file].to_array.each do |file|
            mail.attach file.locale
          end
        end

        if block_given?
          yield mail
        end

        begin
          smtp.open_message_stream from_addr, addrs do |file|
            file.puts mail.to_s
          end

          if logger
            logger.debug 'send mail to %s' % addrs.join(', ')
          end

          true
        rescue
          if logger
            logger.exception $!.to_s
          end

          if not opt[:admin].nil?
            smtp.open_message_stream from_addr, opt[:admin].to_array do |file|
              file.puts mail.to_s
            end
          end

          false
        end
      end
    rescue
      if logger
        logger.exception $!.to_s
      end

      false
    end
  end
end