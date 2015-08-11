class AddPrettyNameToTaxons < ActiveRecord::Migration
  def change
    add_column :spree_taxons, :pretty_name, :string, default: '', null: false

    Spree::Taxon.all.each do |taxon|
      taxon.update_column(:pretty_name, generate_pretty_name(taxon))
    end
  end

  def generate_pretty_name(taxon)
    pretty_name = taxon.ancestors.inject("") do |name, ancestor|
      name += "#{ancestor.name} -> "
    end
    pretty_name += "#{taxon.name}"
  end
end
