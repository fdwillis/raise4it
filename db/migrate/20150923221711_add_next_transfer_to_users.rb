class AddNextTransferToUsers < ActiveRecord::Migration
  def change
    add_column :users, :next_transfer, :float, default: 0
  end
end
