require 'test_helper'

class OpenidUrlTest < ActiveSupport::TestCase
  setup do
    @profile_one_primary = openid_urls(:profile_one_primary)
  end
  
  test "ドメイン名を返す" do
    assert_equal URI(@profile_one_primary.str).host, @profile_one_primary.domain_name
  end
end
