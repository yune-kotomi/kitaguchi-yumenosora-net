class AuthTicketsController < ApplicationController
  layout false
  def show
    @auth_ticket = AuthTicket.
      where(:key => params[:key]).
      where(AuthTicket.arel_table[:created_at].gt(5.minutes.ago)).first
    
    if @auth_ticket.present?
      begin
        @auth_ticket.validate_retrieve_request(params)
        @auth_ticket.destroy
      rescue AuthTicket::InvalidSignatureError
        forbidden
      end
    else
      render :json => {:status => 'Not Found'}, :status => 404
    end
  end
end
