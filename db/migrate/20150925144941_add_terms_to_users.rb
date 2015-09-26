class AddTermsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :agreed_to_terms, :boolean, default: false
  end
end
