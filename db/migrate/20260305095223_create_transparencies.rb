class CreateTransparencies < ActiveRecord::Migration[8.1]
  def change
    create_table :transparencies do |t|
      t.string :name
      t.string :slug
      t.text :description

      t.timestamps
    end
  end
end
