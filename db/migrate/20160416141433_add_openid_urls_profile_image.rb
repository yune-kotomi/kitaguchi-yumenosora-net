class AddOpenidUrlsProfileImage < ActiveRecord::Migration[4.2]
  def change
    add_column :openid_urls, :profile_image, :string
  end
end
