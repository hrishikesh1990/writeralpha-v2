namespace :images do
  desc "Rewrite content/featured image references to the WebP versions listed in db/wordpress_data/webp_manifest.json"
  task webp: :environment do
    manifest = JSON.parse(File.read(Rails.root.join("db/wordpress_data/webp_manifest.json")))
    mapping = manifest.transform_values { |v| v["webp"] }
    pattern = Regexp.union(mapping.keys.sort_by { |k| -k.length })

    rewrite = ->(text) { text.to_s.gsub(pattern) { |m| mapping.fetch(m, m) } }

    gemstone_fields = %w[description meaning_content water_safety_content who_should_not_wear_content sleeping_with_content
                         how_to_identify_content how_to_cleanse_content combinations_content affirmations_content price_guide_content
                         benefits_content properties_content chakra_content uses_content zodiac_content]
    changed = 0
    Gemstone.find_each do |gem|
      updates = {}
      gemstone_fields.each do |f|
        v = gem[f]
        next if v.blank?
        nv = rewrite.call(v)
        updates[f] = nv if nv != v
      end
      if gem.featured_image_url.present? && mapping[gem.featured_image_url]
        updates["featured_image_url"] = mapping[gem.featured_image_url]
      end
      next if updates.empty?
      gem.update_columns(updates)
      changed += 1
    end
    Article.find_each do |a|
      updates = {}
      nv = rewrite.call(a.content)
      updates["content"] = nv if a.content.present? && nv != a.content
      updates["featured_image_url"] = mapping[a.featured_image_url] if a.featured_image_url.present? && mapping[a.featured_image_url]
      next if updates.empty?
      a.update_columns(updates)
      changed += 1
    end
    puts "Rewrote image references on #{changed} records (#{mapping.size} images in manifest)."
  end
end
