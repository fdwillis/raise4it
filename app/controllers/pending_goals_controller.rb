class PendingGoalsController < ApplicationController
  def index
    if current_user.admin?
    	@pendings = FundraisingGoal.all.where(active: false)
    else
      redirect_to root_path
      flash[:error] = "You Dont Have Permission To Access That Page"
    end
  end

  def approve_goal
  	@instance = FundraisingGoal.find(params[:id])
    @instance.update_attributes(active: true)
    flash[:notice] = 'Goal Approved'
    redirect_to pending_goals_path
  end
end
