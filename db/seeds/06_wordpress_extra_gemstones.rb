# Gemstones that exist in the WordPress export (db/wordpress_data/
# transformed_gemstones.json, 86 stones) but were never seeded by db/seeds.rb
# (36 curated stones). They are the destinations of ~60 legacy redirects in
# 05_redirects.rb, so without them those URLs 301 into a 404.
#
# New stones are created published but UNLISTED (thin metadata: no colors,
# healing powers, zodiac or photo). Content fields are filled only when blank,
# so re-running this on production never overwrites the HTML content that was
# synced there. Run `bin/rails content:convert` afterwards to turn the plain
# WordPress text into HTML with <h2> sections.
puts "=== Importing extra WordPress gemstones (unlisted) ==="

require "json"

data = JSON.parse(File.read(Rails.root.join("db/wordpress_data/transformed_gemstones.json")))

# WordPress key => gemstone slug, where the planned URL differs from the key.
ALIASES = {
  "tigers-eye" => "tiger-eye",
  "green-aventurine" => "aventurine",
  "what-is-botswana-agate-everything-you-need-to-know-about-botswana-agate" => "botswana-agate"
}.freeze

# Keys that are not gemstones (handled as articles below).
ARTICLE_KEYS = %w[tree-agate-vs-moss-agate].freeze

# Display names that plain titleizing gets wrong.
NAMES = {
  "cats-eye" => "Cat's Eye",
  "tigers-eye" => "Tiger's Eye",
  "blue-tigers-eye" => "Blue Tiger's Eye",
  "red-tigers-eye" => "Red Tiger's Eye",
  "tortoise-ring" => "Tortoise Ring",
  "jade-crystal" => "Jade Crystal",
  "hematite-rings" => "Hematite Rings"
}.freeze

CONTENT_FIELDS = %w[meaning_content water_safety_content who_should_not_wear_content sleeping_with_content].freeze

# Featured photos that exist in public/images/posts (and on Tigris) for the
# imported stones. The original WordPress uploads for the rest were never
# rehosted, so they keep the gradient placeholder.
FEATURED_IMAGES = {
  "ruby-zoisite" => "/images/posts/ruby-zoisite-meaning.jpeg",
  "larvikite" => "/images/posts/larvikite-vs-labradorite.png"
}.freeze

created = 0
updated = 0

data.each do |key, attrs|
  next if ARTICLE_KEYS.include?(key)

  slug = ALIASES.fetch(key, key)
  gem = Gemstone.find_or_initialize_by(slug: slug)
  changed = false

  if gem.new_record?
    gem.name = NAMES.fetch(slug, slug.tr("-", " ").titleize)
    gem.meta_title = attrs["title"].presence
    gem.description = attrs["description"].presence
    gem.published = true
    gem.listed = false
    changed = true
  end

  CONTENT_FIELDS.each do |field|
    value = attrs[field].to_s.strip
    next if value.blank? || gem.send(field).present?

    gem.send("#{field}=", value)
    changed = true
  end

  if gem.featured_image_url.blank? && FEATURED_IMAGES[slug]
    gem.featured_image_url = FEATURED_IMAGES[slug]
    changed = true
  end

  next unless changed

  if gem.new_record?
    created += 1
    puts "  Created (unlisted): #{slug}"
  else
    updated += 1
    puts "  Filled blank content: #{slug} (from #{key})"
  end
  gem.save!
end

# Comparison article that WordPress filed under gemstones.
if (cmp = data["tree-agate-vs-moss-agate"])
  cat = Category.find_or_create_by!(slug: "comparisons") { |c| c.name = "Comparisons" }
  article = Article.find_or_initialize_by(slug: "tree-agate-vs-moss-agate")
  if article.new_record?
    article.title = cmp["title"].presence || "Tree Agate vs Moss Agate: What are the differences"
    article.excerpt = cmp["description"].presence
    article.content = cmp["meaning_content"]
    article.category = cat
    article.published = true
    article.published_at = Time.zone.parse("2023-01-01")
    article.save!
    puts "  Created article: tree-agate-vs-moss-agate"
  end
end

puts "  #{created} gemstones created, #{updated} existing gemstones back-filled; #{Gemstone.count} total (#{Gemstone.published.listed.count} listed)"
