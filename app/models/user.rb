class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  extend FriendlyId
  friendly_id :username, use: [:slugged, :finders]
  
  has_many :products
  has_many :purchases
  has_many :transfers
  has_many :shipping_addresses
  has_many :stripe_customer_ids

  validates_uniqueness_of :business_name

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

  validates_numericality_of :exp_year, greater_than_or_equal_to: Time.now.year, allow_blank: true
  validates_numericality_of :dob_year, :dob_month, :dob_day, :exp_month, :cvc_number, allow_blank: true

  accepts_nested_attributes_for :shipping_addresses, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :stripe_customer_ids, reject_if: :all_blank, allow_destroy: true



  def admin?
    role == "admin"
  end

  def merchant?
    role == 'merchant'
  end

  def buyer?
    role == 'buyer'
  end

  def card?
    @crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])
    if card_number
      @card = @crypt.decrypt_and_verify(card_number)
    end
    shipping_addresses.present? && (@card.present? || card_number.present?) && exp_year.present? && exp_month.present? && cvc_number.present? && currency.present? && legal_name.present?
  end

  def user_recipient
    puts "Current Information for Bank Account Transfers:\n 
    SSN: #{tax_id.present?} \n Routing Number #{routing_number.present?} \n Legal Name: #{legal_name.present?} \n Account Number: #{account_number.present?}"
  end

  def shipping_to
    shipping_addresses.map{|f| [f.street.upcase, f.city.upcase, f.state.upcase, f.region.upcase, f.zip].join(", ")}
  end

  def merchant_ready?
    tax_rate.present? && return_policy.present? && address_city.present? && address_state.present? && address_zip.present? && address.present? && bank_currency.present? && address_country.present? && statement_descriptor.present? && routing_number.present? && account_number.present? && business_name.present? && business_url.present? && support_email.present? && support_phone.present? && support_url.present? && first_name.present? && last_name.present? && dob_day.present?&& dob_month.present? && dob_year.present? && stripe_account_type.present?
  end

  def merchant_changed
    routing_number_changed? || account_number_changed? || stripe_account_type_changed?
  end

  def stripe_account_id_ready?
    stripe_account_id.present?
  end

  def self.charge_n_process(secret_key, user, price, token, merchant_account_id, currency)
    @token = token.id
    @price = price
    @merchant60 = ((@price) * 60) /100
    @fee = (@price - @merchant60)

    @crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])
    @merchant_secret = @crypt.decrypt_and_verify(secret_key)
    Stripe.api_key = @merchant_secret

    @customers = Stripe::Customer.all.data
    @customer_ids = @customers.map(&:id)
    @customer_account = user.stripe_customer_ids.where(business_name: Stripe::Account.retrieve().business_name).first

    if @customer_ids.include? @customer_account.customer_id
      customer_card = @customer_account.customer_card
      charge = Stripe::Charge.create(
      {
        amount: @price,
        currency: 'USD',
        customer: @customer_account.customer_id ,
        description: 'MarketplaceBase',
        application_fee: @fee,
      },
      {stripe_account: merchant_account_id}
        )  
    else

      @customer = Stripe::Customer.create(
        :description => "Customer for test@example.com",
        :source => @token
      )

      charge = Stripe::Charge.create(
        {
          amount: @price,
          currency: 'USD',
          customer: @customer.id,
          description: 'MarketplaceBase',
          application_fee: @fee,
        },
        {stripe_account: merchant_account_id}
        )

      user.stripe_customer_ids.create(business_name: Stripe::Account.retrieve().business_name, 
                                      customer_card: @customer.default_source, customer_id: @customer.id)
    end
  end

  def self.charge_for_admin(user, price, token)
    Stripe::Charge.create(
      amount: price,
      currency: "usd",
      source: token, 
      description: "MarketplaceBase",
    )
  end
end







