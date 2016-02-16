require 'ruby-ext/os'
require 'ruby-ext/core'
require 'ruby-ext/ext'

Encoding.default_internal ||= Encoding::default_external

# $settings:
#    :accounts
#    :colorize
#    :cov_build
#    :cov_dir
#    :debug
#    :email_admin
#    :email_cc
#    :email_send
#    :email_subject
#    :email_threshold_day
#    :email_threshold_file
#    :env
#    :error_puts
#    :error_scm
#    :exception_trace
#    :git_message
#    :git_password
#    :git_username
#    :klocwork_build
#    :klocwork_dir
#    :quicktest_expired
#    :rake_trace
#    :smtp_password
#    :smtp_username
#    :svn_message
#    :svn_password
#    :svn_username
#    :xml_comment_indent
#    :xml_text_indent

$settings = {
  colorize: false,
  email_threshold_day: 7,
  env: {},
  error_puts: true,
  error_scm: true
}

['JAVA_OPTIONS', '_JAVA_OPTIONS', 'JAVA_TOOL_OPTIONS'].each do |x|
  ENV.delete x
end

if File::FNM_SYSCASE.zero?
  ENV.each do |k, v|
    $settings[:env][k] = v
  end
else
  ENV.each do |k, v|
    $settings[:env][k.upcase] = v
  end
end