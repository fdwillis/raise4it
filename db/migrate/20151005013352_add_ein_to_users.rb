class AddEinToUsers < ActiveRecord::Migration
  def change
    add_column :users, :ein, :string
  end
end
