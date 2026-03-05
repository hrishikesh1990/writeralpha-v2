class CreateGemstoneHealingPowers < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstone_healing_powers do |t|
      t.references :gemstone, null: false, foreign_key: true
      t.references :healing_power, null: false, foreign_key: true

      t.timestamps
    end
  end
end
