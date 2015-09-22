class ApplicationMailer < ActionMailer::Base
  default from: "team@#{ENV['MARKETPLACE_NAME'].gsub(' ', '').downcase}.com"
	layout 'mailer'
end
