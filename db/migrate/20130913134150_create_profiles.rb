class CreateProfiles < ActiveRecord::Migration
  def change
    create_table :profiles do |t|
      t.string   "domain_name"
      t.string   "screen_name"
      t.string   "long_name"
      t.string   "nickname"
      t.text     "profile_text"

      t.timestamps
    end
    
    add_index "profiles", ["long_name"], :name => "index_profiles_on_long_name", :unique => true
  end
end
