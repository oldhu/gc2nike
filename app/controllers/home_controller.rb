class HomeController < ApplicationController
  before_filter :require_user, :except => :login

  def index
    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  def logout
    logout_user
  end
  
  def login
    if params[:login]
      login_user(params[:email], params[:password], params[:remember])
    end
  end
end
