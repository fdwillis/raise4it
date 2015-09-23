class AddAverageTextDonationToUsers < ActiveRecord::Migration
  def change
    add_column :users, :average_text_donation, :float
  end
end
