class PendingGoalsController < ApplicationController
  def index
  	 @pendings = FundraisingGoal.all.where(active: false)
  end

  def approve_goal
  	@instance = FundraisingGoal.find(params[:id])
    @instance.update_attributes(active: true)
    flash[:notice] = 'Goal Approved'
    redirect_to pending_goals_path
  end
end
