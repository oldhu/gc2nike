class ApplicationController < ActionController::Base
  include Logging

  protect_from_forgery with: :exception
  helper_method :current_user, :require_user, :logout_user
  
  private

  def current_user_session
    UserSession.find
  end

  def current_user
    current_user_session && current_user_session.record
  end

  def require_user
    unless current_user
      redirect_to "/login"
    end
  end

  def logout_user
    current_user_session.destroy if current_user_session
  end
  
  def login_user(login, password, remember)
    unless current_user
      begin
        nike = Nike.new(login, password)
      rescue
        logger.error "cannot login to nike plus"
      end
      session = UserSession.new(:login => login, :password => password, :remember_me => remember)
      session.save
    end
  end
end
