class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,:omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body
  has_many :authentications, :dependent=>:delete_all


  def apply_omniauth(auth)
    self.email = auth['extra']['raw_info']['email'] if auth['extra']['raw_info']['email']
    self.password = Devise.friendly_token[0,20]
    register_omniauth(auth)
  end

  def register_omniauth(auth)
    get_screen_name(auth)
    authentications.build(:provider=>auth['provider'], :uid=>auth['uid'], :token=>auth['credentials']['token'], :secret=>auth['credentials']['secret'],:screen_name => @screen_name)
  end

  def get_screen_name(auth)
    if auth['provider'] == 'twitter'
      @screen_name = auth['extra']['raw_info']['screen_name']
    else
      @screen_name = auth['info']['name']
    end
  end

end
