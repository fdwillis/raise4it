class SubscribeController < ApplicationController
before_filter :authenticate_user!

  def update
    plan = Stripe::Plan.retrieve(params[:id])
    @crypt = ActiveSupport::MessageEncryptor.new(ENV['SECRET_KEY_BASE'])

    @card_number = @crypt.encrypt_and_sign(params[:user][:card_number])
    @exp_month = params[:user][:exp_month]
    @exp_year = params[:user][:exp_year]
    @cvc_number = params[:user][:cvc_number]
    @username = params[:user][:username]

    begin
      @token = Stripe::Token.create(
        :card => {
          :number => @crypt.decrypt_and_verify(@card_number),
          :exp_month => @exp_month.to_i,
          :exp_year => @exp_year.to_i,
          :cvc => @cvc_number
        },
      )
    rescue Stripe::CardError => e
      # CardError; display an error message.
      flash[:error] = 'Card Details Not Valid'
      redirect_to edit_user_registration_path
    rescue => e
      # Some other error; display an error message.
      flash[:error] = 'Check Your Card Details Again'
      redirect_to edit_user_registration_path
    end

    if current_user.stripe_plan_id?  

      customer = Stripe::Customer.retrieve(current_user.marketplace_stripe_id)
      subscription = customer.subscriptions.retrieve(current_user.stripe_plan_id)
      
      subscription.plan = plan.id
      subscription.save

      current_user.update_attributes(role: 'merchant', stripe_plan_name: plan.name)
      redirect_to root_path, notice: "You Updated Your Plan To: #{plan.name}"
    elsif current_user.card?
      if current_user.marketplace_stripe_id
        customer = Stripe::Customer.retrieve(current_user.marketplace_stripe_id)
        subscription = customer.subscriptions.create(plan: plan)

        current_user.update_attributes(slug: @username, stripe_plan_id: subscription.id , stripe_plan_name: plan.name)
        flash[:alert] = "You Joined #{plan.name} Plan"
        redirect_to edit_user_registration_path
      else
        begin
          customer = Stripe::Customer.create(
            email: current_user.email,
            source: @token.id,
            plan: plan.id,
            description: 'MarketplaceBase'
          )
          current_user.update_attributes(slug: @username, marketplace_stripe_id: customer.id, role: 'merchant', username: @username, card_number: @card_number, exp_year: @exp_year, exp_month: @exp_month, cvc_number: @cvc_number, 
                                     stripe_plan_id: customer.subscriptions.data[0].id , stripe_plan_name: customer.subscriptions.data[0].plan.name)
          flash[:alert] = "You Joined #{plan.name} Plan"
          redirect_to edit_user_registration_path
        rescue Stripe::CardError => e
          # CardError; display an error message.
          flash[:error] = 'Card Details Not Valid'
          redirect_to edit_user_registration_path
        rescue => e
          # Some other error; display an error message.
          flash[:error] = 'Check Your Card Details Again'
        end
      end
    elsif !current_user.card?
      begin
        customer = Stripe::Customer.create(
          email: current_user.email,
          source: @token.id,
          plan: plan.id,
          description: 'MarketplaceBase'
        )
        current_user.update_attributes(slug: @username, marketplace_stripe_id: customer.id, role: 'merchant', username: @username, card_number: @card_number, exp_year: @exp_year, exp_month: @exp_month, cvc_number: @cvc_number, 
                                     stripe_plan_id: customer.subscriptions.data[0].id , stripe_plan_name: customer.subscriptions.data[0].plan.name)

        flash[:notice] = "Bank Account Details To Get Paid"
        redirect_to edit_user_registration_path
      rescue Stripe::CardError => e
        # CardError; display an error message.
        flash[:error] = 'Card Details Not Valid'
        redirect_to edit_user_registration_path
      rescue => e
        # Some other error; display an error message.
        flash[:error] = 'Check Your Card Details Again'
        redirect_to edit_user_registration_path
      end
    else
      flash[:error] = "Please Add A Credit Card"
      redirect_to edit_user_registration_path
    end
  end
end














