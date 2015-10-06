class AddTotalToFundraisingGoals < ActiveRecord::Migration
  def change
    add_column :fundraising_goals, :total, :float, default: 0.0
  end
end
