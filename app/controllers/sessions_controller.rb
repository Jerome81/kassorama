class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    @users = User.all.order(:name)
  end

  def create
    user = User.find_by(id: params[:user_id])
    if user && user.pin == params[:pin]
      session[:user_id] = user.id
      return_to = session.delete(:return_to)
      redirect_to (return_to.presence || root_path), notice: "Willkommen, #{user.name}!"
    else
      redirect_to login_path, alert: "Falscher PIN oder Benutzer."
    end
  end

  def destroy
    session[:user_id] = nil

    pos_return_path = extract_pos_return_path(params[:return_to]) || extract_pos_return_path(request.referer)
    if pos_return_path
      session[:return_to] = pos_return_path
    else
      session.delete(:return_to)
    end

    redirect_to login_path, notice: "Abgemeldet."
  end

  private

  def extract_pos_return_path(url_or_path)
    return nil if url_or_path.blank?

    path = URI.parse(url_or_path.to_s).path rescue url_or_path.to_s
    if path =~ %r{\A/pos/(\d+)(?:/|\z)}
      "/pos/#{$1}"
    end
  end
end
