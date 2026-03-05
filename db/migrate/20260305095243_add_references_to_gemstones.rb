class AddReferencesToGemstones < ActiveRecord::Migration[8.1]
  def change
    add_reference :gemstones, :transparency, null: true, foreign_key: true
    add_reference :gemstones, :lustre, null: true, foreign_key: true
    add_reference :gemstones, :birth_month, null: true, foreign_key: true
  end
end
