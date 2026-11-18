require "pp"

class ApplicationController < ActionController::Base
  helper_method :current_user
  before_action :require_login

  rescue_from StandardError, with: :render_error_page

  def current_user
    if session[:user_id]
      @current_user ||= User.find_by(id: session[:user_id])
    else
      @current_user = nil
    end
  end
  
  def require_login
    unless current_user
      if request.get? && request.path != login_path && request.path != logout_path
        session[:return_to] = request.fullpath
      end
      redirect_to login_url
    end
  end

  private

  def render_error_page(exception)
    Rails.logger.error("#{exception.class} (#{exception.message}):\n  #{Array(exception.backtrace).join("\n  ")}")

    @exception = exception
    @exception_wrapper = ActionDispatch::ExceptionWrapper.new(Rails.backtrace_cleaner, exception)
    trace_wrapper = if @exception_wrapper.source_extracts.empty? && @exception_wrapper.wrapped_causes.any?
                      @exception_wrapper.wrapped_causes.find { |w| w.source_extracts.any? } || @exception_wrapper
                    else
                      @exception_wrapper
                    end
    @traces = trace_wrapper.traces
    @trace_to_show = trace_wrapper.trace_to_show
    @source_extracts = trace_wrapper.source_extracts
    @show_source_idx = trace_wrapper.source_to_show_id

    if request.format.json?
      render json: { error: "Oops, da ist was schief gelaufen.", exception: exception.message }, status: :internal_server_error
    else
      render "errors/internal_server_error", formats: [:html], content_type: "text/html", status: :internal_server_error
    end
  end
end
