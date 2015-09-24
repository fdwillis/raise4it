class CreateSignUps < ActiveRecord::Migration
  def change
    create_table :sign_ups do |t|
      t.belongs_to :user, index: true
      t.string :end_year
      t.string :start_year
      t.string :start_month
      t.string :end_month
      t.string :start_day
      t.string :end_day
      t.float :value

      t.timestamps null: false
    end
    add_foreign_key :sign_ups, :users
  end
end
