class CreateBirthMonths < ActiveRecord::Migration[8.1]
  def change
    create_table :birth_months do |t|
      t.integer :month_number
      t.string :name

      t.timestamps
    end
  end
end
