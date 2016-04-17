class AuthTicket < ActiveRecord::Base
  belongs_to :profile
  belongs_to :service

  before_save :key_generate

  private
  def key_generate
    self.key = SecureRandom.base64(50)
  end
end
