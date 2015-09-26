require "active_support"

@crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])

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
                  twilio_text.account.messages.create from: ENV['TWILIO_NUMBER'], to: User.find_by(role: 'admin').support_phone, body: "Transferred #{number_to_currency((transfer.amount.to_f) / 100, precision: 2)}"
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
            twilio_text.account.messages.create from: ENV['TWILIO_NUMBER'], to: User.find_by(role: 'admin').support_phone, body: "Transferred #{number_to_currency((transfer.amount.to_f) / 100, precision: 2)}"
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
        user.update_attributes(monthly_revenue: (Stripe::Customer.all.data.map(&:subscriptions).map(&:data).flatten.map(&:plan).map(&:amount).sum.to_f / 100))
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
          user.update_attributes(monthly_revenue: (Stripe::Customer.all.data.map(&:subscriptions).map(&:data).flatten.map(&:plan).map(&:amount).sum.to_f / 100))
        end
      end
    end
  end
  Stripe.api_key = ENV['STRIPE_SECRET_KEY_TEST']
end

namespace :keen do
  desc "Average Donation"
  task average_donations: :environment do
    User.all.each do |user|
      types = ['web', 'text']
      if user.merchant_secret_key.present? || user.admin?
        types.each do |type|
          if !user.admin?  
            donation_ave = Keen.average("Donations", {
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
          else
            donation_ave = Keen.average("Donations", {
              target_property: "donation_amount",
              filters: [
                {
                  property_name: "marketplace_name", 
                  operator: "eq", 
                  property_value: ENV["MARKETPLACE_NAME"]
                },
                {
                  property_name: 'donate_by',
                  operator: "eq",
                  property_value: type
                },
              ]  
            })
          end
          if type == types[0]
            user.update_attributes(average_web_donation: donation_ave.to_f)
            puts "Web: #{donation_ave}"
          else
            user.update_attributes(average_text_donation: donation_ave.to_f)
            puts "Text: #{donation_ave}"
          end
        end
        if !user.admin?
          total_donations = Keen.sum("Donations", 
            target_property: "donation_amount",
            timeframe: 'this_year',
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
            ]
          )

        else
          total_donations = Keen.sum("Donations", {
            target_property: "donation_amount",
            filters: [
              {
                property_name: "marketplace_name", 
                operator: "eq", 
                property_value: ENV["MARKETPLACE_NAME"]
              },
            ]  
          })
        end
        user.update_attributes(total_donation_revenue: total_donations.to_f)
        puts "#{user.username} Donation revenue #{total_donations}"
      end
    end
  end

  desc "Get Signups For Admin"
  task signups: :environment do
    keen_signups = Keen.count("Sign Ups", 
      max_age: 300, 
      timeframe: 'this_year', 
      interval: 'daily',
      filters: [
        {
          property_name: "marketplace_name", 
          operator: "eq", 
          property_value: ENV["MARKETPLACE_NAME"]
        }
      ]
    )

    keen_signups.each do |su|
      admin = User.all.where(role: 'admin')[0]
      date_start = su['timeframe']['start']
      date_end = su['timeframe']['end']
      data = admin.sign_ups.find_or_create_by(start_year: date_start[0..3], start_month: date_start[5..6], start_day: date_start[8..9], 
                                              end_year: date_end[0..3], end_month: date_end[5..6], end_day: date_end[8..9])
      if !data.new_record?
        data.update_attributes(value: su['value'])
        data.save!
      else
        data.update_attributes(value: su['value'])
      end
    end
  end

  desc "Getting Donation Data"
  task donations: :environment do
    User.all.each do |user|  
      if user.merchant_secret_key.present?
        rake_donations = Keen.sum("Donations",
          timeframe: 'this_year',
          target_property: "donation_amount",
          interval: 'daily',
          filters: [
            {
              property_name: "merchant_id",
              operator: "eq",
              property_value: user.id
            },
            {
              property_name: "marketplace_name", 
              operator: "eq", 
              property_value: ENV["MARKETPLACE_NAME"]
            }
          ]
        )
      elsif user.admin?  
          rake_donations = Keen.sum("Donations",
          timeframe: 'this_year',
          target_property: "donation_amount",
          interval: 'daily',
          filters: [
            {
              property_name: "marketplace_name", 
              operator: "eq", 
              property_value: ENV["MARKETPLACE_NAME"]
            }
          ]
        )
      end
      if rake_donations.present?  
        rake_donations.each do |d|
          date_start = d['timeframe']['start']
          date_end = d['timeframe']['end']
          data = user.rake_donations.find_or_create_by(start_year: date_start[0..3], start_month: date_start[5..6], start_day: date_start[8..9], 
                                                end_year: date_end[0..3], end_month: date_end[5..6], end_day: date_end[8..9])
          if !data.new_record?
            data.update_attributes(value: d['value'])
            data.save!
          else
            data.update_attributes(value: d['value'])
          end
        end
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




