module ProfilesHelper
  def back_from_profile(service, profile)
    service.back_from_profile.
      gsub('PROFILE_ID', profile.id.to_s).
      gsub('DOMAIN_NAME', profile.domain_name).
      gsub('SCREEN_NAME', profile.screen_name)
  end
end
