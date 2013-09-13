class CreateAuthTickets < ActiveRecord::Migration
  def change
    create_table :auth_tickets do |t|
      t.integer  "profile_id"
      t.integer  "service_id"
      t.string   "key"

      t.timestamps
    end
  end
end
