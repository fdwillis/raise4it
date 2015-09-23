require "active_support"

@crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])

namespace :email do

  desc "Email Pending Orders"
  task orders: :environment do
    User.all.each do |user|
    	orders = Order.all.where(merchant_id: user.id).where(paid: true).where(refunded: (false || nil)).where(tracking_number: nil).count
      if user.account_ready? && orders > 0
        Notify.orders(user, orders ).deliver_now
        puts Notify.orders(user, orders ).message
        puts "email to #{user.email}"
      end
    end
  end

  desc "Email Pending Refunds"
  task refunds: :environment do
  	User.all.each do |user|
  		refunds = Refund.all.where(merchant_id: user.id).where(status: "Pending").count
  		if user.account_ready? && refunds > 0
        Notify.refunds(user, refunds ).deliver_now
        puts Notify.refunds(user, refunds ).message
        puts "email to #{user.email}"
      end
  	end
  end
end

namespace :payout do
  include ActionView::Helpers::NumberHelper

  twilio_text = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  
  task all: :environment do
    User.all.each do |user|
      crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])
      
      if user.merchant_secret_key.present?  
        if user.admin?
          trans_amount = Stripe::Balance.retrieve()['available'][0].amount

          if trans_amount > 10000
            
            Stripe::Transfer.create(
              :amount => Stripe::Balance.retrieve()['available'][0].amount,
              :currency => "usd",
              :destination => crypt.decrypt_and_verify(user.stripe_account_id),
              :description => "Transfer for #{ENV["MARKETPLACE_NAME"]} revenue"
            )
          end
        end

        User.decrypt_and_verify(user.merchant_secret_key)          

        if user.team_members.count >= 1
          bal = Stripe::Balance.retrieve()['available'][0].amount
          user.team_members.each_with_index do |member, index|
            if  bal > 10000  
              amounts = user.team_members.map{|t| ((bal * t.percent.to_i) / 100 )}
                transfer = Stripe::Transfer.create(
                  :amount => amounts[index] - (amounts[index] * 0.0051).to_i,
                  :currency => "usd",
                  :destination => member.stripe_bank_id,
                  :description => "Transfer for #{ENV["MARKETPLACE_NAME"]} revenue"
                )
                if member.name.downcase == 'hacknvest'
                  Keen.publish("Hacknvest", {
                    income: ((transfer.amount.to_f) / 100),
                    marketplace_name: ENV["MARKETPLACE_NAME"],
                    })
                  # message = twilio_text.messages.create from: ENV['TWILIO_NUMBER'], to: User.find_by(role: 'admin').support_phone, body: "Transferred #{number_to_currency((transfer.amount.to_f) / 100, precision: 2)}"
                else
                  Keen.publish("Payout", {
                    income: ((transfer.amount.to_f) / 100),
                    marketplace_name: ENV["MARKETPLACE_NAME"],
                    })
                end
                puts "Team Paid"
            else
              puts "No Team Payout"
            end
          end
          Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
        else
          Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
          User.decrypt_and_verify(user.merchant_secret_key)          
          amount = Stripe::Balance.retrieve()['available'][0].amount
          if  amount > 10000  
            Stripe::Transfer.create(
              :amount => Stripe::Balance.retrieve()['available'][0].amount - (Stripe::Balance.retrieve()['available'][0].amount * 0.0051).to_i,
              :currency => "usd",
              :destination => Stripe::Account.retrieve.bank_accounts.data[0].id,
              :description => "Transfer for #{ENV["MARKETPLACE_NAME"]} revenue"
            )
            puts "Solo Paid"
          else
            puts "No Solo payout"
          end
        end
        Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
      else
        Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
        if user.admin?  
          bal = Stripe::Balance.retrieve()['available'][0].amount
          if bal >= 10000  
            transfer = Stripe::Transfer.create(
              :amount => Stripe::Balance.retrieve()['available'][0].amount - 100,
              :currency => "usd",
              :recipient => "self",
            )
            Keen.publish("Hacknvest", {
              income: ((transfer.amount.to_f) / 100),
              marketplace_name: ENV["MARKETPLACE_NAME"],
            })
            # message = twilio_text.messages.create from: ENV['TWILIO_NUMBER'], to: User.find_by(role: 'admin').support_phone, body: "Transferred #{number_to_currency((transfer.amount.to_f) / 100, precision: 2)}"
            puts "admin paid"
          end
        end
      end
    end
  end
  Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
end

namespace :stripe do
  desc "Sum active subscriptions directly from stripe"
  task monthly: :environment do
    User.all.each do |user|
      if user.merchant_secret_key.present?
        User.decrypt_and_verify(user.merchant_secret_key)
        Keen.publish("Subscription Revenue", {
          merchant_id: user.id, 
          marketplace_name: ENV["MARKETPLACE_NAME"],
          platform_for: 'donations',
          revenue: (Stripe::Customer.all.data.map(&:subscriptions).map(&:data).flatten.map(&:plan).map(&:amount).sum.to_f / 100)
        })
        Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
      else
        Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
        if user.admin?
          Keen.publish("Subscription Revenue", {
            merchant_id: user.id, 
            marketplace_name: ENV["MARKETPLACE_NAME"],
            platform_for: 'donations',
            revenue: (Stripe::Customer.all.data.map(&:subscriptions).map(&:data).flatten.map(&:plan).map(&:amount).sum.to_f / 100)
          })
        end
      end
    end
  end
  Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
end

namespace :keen do
  desc "Average Web Donation"
  task donations: :environment do
    User.all.each do |user|
      types = ['web', 'text']
      types.each do |type|
        if user.merchant_secret_key.present?
          donation = Keen.average("Donations", {
            target_property: "donation_amount",
            filters: [
              {
                property_name: "marketplace_name", 
                operator: "eq", 
                property_value: ENV["MARKETPLACE_NAME"]
              },
              {
                property_name: "merchant_id",
                operator: "eq",
                property_value: user.id
              },
              {
                property_name: 'donate_by',
                operator: "eq",
                property_value: type
              },
            ]  
          })
          if type == types[0]
            user.update_attributes(average_web_donation: donation)
            puts "Web: #{donation}"
          else
            user.update_attributes(average_text_donation: donation)
            puts "Text: #{donation}"
          end
        end
      end

      if user.admin?
        total_donations = Keen.sum("Donations", 
          target_property: "donation_amount",
          timeframe: 'this_year',
          filters: [
           {
            property_name: "marketplace_name", 
            operator: "eq", 
            property_value: ENV["MARKETPLACE_NAME"]
           } 
          ]
        )

        user.update_attributes(total_donation_revenue: total_donations)
        puts total_donations
      end
    end
  end
end

namespace :stripe_amounts do 
  desc "Grab stripe amounts"
  task fetch: :environment do
    User.all.each do |user|
      if user.merchant_secret_key.present?
        if user.admin?
          Stripe.api_key = Rails.configuration.stripe[:secret_key]
          User.stripe_amounts(user)
        else
          User.decrypt_and_verify(user.merchant_secret_key)
          User.stripe_amounts(user)
        end
      else
        if user.admin?
          Stripe.api_key = Rails.configuration.stripe[:secret_key]
          User.stripe_amounts(user)
        end
      end
      Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
    end
  end
end




