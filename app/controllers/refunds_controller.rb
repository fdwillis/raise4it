class RefundsController < ApplicationController
  before_filter :authenticate_user!
  def index
    @refunds = Purchase.all.where(merchant_id: current_user.id).where(status: "Pending Refund")
  end
  def create
    #Test refund for admin, might need to filter because admin doesnt have merchant_secret field
    #Track With Keen "refund requests"
    # let merchants handle refunds
    purchase = Purchase.find_by(stripe_charge_id: params[:refund_id])
    purchase.update_attributes(status: "Pending Refund")
    redirect_to purchases_path, alert: "Your Refund Is Pending"
  end
  def update
    #Track With Keen "refunds fullfilled"
    @product = Product.find_by(uuid: params[:uuid])
    purchase = Purchase.find_by(stripe_charge_id: params[:refund_id])
    @new_q = (@product.quantity + purchase.quantity)

    if @new_q > 0
      @product.update_attributes(status: nil)
    end
    if Product.find_by(uuid: params[:uuid]).user.role == 'admin'
      debugger
      ch = Stripe::Charge.retrieve(params[:refund_id])
      debugger
      refund = ch.refunds.create(amount: ch.amount)
      debugger
    else
      @crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])
      Stripe.api_key = @crypt.decrypt_and_verify((@product).user.merchant_secret_key)

      ch = Stripe::Charge.retrieve(params[:refund_id])
      refund = ch.refunds.create(refund_application_fee: true, amount: ch.amount)

      Stripe.api_key = Rails.configuration.stripe[:secret_key]
    end

    purchase.update_attributes(status: "Refunded", refunded: true)
    @product.update_attributes(quantity: @new_q)
    redirect_to refunds_path, notice: "Refund Fullfilled"
  end
end
