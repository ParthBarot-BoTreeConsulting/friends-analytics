class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def twitter
    auth =  request.env["omniauth.auth"]
    session[:tw_token] = auth.credentials.token
    session[:tw_secret] = auth.credentials.secret
    session[:screen_name] = auth.extra.raw_info.screen_name
    session[:twUid] = auth.uid
    session[:signed_in_with] = auth.provider
    process_callback(true)
  end

  def facebook
    data = request.env["omniauth.auth"].extra.raw_info
    session[:access_token] = request.env["omniauth.auth"].credentials.token
    if data.email.nil?
      @email = data.link
    else
      @email = data.email
    end
    process_callback
    add_screen_name
  end

  #def create_new_user
  #  user = User.new
  #  user.email = @email
  #  user.encrypted_password = Devise.friendly_token[0, 20]
  #  user.save(:validate => false)
  #  user
  #end

  private

  def process_callback(is_twitter=false)
    if user_signed_in?
      add_authentication
      redirect_to root_url
    else
      process_create_user(is_twitter)
    end
  end

  # Add authentication to current user
  def add_authentication
    auth = request.env["omniauth.auth"]
    authentication = current_user.authentications.find_by_provider(auth.provider)
    if authentication.blank?
      current_user.register_omniauth(auth)
      current_user.save(:validate => false)
      flash[:notice] = "Connected to #{auth["provider"]} successfully."
    else
      authentication.update_attribute('token', auth.credentials.token)
    end

  end

  def process_create_user(is_twitter = false)
    auth = request.env["omniauth.auth"]
    authentication = Authentication.find_by_provider_and_uid(auth['provider'], auth['uid'])
    if authentication.present?
      #flash[:notice] = "Signed in successfully."
      sign_in(:user, authentication.user)
      redirect_to root_url
    else
      user = User.new
      user.apply_omniauth(auth)

      if user.save(:validate => false)
        flash[:notice] = "Account created and you have been signed in!"
        sign_in_and_redirect(:user, user)
      else
        flash[:error] = "Error while logging in! #{user.errors.full_messages.join(" and ")}"
        redirect_to root_url
      end

    end
  end

# Added by:: Parth
#
# add screen name of current user on Authentication model with corresponding provider
#
  def add_screen_name
    auth = request.env["omniauth.auth"]
    authentication = current_user.authentications.find_by_provider(auth.provider)
    authentication.update_attribute('screen_name',auth.info.name)
    session[:fb_screen_name] = auth.info.name
  end

end
