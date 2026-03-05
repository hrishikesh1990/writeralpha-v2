class CreateColors < ActiveRecord::Migration[8.1]
  def change
    create_table :colors do |t|
      t.string :name
      t.string :slug
      t.string :hex_code

      t.timestamps
    end
  end
end
