class AuthTicketsController < ApplicationController
  before_action :set_auth_ticket, only: [:show, :edit, :update, :destroy]

  # GET /auth_tickets
  # GET /auth_tickets.json
  def index
    @auth_tickets = AuthTicket.all
  end

  # GET /auth_tickets/1
  # GET /auth_tickets/1.json
  def show
  end

  # GET /auth_tickets/new
  def new
    @auth_ticket = AuthTicket.new
  end

  # GET /auth_tickets/1/edit
  def edit
  end

  # POST /auth_tickets
  # POST /auth_tickets.json
  def create
    @auth_ticket = AuthTicket.new(auth_ticket_params)

    respond_to do |format|
      if @auth_ticket.save
        format.html { redirect_to @auth_ticket, notice: 'Auth ticket was successfully created.' }
        format.json { render action: 'show', status: :created, location: @auth_ticket }
      else
        format.html { render action: 'new' }
        format.json { render json: @auth_ticket.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /auth_tickets/1
  # PATCH/PUT /auth_tickets/1.json
  def update
    respond_to do |format|
      if @auth_ticket.update(auth_ticket_params)
        format.html { redirect_to @auth_ticket, notice: 'Auth ticket was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @auth_ticket.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /auth_tickets/1
  # DELETE /auth_tickets/1.json
  def destroy
    @auth_ticket.destroy
    respond_to do |format|
      format.html { redirect_to auth_tickets_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_auth_ticket
      @auth_ticket = AuthTicket.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def auth_ticket_params
      params[:auth_ticket]
    end
end
