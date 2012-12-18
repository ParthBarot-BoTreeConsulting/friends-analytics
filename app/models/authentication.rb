class Authentication < ActiveRecord::Base
  belongs_to :user

  attr_accessible :provider, :screen_name, :secret, :token, :uid, :user_id
end
