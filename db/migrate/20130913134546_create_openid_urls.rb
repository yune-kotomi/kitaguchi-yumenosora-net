class CreateOpenidUrls < ActiveRecord::Migration
  def change
    create_table :openid_urls do |t|
      t.string   "str"
      t.integer  "profile_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "primary_openid"

      t.timestamps
    end

    create_table "open_id_associations", :force => true do |t|
      t.binary  "server_url"
      t.string  "handle"
      t.binary  "secret"
      t.integer "issued"
      t.integer "lifetime"
      t.string  "assoc_type"
    end

    create_table "open_id_nonces", :force => true do |t|
      t.string  "server_url", :null => false
      t.integer "timestamp",  :null => false
      t.string  "salt",       :null => false
    end
  end
end
