class HatenaController < ApplicationController
  def authenticate
    flash[:hatena_after_service_id] = params[:service_id]
    flash[:auth_mode] = params[:mode]
    redirect_to hatena.uri_to_login.to_s
  end

  def complete
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
  def hatena
    Hatena::API::Auth.new(
      :api_key => Hotarugaike::Application.config.hatenaapiauth_key,
      :secret => Hotarugaike::Application.config.hatenaapiauth_secret
    )
  end
end
