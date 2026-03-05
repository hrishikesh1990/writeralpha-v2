class CreateGemstoneShapes < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstone_shapes do |t|
      t.references :gemstone, null: false, foreign_key: true
      t.references :shape, null: false, foreign_key: true

      t.timestamps
    end
  end
end
