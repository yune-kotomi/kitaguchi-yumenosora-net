class CreateAuthTickets < ActiveRecord::Migration[4.2]
  def change
    create_table :auth_tickets do |t|
      t.integer  "profile_id"
      t.integer  "service_id"
      t.string   "key"

      t.timestamps
    end
  end
end
