class ChangeSubPageMetaToText < ActiveRecord::Migration[8.1]
  # Postgres has no equality operator for `json`, so any DISTINCT over
  # gemstones.* (directory and filter pages) failed with the json column.
  # Store the hash as JSON text instead (serialized in the model).
  def up
    if connection.adapter_name =~ /postgres/i
      execute "ALTER TABLE gemstones ALTER COLUMN sub_page_meta TYPE text USING sub_page_meta::text"
    else
      change_column :gemstones, :sub_page_meta, :text
    end
  end

  def down
    if connection.adapter_name =~ /postgres/i
      execute "ALTER TABLE gemstones ALTER COLUMN sub_page_meta TYPE json USING sub_page_meta::json"
    else
      change_column :gemstones, :sub_page_meta, :json
    end
  end
end
