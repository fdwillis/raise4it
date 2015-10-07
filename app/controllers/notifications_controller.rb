class NotificationsController < ApplicationController
  protect_from_forgery except: :twilio
  include ActionView::Helpers::NumberHelper

  def twilio
    render nothing: true, status: :ok, content_type: "application/xml"
    twilio_text = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
    crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])
    text_message = params[:Body].split

    amount = (text_message[0].gsub(/[^0-9]/i, '').to_i)
    if text_message[0].include?(".")
      stripe_amount = amount
    else
      stripe_amount = amount * 100
    end

    if stripe_amount >= 100 && stripe_amount < 99999999

      user_search = User.find_by(username: text_message[1].downcase)
      if text_message[1] && user_search
        raiser_username = text_message[1].downcase
      
        location = {
          'city' => params[:FromCity],
          'region_name' => params[:FromState],
          'zipcode' => params[:FromZip],
          'country_code' => params[:FromCountry],
        }
        phone_number = params[:From][2,params[:From].length]
        if text_message[2]  
          donation_type = text_message[2].downcase
          
          the_plan = DonationPlan.find_by(amount: (stripe_amount / 100).to_f)
          if the_plan
            donation_plan = the_plan.uuid
          else
            twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "There Is No Monthly Plan For That Amount Assigned To #{raiser_username}"})
            return
          end
        end

        donater = User.find_by(support_phone: phone_number)
        fundraiser = User.find_by(username: raiser_username)

        if (fundraiser && fundraiser.merchant_secret_key?) || fundraiser.admin?
          if donater && donater.card?
            begin
              token = User.new_token(donater, crypt.decrypt_and_verify(donater.card_number))
            rescue Stripe::CardError => e
              body = e.json_body
              err  = body[:error]
              twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "#{err[:message]}"})
              return
            end
            if !fundraiser.admin?
              stripe_account_id = crypt.decrypt_and_verify(fundraiser.stripe_account_id)
              begin
                if donation_type == 'monthly'  
                  subscription = User.subscribe_to_fundraiser(fundraiser.merchant_secret_key, donater, token.id, stripe_account_id, donation_plan)
                  @donation = donater.donations.create(application_fee: (subscription.plan.amount * (subscription.application_fee_percent / 100 ) / 100 ) , stripe_plan_name: subscription.plan.name, stripe_subscription_id: donation_plan ,active: true, donation_type: 'subscription', subscription_id: subscription.id, organization: raiser_username, amount: subscription.plan.amount, uuid: SecureRandom.uuid, fundraiser_stripe_account_id: fundraiser.merchant_secret_key)
                else
                  charge = User.charge_n_process(fundraiser.merchant_secret_key, donater, stripe_amount, token.id, stripe_account_id )
                  Stripe.api_key = Rails.configuration.stripe[:secret_key]
                  @donation = donater.donations.create(application_fee: ((Stripe::ApplicationFee.retrieve(charge.application_fee).amount) / 100).to_f , donation_type: 'one-time', organization: raiser_username, amount: stripe_amount, uuid: SecureRandom.uuid)
                end
              rescue Stripe::CardError => e
                body = e.json_body
                err  = body[:error]
                twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "#{err[:message]}"})
                return
              end
            else
              begin  
                if donation_type == 'monthly'  
                  @subscription = User.subscribe_to_admin(donater, token.id, donation_plan )
                  @donation = donater.donations.create(stripe_plan_name: @subscription.plan.name, stripe_subscription_id: donation_plan ,active: true, donation_type: 'subscription', subscription_id: @subscription.id ,organization: raiser_username, amount: @subscription.plan.amount, uuid: SecureRandom.uuid)
                else
                  User.charge_for_admin(donater, stripe_amount, token.id)
                  @donation = donater.donations.create(donation_type: 'one-time', organization: raiser_username, amount: stripe_amount, uuid: SecureRandom.uuid)
                end
              rescue Stripe::CardError => e
                body = e.json_body
                err  = body[:error]
                twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "#{err[:message]}"})
                return
              end
            end

            Donation.text_donation(@donation, location, 'text')
            
            if donater.notifications == true
              fundraiser.text_lists.find_or_create_by(phone_number: phone_number)
            end

            Stripe.api_key = Rails.configuration.stripe[:secret_key]
            # Twilio message to thank user for donation
            begin
              twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "Thanks for your #{number_to_currency(text_message[0], precision: 2)} donation to #{raiser_username}"})
            rescue Twilio::REST::RequestError => e
              puts e.message
            end
            return
          else
            Bitly.use_api_version_3

            Bitly.configure do |config|
              config.api_version = 3
              config.access_token = ENV['BITLY_ACCESS_TOKEN']
            end

            @bitly_link = Bitly.client.shorten("#{ENV['NEW_DONATE_LINK']}amount=#{stripe_amount}&fundraiser_name=#{raiser_username}&phone_number=#{phone_number}&donation_plan=#{donation_plan}").short_url

            # Link to enter card info and create user profile
            twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "Please follow link to enter Credit Card details #{@bitly_link}"})
            return
          end
        else
          #Twilio message back to donater
          twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "Please enter a dollar amount first, then username of the fundraiser. Example: 90 valid_username"})
          return
        end
      else
        twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "Please enter a valid username to donate to. Example: 90 valid_username"})
        return
      end
    else
      twilio_text.account.messages.create({from: "#{ENV['TWILIO_NUMBER']}", to: params[:From] , body: "Please enter a minimum dollar amount of 1 or max of 999,999.99, then a valid username to donate to. Example: 90 valid_username"})
      return
    end
  end

  def remove_text
    numbers = params[:text_id]
    numbers.each do |num|
      number = TextList.find(num.to_i)
      number.delete
    end
    redirect_to request.referrer
    flash[:notice] = "You removed your number from #{numbers.count} text lists"
  end
  def remove_email
    emails = params[:email_id]
    emails.each do |email|
      number = EmailList.find(email.to_i)
      number.delete
    end
    redirect_to request.referrer
    flash[:notice] = "You removed your email from #{emails.count} email lists"
  end

  def stop_notifications
    if params[:stop_notifications] == 'true'
      current_user.update_attributes(notifications: false)
      EmailList.all.where(email: current_user.email).destroy_all
      TextList.all.where(phone_number: current_user.support_phone).destroy_all
      flash[:notice] = "Your notifications have been turned off. You will no longer be added to any text or email lists"
    else
      current_user.update_attributes(notifications: true)
      flash[:notice] = "Your notifications have been turned on."
    end
    redirect_to request.referrer
  end

  def import_numbers
    TextList.import(params[:file], current_user)
    redirect_to request.referrer
    flash[:notice] = "Imported Phone Numbers Successfully"
  end

  def import_emails
    emails = EmailList.import(params[:file], current_user)
    redirect_to request.referrer
    flash[:notice] = "Imported Emails Successfully"
  end
end

# Test CURL
  # Tracking
    # curl -X POST -d "msg[checkpoints][][message]=bar&msg[tracking_number]=1Z0F28171596013711&msg[checkpoints][][tag]=tag&msg[checkpoints][][checkpoint_time]=2014-05-02T16:24:38" http://localhost:3000/notifications
  # twilio
    # curl -X POST -d 'Body=22 admin monthly&From=+14143997341' http://localhost:3000/notifications/twilio
    # curl -X POST -d 'Body=90.30 admin_tes&From=+14143997341' https://marketplace-base.herokuapp.com/notifications/twilio

# Send Twilio Message
  # twilio_text = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  # message = twilio_text.messages.create from: ENV['TWILIO_NUMBER'], to: '4143997341', body: "Thanks for wanting to donate. https://www.google.com/ "

