class AddOpenidUrlsProfileImage < ActiveRecord::Migration
  def change
    add_column :openid_urls, :profile_image, :string
  end
end
