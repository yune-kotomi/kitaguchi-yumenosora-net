class OpenidUrlsController < ApplicationController
  before_action :set_openid_url, only: [:show, :edit, :update, :destroy]

  # GET /openid_urls
  # GET /openid_urls.json
  def index
    @openid_urls = OpenidUrl.all
  end

  # GET /openid_urls/1
  # GET /openid_urls/1.json
  def show
  end

  # GET /openid_urls/new
  def new
    @openid_url = OpenidUrl.new
  end

  # GET /openid_urls/1/edit
  def edit
  end

  # POST /openid_urls
  # POST /openid_urls.json
  def create
    @openid_url = OpenidUrl.new(openid_url_params)

    respond_to do |format|
      if @openid_url.save
        format.html { redirect_to @openid_url, notice: 'Openid url was successfully created.' }
        format.json { render action: 'show', status: :created, location: @openid_url }
      else
        format.html { render action: 'new' }
        format.json { render json: @openid_url.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /openid_urls/1
  # PATCH/PUT /openid_urls/1.json
  def update
    respond_to do |format|
      if @openid_url.update(openid_url_params)
        format.html { redirect_to @openid_url, notice: 'Openid url was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @openid_url.errors, status: :unprocessable_entity }
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_openid_url
      @openid_url = OpenidUrl.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def openid_url_params
      params[:openid_url]
    end
end
