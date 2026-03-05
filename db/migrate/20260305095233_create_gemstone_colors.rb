class CreateGemstoneColors < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstone_colors do |t|
      t.references :gemstone, null: false, foreign_key: true
      t.references :color, null: false, foreign_key: true

      t.timestamps
    end
  end
end
