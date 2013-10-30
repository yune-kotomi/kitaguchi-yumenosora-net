require "pathname"
require "cgi"
require 'uri'

require "openid"
require 'openid/extensions/sreg'
require 'openid/extensions/pape'
require 'openid/store/filesystem'

require 'hatena/api/auth'

class OpenidUrlsController < ApplicationController
  before_action :set_openid_url, only: [:show, :edit, :update, :destroy]

  def login
    begin
      openid_url = params[:openid_url].gsub("#", "%23")
      request = consumer.begin(openid_url)
      trust_root = root_path(:only_path => false)
      return_to = url_for(:action=> 'complete', :service_id => params[:service_id])

      url = request.redirect_url(trust_root, return_to)
      redirect_to(url)
      
    rescue OpenID::OpenIDError
      flash[:notice] = "認証に失敗しました"
    
    end
  end
  
  def complete
    current_url = url_for(:only_path => false, :service_id => params[:service_id])
    parameters = params.reject{ |k,v| request.path_parameters[k.to_sym] }
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
    @openid_url.destroy
    respond_to do |format|
      format.html { redirect_to openid_urls_url }
      format.json { head :no_content }
    end
  end
  
  def hatena_authenticate
    flash[:hatena_after_service_id] = params[:service_id]
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
    
    if @service.blank?
      begin
        previous_openid_url = OpenidUrl.find(session[:openid_url_id])
        if previous_openid_url != @openid_url and 
          Time.at(session[:last_login]) > 5.minutes.ago and
          previous_openid_url.profile.present? and
          @openid_url.profile.blank?
          # サービスが指定されておらず、前回ログインから5分以内で別のOpenIDにて認証されたら追加登録
          @openid_url.update_attribute(:profile_id, previous_openid_url.profile.id)
          
          session[:openid_url_id] = @openid_url.id
          session[:last_login] = Time.now.to_i
          session[:login_profile_id] = @openid_url.profile.id
          redirect_to :controller => :profiles, :action => :show
          return
        end
      rescue ActiveRecord::RecordNotFound
        # do nothing
      end
      
      if @openid_url.profile.blank?
        redirect_to :controller => :profiles, :action => :new
      else
        session[:openid_url_id] = @openid_url.id
        session[:last_login] = Time.now.to_i
        session[:login_profile_id] = @openid_url.profile.id
        redirect_to :controller => :profiles, :action => :show
      end
    else
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
