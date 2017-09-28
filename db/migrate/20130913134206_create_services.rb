class CreateServices < ActiveRecord::Migration[4.2]
  def change
    create_table :services do |t|
      t.string   "title"
      t.string   "logo"
      t.string   "banner"
      t.string   "root"
      t.string   "auth_success"
      t.string   "auth_fail"
      t.string   "profile_update"
      t.string   "back_from_profile"
      t.string   "key"

      t.timestamps
    end
  end
end
