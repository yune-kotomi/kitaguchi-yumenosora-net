require "uuidtools"
class AuthTicket < ActiveRecord::Base
  belongs_to :profile
  belongs_to :service

  before_save :key_generate
  
  private
  def key_generate
    self.key = UUIDTools::UUID.random_create.to_s
  end
end

