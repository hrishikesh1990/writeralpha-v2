class CreateZodiacSigns < ActiveRecord::Migration[8.1]
  def change
    create_table :zodiac_signs do |t|
      t.string :name
      t.string :slug
      t.string :symbol
      t.string :date_range
      t.string :element

      t.timestamps
    end
  end
end
