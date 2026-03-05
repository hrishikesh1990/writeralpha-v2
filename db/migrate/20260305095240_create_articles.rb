class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :slug
      t.text :content
      t.text :excerpt
      t.references :category, null: false, foreign_key: true
      t.string :featured_image_url
      t.string :meta_title
      t.text :meta_description
      t.boolean :published
      t.datetime :published_at

      t.timestamps
    end
  end
end
