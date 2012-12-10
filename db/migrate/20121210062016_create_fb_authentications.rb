class CreateFbAuthentications < ActiveRecord::Migration
  def change
    create_table :fb_authentications do |t|
      t.integer :user_id
      t.string :uid
      t.string :token

      t.timestamps
    end
  end
end
