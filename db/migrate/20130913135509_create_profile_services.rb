class CreateProfileServices < ActiveRecord::Migration[4.2]
  def change
    create_table :profile_services do |t|
      t.integer  "profile_id"
      t.integer  "service_id"

      t.timestamps
    end
  end
end
