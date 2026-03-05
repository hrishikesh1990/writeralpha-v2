# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_05_095319) do
  create_table "articles", force: :cascade do |t|
    t.integer "category_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.string "featured_image_url"
    t.text "meta_description"
    t.string "meta_title"
    t.boolean "published"
    t.datetime "published_at"
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "birth_months", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "month_number"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "colors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hex_code"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_colors_on_slug", unique: true
  end

  create_table "cuts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "gemstone_colors", force: :cascade do |t|
    t.integer "color_id", null: false
    t.datetime "created_at", null: false
    t.integer "gemstone_id", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_gemstone_colors_on_color_id"
    t.index ["gemstone_id"], name: "index_gemstone_colors_on_gemstone_id"
  end

  create_table "gemstone_cuts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "cut_id", null: false
    t.integer "gemstone_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cut_id"], name: "index_gemstone_cuts_on_cut_id"
    t.index ["gemstone_id"], name: "index_gemstone_cuts_on_gemstone_id"
  end

  create_table "gemstone_healing_powers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gemstone_id", null: false
    t.integer "healing_power_id", null: false
    t.datetime "updated_at", null: false
    t.index ["gemstone_id"], name: "index_gemstone_healing_powers_on_gemstone_id"
    t.index ["healing_power_id"], name: "index_gemstone_healing_powers_on_healing_power_id"
  end

  create_table "gemstone_shapes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gemstone_id", null: false
    t.integer "shape_id", null: false
    t.datetime "updated_at", null: false
    t.index ["gemstone_id"], name: "index_gemstone_shapes_on_gemstone_id"
    t.index ["shape_id"], name: "index_gemstone_shapes_on_shape_id"
  end

  create_table "gemstone_zodiac_signs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gemstone_id", null: false
    t.datetime "updated_at", null: false
    t.integer "zodiac_sign_id", null: false
    t.index ["gemstone_id"], name: "index_gemstone_zodiac_signs_on_gemstone_id"
    t.index ["zodiac_sign_id"], name: "index_gemstone_zodiac_signs_on_zodiac_sign_id"
  end

  create_table "gemstones", force: :cascade do |t|
    t.text "affirmations_content"
    t.text "benefits_content"
    t.integer "birth_month_id"
    t.text "chakra_content"
    t.string "chemical_formula"
    t.text "combinations_content"
    t.datetime "created_at", null: false
    t.string "crystal_system"
    t.text "description"
    t.string "element"
    t.string "featured_image_url"
    t.text "how_to_cleanse_content"
    t.text "how_to_identify_content"
    t.integer "lustre_id"
    t.text "meaning_content"
    t.text "meta_description"
    t.string "meta_title"
    t.float "mohs_hardness"
    t.string "name"
    t.text "price_guide_content"
    t.text "properties_content"
    t.boolean "published"
    t.string "ruling_planet"
    t.text "sleeping_with_content"
    t.string "slug"
    t.string "subtitle"
    t.integer "transparency_id"
    t.datetime "updated_at", null: false
    t.text "uses_content"
    t.text "water_safety_content"
    t.text "who_should_not_wear_content"
    t.text "zodiac_content"
    t.index ["birth_month_id"], name: "index_gemstones_on_birth_month_id"
    t.index ["lustre_id"], name: "index_gemstones_on_lustre_id"
    t.index ["published"], name: "index_gemstones_on_published"
    t.index ["slug"], name: "index_gemstones_on_slug", unique: true
    t.index ["transparency_id"], name: "index_gemstones_on_transparency_id"
  end

  create_table "healing_powers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "lustres", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "new_path"
    t.string "old_path"
    t.integer "status_code"
    t.datetime "updated_at", null: false
    t.index ["old_path"], name: "index_redirects_on_old_path", unique: true
  end

  create_table "shapes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "transparencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "zodiac_signs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_range"
    t.string "element"
    t.string "name"
    t.string "slug"
    t.string "symbol"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "articles", "categories"
  add_foreign_key "gemstone_colors", "colors"
  add_foreign_key "gemstone_colors", "gemstones"
  add_foreign_key "gemstone_cuts", "cuts"
  add_foreign_key "gemstone_cuts", "gemstones"
  add_foreign_key "gemstone_healing_powers", "gemstones"
  add_foreign_key "gemstone_healing_powers", "healing_powers"
  add_foreign_key "gemstone_shapes", "gemstones"
  add_foreign_key "gemstone_shapes", "shapes"
  add_foreign_key "gemstone_zodiac_signs", "gemstones"
  add_foreign_key "gemstone_zodiac_signs", "zodiac_signs"
  add_foreign_key "gemstones", "birth_months"
  add_foreign_key "gemstones", "lustres"
  add_foreign_key "gemstones", "transparencies"
end
