require 'test_helper'

class ProfileTest < ActiveSupport::TestCase
  setup do
    @one = profiles :one
  end
  
  test "プライマリなOpenIDを返す" do
    assert_equal openid_urls(:profile_one_primary), @one.primary_openid
  end
  
  test "プロフィール文をはてな記法展開して返す" do
    assert_equal "<div class=\"section\">\n\t<p>一人目のプロフィール文</p>\n</div>", @one.profile_html
  end
end

