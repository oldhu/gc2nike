class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :login
      t.string :crypted_password
      t.string :gc_login
      t.string :gc_password
      t.string :nike_login
      t.string :nike_password
      t.timestamps
    end
  end
end
