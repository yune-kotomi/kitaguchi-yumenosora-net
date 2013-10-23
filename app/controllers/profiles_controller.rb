class ProfilesController < ApplicationController
  before_filter :login_required, :only => [:show, :update]

  # GET /profiles/1
  # GET /profiles/1.json
  def show
  end
  
  def new
  
  end
  
  def create
    @service = Service.find(params[:service_id])
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
      
      case params[:back_to]
      when 'success'
        @service = Service.find(params[:service_id])
        back_path = @service.auth_success
      when 'updated'
        @service = Service.find(params[:service_id])
        back_path = @service.back_from_profile
      else
        back_path = profile_path
      end
      
      format.html { redirect_to back_path }
    end
  end
  
  def authenticate
    begin
      @service = Service.find(params[:id])
      # 署名検証
      begin
        @service.validate_params(params)
        
        if @login_profile.present?
          # ログイン済みなのでサービスに戻す
          deliver_to_service(@service, @login_profile)
        end
      rescue Service::SignatureInvalidError, Service::RequestTooOldError
        forbidden
      end
      
      # ログアウト状態なので認証サービスの選択を求める
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end
  end
end
