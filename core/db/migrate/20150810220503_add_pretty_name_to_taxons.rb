class AddPrettyNameToTaxons < ActiveRecord::Migration
  def change
    add_column :spree_taxons, :pretty_name, :string, default: '', null: false

    Spree::Taxon.each do |taxon|
      taxon.pretty_name = generate_pretty_name(taxon)
      taxon.save
    end
  end

  def generate_pretty_name(taxon)
    pretty_name = taxons.ancestors.inject("") do |name, ancestor|
      name += "#{ancestor.name} -> "
    end
    pretty_name += "#{name}"
  end
end
