class OpenidUrl < ActiveRecord::Base
  belongs_to :profile

  def domain_name
    return URI(self.str).host
  end
  
  def screen_name
    case domain_name
    when 'www.hatena.ne.jp', 'profile.livedoor.com'
      URI(self.str).path.gsub('/', '')
    else
      Digest::MD5.hexdigest(self.str)
    end
  end
end

