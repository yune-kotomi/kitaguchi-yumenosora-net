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
    payload = {'key' => auth_ticket.key, 'exp' => 5.minutes.from_now.to_i}
    token = JWT.encode(payload, service.key)
    redirect_to "#{service.authenticate_success}?id=#{service.id}&token=#{token}"
  end

  def identity_retrieved_after(identity_url)
    #ログイン完了
    @openid_url = OpenidUrl.where(:str => identity_url).first
    if @openid_url.nil?
      @openid_url = OpenidUrl.new(:str => identity_url)
      @openid_url.save
    end

    if flash[:auth_mode] == 'id_append'
      # ID追加処理
      if @openid_url.profile.present?
        # ID追加処理第1段階
        session[:login_profile_id] = @openid_url.profile.id
        session[:openid_url_id] = @openid_url.id
        session[:last_login] = Time.now.to_i
        flash[:auth_mode] = 'id_append'
        redirect_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
      else
        begin
          previous_openid_url = OpenidUrl.find(session[:openid_url_id])
          if Time.at(session[:last_login]) > 5.minutes.ago and previous_openid_url.profile.present?
            @openid_url.update_attribute(:profile_id, previous_openid_url.profile.id)
            redirect_to :controller => :profiles, :action => :show
          else
            # 時間たち過ぎかID追加対象のプロフィールが存在しないのでやり直し
            session[:openid_url_id] = nil
            session[:last_login] = nil
            redirect_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
          end
        rescue ActiveRecord::RecordNotFound
          # 前にログインに使用したOpenIDがDBに存在しないのでやりなおし
          redirect_to :controller => :profiles, :action => :authenticate, :mode => 'id_append'
        end
      end

    else
      # ログイン処理
      session[:openid_url_id] = @openid_url.id
      session[:last_login] = Time.now.to_i
      if @openid_url.profile.nil?
        flash[:notice] = "ログイン完了しました。"
        redirect_to :controller => :profiles,
          :action => :new,
          :service_id => @service.id

      else
        session[:login_profile_id] = @openid_url.profile.id
        if @service.present?
          deliver_to_service(@service, @openid_url.profile)
        else
          redirect_to :controller => :profiles,
            :action => :show,
            :id => @openid_url.profile.id
        end
      end
    end
  end
end
