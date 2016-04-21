module ProfilesHelper
  def back_from_profile(service, profile)
    service.user_page_url.
      gsub('PROFILE_ID', profile.id.to_s).
      gsub('DOMAIN_NAME', profile.domain_name).
      gsub('SCREEN_NAME', profile.screen_name)
  end

  def openid_label(url)
    u = URI(url)

    case u.host
    when 'www.hatena.ne.jp'
      'はてなID'
    when 'profile.livedoor.com'
      'livedoor ID'
    when 'id.mixi.jp'
      'mixi OpenID'
    when 'www.google.com'
      'Googleアカウント'
    when 'me.yahoo.co.jp'
      'Yahoo! JAPAN ID'
    else
      url
    end
  end
end
