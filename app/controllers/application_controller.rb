class ApplicationController < ActionController::Base
  helper_method :current_user
  before_action :require_login

  def current_user
    if session[:user_id]
      @current_user ||= User.find_by(id: session[:user_id])
    else
      @current_user = nil
    end
  end
  
  def require_login
    unless current_user
      redirect_to login_url
    end
  end
end
