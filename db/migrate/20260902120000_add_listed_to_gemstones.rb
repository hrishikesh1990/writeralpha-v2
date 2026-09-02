class AddListedToGemstones < ActiveRecord::Migration[8.1]
  def change
    # Listed = shown in the directory/home/filters. Thin WordPress imports are
    # published (reachable by URL, in the sitemap) but unlisted.
    add_column :gemstones, :listed, :boolean, default: true, null: false
    add_index :gemstones, [:published, :listed]
  end
end
