class CreateGemstones < ActiveRecord::Migration[8.1]
  def change
    create_table :gemstones do |t|
      t.string :name
      t.string :slug
      t.string :subtitle
      t.text :description
      t.text :meaning_content
      t.text :properties_content
      t.text :benefits_content
      t.text :uses_content
      t.text :water_safety_content
      t.text :who_should_not_wear_content
      t.text :sleeping_with_content
      t.text :how_to_identify_content
      t.text :how_to_cleanse_content
      t.text :combinations_content
      t.text :affirmations_content
      t.text :price_guide_content
      t.text :zodiac_content
      t.text :chakra_content
      t.float :mohs_hardness
      t.string :chemical_formula
      t.string :crystal_system
      t.string :element
      t.string :ruling_planet
      t.string :featured_image_url
      t.string :meta_title
      t.text :meta_description
      t.boolean :published

      t.timestamps
    end
  end
end
