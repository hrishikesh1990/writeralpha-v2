class AddSubPageMetaToGemstones < ActiveRecord::Migration[8.1]
  def change
    # Per-sub-page title / meta_title / meta_description keyed by sub-page
    # path (see Gemstone#sub_page_meta_for). Written by sro:import.
    add_column :gemstones, :sub_page_meta, :json
  end
end
