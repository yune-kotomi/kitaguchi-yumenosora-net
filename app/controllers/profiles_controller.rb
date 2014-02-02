class ProfilesController < ApplicationController
  before_filter :login_required, :only => [:show, :update]

  # GET /profiles/1
  # GET /profiles/1.json
  def show
    @profile = @login_profile
    begin
      @service = Service.find(params[:service_id]||session[:service_back_to])
      session[:service_back_to] = @service.id
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end
  end
  
  def new
    @openid_url = OpenidUrl.find(session[:openid_url_id])
    @profile = Profile.new
  end
  
  def create
    @service = Service.find(params[:id])
    @openid_url = OpenidUrl.find(session[:openid_url_id])
    if @openid_url.profile.present?
      # 登録済みのOpenIDなのでプロフィールを作成しない
      redirect_to :action => :login
    else
      @profile = Profile.new(params[:profile].permit(:nickname, :profile_text))
      @profile.domain_name = @openid_url.domain_name
      @profile.screen_name = @openid_url.screen_name
      
      if @profile.save
        @openid_url.update_attributes(:primary_openid => true, :profile_id => @profile.id)
        session[:login_profile_id] = @profile.id
        deliver_to_service(@service, @profile)
      else
        redirect_to :action => :new, :service_id => @service.id
      end
    end
  end

  # PATCH/PUT /profiles/1
  # PATCH/PUT /profiles/1.json
  def update
    respond_to do |format|
      @login_profile.update(params[:profile].permit(:nickname, :profile_text))
      @login_profile.profile_services.each do |profile_service|
        profile_service.service.notice(@login_profile)
      end
      
      format.html { render :text => 'true' }
    end
  end
  
  def authenticate
    # セッションの再生成
    temp = session.to_hash
    old_flash = flash.to_hash
    reset_session
    temp.each do |key, value|
      session[key] = value
    end
    
    begin
      @service = Service.find(params[:id])
      # 署名検証
      begin
        @service.validate_authenticate_request(params)
        if @login_profile.present?
          # ログイン済みなのでサービスに戻す
          deliver_to_service(@service, @login_profile)
        end
      rescue Service::InvalidSignatureError
        forbidden
      end
      
      # ログアウト状態なので認証サービスの選択を求める
    rescue ActiveRecord::RecordNotFound
      @service = Service.find(old_flash[:service_id]) if old_flash[:service_id].present?
    end
  end
  
  def logout
    session[:openid_url_id] = nil
    session[:last_login] = nil
    session[:login_profile_id] = nil
    
    @service = Service.find(params[:id])
    redirect_to @service.root
  end
end
