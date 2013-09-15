class OpenidUrl < ActiveRecord::Base
  belongs_to :profile

  def domain_name
    return URI(self.str).host
  end
end

