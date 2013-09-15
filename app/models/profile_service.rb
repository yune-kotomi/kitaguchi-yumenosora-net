class ProfileService < ActiveRecord::Base
  belongs_to :profile
  belongs_to :service
end
