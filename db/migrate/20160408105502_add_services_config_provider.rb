class AddServicesConfigProvider < ActiveRecord::Migration[4.2]
  def change
    add_column :services, :config_provider, :string
  end
end
