class AddPrettyNameToTaxons < ActiveRecord::Migration
  def change
    add_column :spree_taxons, :pretty_name, :string, default: '', null: false
  end
end
