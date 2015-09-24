class CreateRakeDonations < ActiveRecord::Migration
  def change
    create_table :rake_donations do |t|
      t.string :start_day
      t.string :end_day
      t.string :start_month
      t.string :end_month
      t.string :start_year
      t.string :end_year
      t.float :value
      t.belongs_to :user, index: true

      t.timestamps null: false
    end
    add_foreign_key :rake_donations, :users
  end
end
