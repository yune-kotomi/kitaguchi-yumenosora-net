require 'test_helper'

class AuthTicketTest < ActiveSupport::TestCase
  test "保存時にキーを発行する" do
    ticket = AuthTicket.new
    ticket.save
    assert ticket.key.present?
  end
end
