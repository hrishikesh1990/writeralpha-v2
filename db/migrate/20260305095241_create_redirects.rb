class CreateRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :redirects do |t|
      t.string :old_path
      t.string :new_path
      t.integer :status_code

      t.timestamps
    end
  end
end
