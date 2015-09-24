class AddAverageTextDonationToUsers < ActiveRecord::Migration
  def change
    add_column :users, :average_text_donation, :float, default: 0
  end
end
