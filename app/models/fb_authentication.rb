class FbAuthentication < ActiveRecord::Base
  attr_accessible :token, :uid, :user_id
  belongs_to :user
end
