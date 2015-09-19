class Notify < ApplicationMailer
	default from: "no-reply@marketplacebase.com", return_path: 'fdwillis7@gmail.com'

  def account_approved(user)
    @user = user
    if !@user.admin?  
      @mail = mail(to: user.email, subject: "Business/Fundraising Account Approved") do |format|
        format.text
        format.html
      end
    end
  end

  def email_blast(sender_email, emails, subject, body)
    @body = body
    emails.each do |email|
      @email = email
      @mail = mail(from: sender_email, to: email, subject: subject) do |format|
        format.text
        format.html
      end
    end
  end
end
