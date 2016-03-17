require 'clockwork'
require './config/boot'
require './config/environment'
module Clockwork
  handler do |job|
    puts "Running #{job}"
  end
  every(15.minutes, "Update Stripe Pending & Available"){
    "rake stripe_amounts:fetch"
  }

  every(1.week, 'Payroll', at: 'Friday 00:00') {
    `rake payout:all`
  }

  every(1.day, 'Push Monthly Revenue Data', at: '23:59') {
    `rake tasks:payout`
  }

  every(15.minutes, "Update Keen Data"){
    "rake keen:average_donations"
  }
  every(15.minutes, "Update Keen Data"){
    "rake keen:signups"
  }
  every(15.minutes, "Update Keen Data"){
    "rake keen:donations"
  }
  every(1.week, "Forgotten Donation", at: "Sunday 14:00"){
    "rake finish:donation"
  }
end