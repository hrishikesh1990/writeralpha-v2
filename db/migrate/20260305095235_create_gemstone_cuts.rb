class CreateGemstoneCuts < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstone_cuts do |t|
      t.references :gemstone, null: false, foreign_key: true
      t.references :cut, null: false, foreign_key: true

      t.timestamps
    end
  end
end
