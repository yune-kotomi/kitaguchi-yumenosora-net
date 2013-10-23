class ApplicationController < ActionController::Base
  before_filter :login_user
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  private
  def login_user
    begin
      @login_profile = Profile.find(session[:login_profile_id])
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end
    
    true
  end
  
  def login_required
    if session[:login_profile_id].present?
      return true
    end
    
    forbidden
    false
  end
  
  def forbidden
    render :text => 'Forbidden', :status => 403
  end
  
  def deliver_to_service(service, profile)
    # 初回認証ならサービス使用済みとして記録する
    if service.profile_services.where(:profile_id => profile.id).count == 0
      service.profile_services.create(:profile_id => profile.id)
    end
    
    # 認証チケット発行
    auth_ticket = service.auth_tickets.create(:profile_id => profile.id)
    
    # サービスへ引渡し
    timestamp = Time.now.to_i
    query = {
      :id => service.id,
      :key => auth_ticket.key,
      :timestamp => timestamp
    }
    query[:signature] = service.sign(query)
    
    query = query.map do |key, value|
      "#{key}=#{CGI.escape(value.to_s)}"
    end.join('&')
    
    redirect_to "#{service.auth_success}?#{query}"
  end
end
