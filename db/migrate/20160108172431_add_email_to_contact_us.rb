class AddEmailToContactUs < ActiveRecord::Migration
  def change
    add_column :contact_us, :email, :string
  end
end
