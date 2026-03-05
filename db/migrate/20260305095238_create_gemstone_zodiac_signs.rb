class CreateGemstoneZodiacSigns < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstone_zodiac_signs do |t|
      t.references :gemstone, null: false, foreign_key: true
      t.references :zodiac_sign, null: false, foreign_key: true

      t.timestamps
    end
  end
end
