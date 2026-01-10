class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    @users = User.all.order(:name)
  end

  def create
    user = User.find_by(id: params[:user_id])
    if user && user.pin == params[:pin]
      session[:user_id] = user.id
      redirect_to root_path, notice: "Willkommen, #{user.name}!"
    else
      redirect_to login_path, alert: "Falscher PIN oder Benutzer."
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "Abgemeldet."
  end
end
