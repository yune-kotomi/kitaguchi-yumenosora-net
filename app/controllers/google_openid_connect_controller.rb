require 'openid-connect'

class GoogleOpenidConnectController < ApplicationController
  def authenticate
    flash[:openid_connect_after_service_id] = params[:service_id]
    flash[:auth_mode] = params[:mode]

    oc = OpenIDConnect.new(session, openid_connect_callback_url)
    redirect_to oc.authentication_url('openid', root_url)
  end

  def complete
    @service = Service.where(:id => flash[:openid_connect_after_service_id]).first

    oc = OpenIDConnect.new(session, openid_connect_callback_url)

    @result = oc.authentication_result(params)
    @payload = oc.parse_id_token(@result)
    openid_url = @payload['openid_id']

    identity_retrieved_after(openid_url)

  rescue OpenIDConnect::CancelError, OpenIDConnect::InvalidTokenError, OpenIDConnect::ExchangeError, OpenIDConnect::IdTokenError => e
    if @service.present?
      redirect_to @service.authenticate_failure
    else
      flash[:notice] = "認証できませんでした。"
      redirect_to :controller => :profiles, :action => :authenticate
    end
  end
end
