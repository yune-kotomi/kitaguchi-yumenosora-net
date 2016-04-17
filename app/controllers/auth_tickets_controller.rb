class AuthTicketsController < ApplicationController
  layout false
  def show
    @service = Service.find(params[:id])
    payload = JWT.decode(params[:token], @service.key).first
    if payload['exp'].present?
      @auth_ticket = AuthTicket.where(:key => payload['key']).first
      if @auth_ticket.present?
        @auth_ticket.destroy
      else
        render :json => {:status => 'Not Found'}, :status => 404
      end
    else
      forbidden
    end
  rescue JWT::VerificationError
    forbidden
  end
end
