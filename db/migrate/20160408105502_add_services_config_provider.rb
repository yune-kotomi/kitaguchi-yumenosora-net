class AddServicesConfigProvider < ActiveRecord::Migration
  def change
    add_column :services, :config_provider, :string
  end
end
