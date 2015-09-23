class AddPendingAmountToUsers < ActiveRecord::Migration
  def change
    add_column :users, :pending_amount, :float, default: 0
  end
end
