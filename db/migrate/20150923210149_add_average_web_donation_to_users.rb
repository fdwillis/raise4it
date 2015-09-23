class AddAverageWebDonationToUsers < ActiveRecord::Migration
  def change
    add_column :users, :average_web_donation, :float
  end
end
