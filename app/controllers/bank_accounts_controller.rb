class BankAccountsController < ApplicationController
  def create
    begin
      member = params[:member]
      token = User.bank_token(member[:country], member[:acct_num], member[:rout_num])
      bank_account = User.new_member(current_user, current_user.stripe_account_id, token.id, member[:percent].to_f, member)

      if !bank_account.nil?
        redirect_to request.referrer
        flash[:notice] = "You Added #{member[:name].titleize} To Your Team"
        return
      else
        redirect_to request.referrer
        flash[:error] = "Team Members Percentages Can't Exceed 100%"
        return
      end
    rescue Stripe::StripeError => e
      body = e.json_body
      err  = body[:error]
      redirect_to edit_user_registration_path
      flash[:error] = "#{err[:message]}"      
      return
    end
  end

  def destroy
    member = TeamMember.find_by(uuid: params[:id])
    name = member.name

    begin
      User.delete_member(current_user, current_user.stripe_account_id, member)
      flash[:notice] = "You Deleted #{name.titleize} From Your Team"
      redirect_to request.referrer
      return
    rescue Stripe::StripeError => e
      body = e.json_body
      err  = body[:error]
      redirect_to edit_user_registration_path
      flash[:error] = "#{err[:message]}"      
      return
    end
  end

  def update
    if params[:user][:member_uuid]
      member = TeamMember.find_by(uuid: params[:user][:member_uuid])
      
      if current_user.team_members.where.not(uuid: params[:user][:member_uuid]).map(&:percent).sum + params[:user][:percent].to_f <= 100.00
        member.update_attributes(percent: params[:user][:percent])
        redirect_to request.referrer
        flash[:notice] = "Updated #{member.name} percentage"
      else
        redirect_to request.referrer
        flash[:error] = "Team Members Percentages Can't Exceed 100%"
      end
    end
  end
end
