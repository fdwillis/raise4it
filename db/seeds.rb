User.destroy_all

@crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])

admin = User.create!(
  name: "Admin", 
  email: 'admin@test.com', 
  password: 'pa', 
  role: 'admin',
  username: 'admin',
  card_number: @crypt.encrypt_and_sign('4000000000000077'),
  cvc_number: '433',
  exp_month: '03',
  exp_year: '2034',
  account_number: @crypt.encrypt_and_sign('000123456789'),
  routing_number: '110000000',
  tax_id: @crypt.encrypt_and_sign('000000000'),
  first_name: 'Admin',
  last_name: 'Doe',
  business_name: 'Admin',
  business_url: 'https://www.merchant.com',
  support_email: 'support@fa.com',
  support_phone: '4143997842',
  support_url: "https://team.com",
  dob_day: 02,
  dob_month: 12,
  dob_year: 1995,
  stripe_account_type: 'sole_prop',
  statement_descriptor: "MarketBase",
  address: '526 west wilson suite B',
  address_city: "Madison",
  address_state: "WI",
  address_zip: 53703,
  address_country: 'US',
  currency: 'USD',
  bank_currency: 'USD',
  tax_rate: 3.0,
  legal_name: "Full Admin"
)

a = User.create!(
  email: 'a@a.com',
  password: 'pa',
  business_name: '34',
  card_number: @crypt.encrypt_and_sign('4000000000000077'), 
  exp_year: '2018',
  exp_month: '09',
  cvc_number: '3333',
  legal_name: 'full legal',
  username: 'full_',
  address_country: "US",
  currency: "USD",
  country_name: "United States",
  support_phone: 4143997341
)

a.skip_confirmation!
a.save!

admin.skip_confirmation!
admin.save!
admin.roles.create(title: 'admin')

puts "Created #{User.count} Users"

stripe_plans = Stripe::Plan.create(
  amount: 3635,
  interval: 'month',
  name: ENV['MARKETPLACE_NAME'],
  currency: 'USD',
  id: 987654345678,
  trial_period_days: 30,
)
puts "Created #{stripe_plans.id}"


