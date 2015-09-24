class AddMonthlyRevenueToUsers < ActiveRecord::Migration
  def change
    add_column :users, :monthly_revenue, :float, default: 0
  end
end
