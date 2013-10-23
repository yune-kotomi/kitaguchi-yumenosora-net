require 'test_helper'

class OpenidUrlTest < ActiveSupport::TestCase
  setup do
    @profile_one_primary = openid_urls(:profile_one_primary)
  end
  
  test "ドメイン名を返す" do
    assert_equal URI(@profile_one_primary.str).host, @profile_one_primary.domain_name
  end
  
  test "一般ドメインのOpenIDの場合はidentifierのMD5をスクリーン名(候補)として返す" do
    assert_equal Digest::MD5.hexdigest(@profile_one_primary.str), @profile_one_primary.screen_name
  end
  
  test "はてなIDの場合はユーザ名をスクリーン名候補として返す" do
    assert_equal 'user', openid_urls(:hatena_id).screen_name
  end
  
  test "ライブドアIDの場合はユーザ名をスクリーン名候補として返す" do
    assert_equal 'user', openid_urls(:livedoor_id).screen_name
  end
end
