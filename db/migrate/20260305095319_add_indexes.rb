class AddIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :categories, :parent_id unless index_exists?(:categories, :parent_id)
    add_index :redirects, :old_path, unique: true unless index_exists?(:redirects, :old_path)
    add_index :gemstones, :slug, unique: true unless index_exists?(:gemstones, :slug)
    add_index :gemstones, :published unless index_exists?(:gemstones, :published)
    add_index :articles, :slug, unique: true unless index_exists?(:articles, :slug)
    add_index :colors, :slug, unique: true unless index_exists?(:colors, :slug)
    add_index :categories, :slug, unique: true unless index_exists?(:categories, :slug)
  end
end
