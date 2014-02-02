require "pathname"
require "cgi"
require 'uri'

require "openid"
require 'openid/extensions/sreg'
require 'openid/extensions/pape'
require 'openid/store/filesystem'

require 'hatena/api/auth'

class OpenidUrlsController < ApplicationController
  before_filter :login_required, :only => [:destroy]
  
  def login
    begin
      openid_url = params[:openid_url].gsub("#", "%23")
      request = consumer.begin(openid_url)
      trust_root = root_path(:only_path => false)
      return_to = url_for(:action=> 'complete', :service_id => params[:service_id])

      url = request.redirect_url(trust_root, return_to)
      redirect_to(url)
      
      flash[:auth_mode] = params[:mode]
      
    rescue OpenID::OpenIDError, OpenID::DiscoveryFailure
      flash[:notice] = "認証に失敗しました"
      redirect_to profile_authenticate_path
    end
  end
  
  def complete
    current_url = url_for(:only_path => false, :service_id => params[:service_id])
    parameters = params.reject{ |k,v| request.path_parameters[k] or request.path_parameters[k.to_sym] }
    parameters.delete(:service_id)
    response = consumer.complete(parameters, current_url)

    begin
      @service = Service.find(params[:service_id])
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end
    
    case response.status
    when OpenID::Consumer::SUCCESS
      identity_retrieved_after(response.identity_url)
      
    else
      if @service.present?
        redirect_to @service.auth_fail
      else
        flash[:notice] = "認証できませんでした。"
        redirect_to :controller => :profiles, :action => :authenticate
      end
    end
  end
  
  # DELETE /openid_urls/1
  # DELETE /openid_urls/1.json
  def destroy
    @openid_url = OpenidUrl.find(params[:id])
    
    if @login_profile == @openid_url.profile
      @openid_url.destroy unless @openid_url.primary_openid
      
      respond_to do |format|
        format.html { redirect_to profile_path }
      end
    else
      forbidden
    end
  end
  
  def hatena_authenticate
    flash[:hatena_after_service_id] = params[:service_id]
    flash[:auth_mode] = params[:mode]
    redirect_to hatena.uri_to_login.to_s
  end
  
  def hatena_complete
    @service = Service.where(:id => flash[:hatena_after_service_id]).first
    
    begin
      user_info = hatena.login(params[:cert])
      openid_url = "http://www.hatena.ne.jp/#{user_info['name']}/"
      identity_retrieved_after(openid_url)

    rescue Hatena::API::AuthError
      if @service.present?
        redirect_to @service.auth_fail
      else
        flash[:notice] = "認証できませんでした。"
        redirect_to :controller => :profiles, :action => :authenticate
      end
    end
  end

  private
  # OpenID::Consumerオブジェクトを取得
  def consumer
    if @consumer.nil?
      dir = "#{::Rails.root.to_s}/tmp/"
      store = OpenID::Store::Filesystem.new(dir)
      @consumer = OpenID::Consumer.new(session, store)
    end
    
    return @consumer
  end
  
  def hatena
    Hatena::API::Auth.new(
      :api_key => Hotarugaike::Application.config.hatenaapiauth_key,
      :secret => Hotarugaike::Application.config.hatenaapiauth_secret
    )
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
