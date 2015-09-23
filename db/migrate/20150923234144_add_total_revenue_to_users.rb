class AddTotalRevenueToUsers < ActiveRecord::Migration
  def change
    add_column :users, :total_donation_revenue, :float
  end
end
