# frozen_string_literal: true

# View helpers for the "at a glance" Atlas panel on gemstone hubs
# (app/views/tools/atlas/_hub_panel.html.erb). Everything reads the Atlas;
# nothing here invents facts.
module AtlasPanelHelper
  CARE_ROWS = [
    { key: "water", label: "Water", icon: "💧", ld: "Water safety" },
    { key: "salt", label: "Salt", icon: "🧂", ld: "Salt safety" },
    { key: "sun", label: "Sunlight", icon: "☀️", ld: "Sunlight safety" },
    { key: "sleep", label: "Sleeping with it", icon: "🌙", ld: "Sleeping-with safety" },
    { key: "wear", label: "Wearing it", icon: "💍", ld: "Wearability" }
  ].freeze

  LANG_NAMES = {
    "hi" => "Hindi", "bn" => "Bengali", "es" => "Spanish", "ta" => "Tamil", "te" => "Telugu", "mr" => "Marathi"
  }.freeze

  CHAKRA_COLORS = {
    "root" => "#e5484d", "sacral" => "#f08a3c", "solar_plexus" => "#e9c13a", "heart" => "#4fae7b",
    "throat" => "#4f8fdd", "third_eye" => "#5b57c9", "crown" => "#a779ec"
  }.freeze

  PRICE_LABELS = { "budget" => "Budget", "mid" => "Mid-range", "premium" => "Premium", "luxury" => "Luxury" }.freeze

  # Friendly, honest label for the Atlas `kind`.
  def atlas_kind_label(stone)
    species = stone.species.to_s
    case stone.kind
    when "mineral" then "Mineral"
    when "variety" then species.present? ? "#{species} variety" : "Mineral variety"
    when "rock" then "Rock"
    when "mineraloid" then "Mineraloid"
    when "organic" then "Organic gem material"
    when "glass" then "Man-made glass"
    when "synthetic" then "Lab-made (synthetic)"
    when "treated" then species.present? ? "Treated #{species.downcase}" : "Treated stone"
    when "jewellery" then "Jewellery"
    else stone.kind.to_s.humanize
    end
  end

  # Badge text when the Atlas entry is not a natural stone, else nil.
  def atlas_unnatural_badge(stone)
    return nil if stone.natural?

    stone.kind == "jewellery" ? "A jewellery piece, not a stone" : "Not a natural stone"
  end

  # A short sentence for kinds that are not a natural stone, or nil.
  def atlas_kind_note(stone)
    case stone.kind
    when "glass" then "Not a natural stone: it is made in a factory, which is why it is so consistent."
    when "synthetic" then "Grown in a laboratory. Chemically the real thing, but not mined."
    when "treated" then "The colour or sheen is added by coating, dyeing or heat treatment, so care rules differ from the natural stone."
    when "mineraloid" then "No repeating crystal structure, so it can be more fragile than its hardness suggests."
    when "rock" then "A mix of minerals, so every piece differs a little."
    when "organic" then "Formed by living things, which makes it softer and more sensitive than most minerals."
    end
  end

  # Ten cells for the Mohs bar: true where the stone's hardness range falls.
  def atlas_mohs_cells(stone)
    lo = stone.mohs_min.ceil.clamp(1, 10)
    hi = stone.mohs_max.ceil.clamp(1, 10)
    (1..10).map { |i| i.between?(lo, hi) }
  end

  # One honest, derived sentence comparing the stone with everyday objects.
  def atlas_mohs_caption(stone)
    return nil if stone.mohs.empty?

    if stone.mohs_max <= 2.5 then "Softer than a fingernail (2.5): it scratches very easily."
    elsif stone.mohs_max < 5.5 then "Softer than window glass (about 5.5) and a steel knife: it scratches easily."
    elsif stone.mohs_min >= 7 then "Harder than glass (about 5.5) and a steel knife: it resists everyday scratches."
    elsif stone.mohs_min >= 6 then "Harder than glass (about 5.5), but a hard stone like quartz can still mark it."
    else "About as hard as window glass and a steel knife (around 5.5 to 6)."
    end
  end

  # "Smoke (sage, palo santo, incense)" => ["Smoke", "sage, palo santo, incense"]
  def atlas_cleanse_parts(key)
    label = Atlas::Stone::CLEANSE_METHODS[key].to_s
    main, detail = label.split(" (", 2)
    [main, detail&.delete_suffix(")")]
  end

  # Vedic line for a stone, or nil: graha names and the stone's role.
  def atlas_vedic(stone)
    graha = stone.vedic_planet
    info = Atlas::Vedic::GRAHAS[graha] or return nil
    nav = Atlas::Vedic::NAVARATNA[graha]
    role =
      if nav && nav[:slug] == stone.slug then "A Navaratna stone for #{info[:en]}."
      elsif nav && nav[:substitutes].include?(stone.slug) then "Worn as an upratna (substitute) for #{nav[:stone]}, #{nav[:hi]}."
      end
    { graha: graha, hindi: info[:hi], bengali: info[:bn], planet: info[:en], role: role }
  end

  def atlas_lang_names(stone)
    LANG_NAMES.filter_map do |lang, label|
      name = stone.names[lang].presence
      [lang, label, name] if name
    end
  end

  def atlas_source_host(url)
    URI.parse(url).host.to_s.delete_prefix("www.")
  rescue URI::InvalidURIError
    url
  end

  # schema.org Thing for a stone: name, description, url, image, sameAs and
  # the physical facts as additionalProperty.
  def atlas_stone_jsonld(entry, base: AtlasApi.base_url(request))
    stone = entry.stone
    props = []
    props << atlas_property("Mohs hardness", mohs_value(stone), "Mohs scale") if mohs_value(stone)
    props << atlas_property("Chemical formula", stone.formula) if stone.formula.present?
    props << atlas_property("Crystal system", stone.crystal_system) if stone.crystal_system.present?
    CARE_ROWS.each do |row|
      verdict = stone.safety(row[:key]) or next
      props << atlas_property(row[:ld], verdict, nil, stone.safety_reason(row[:key]))
    end
    props << atlas_property("Toxicity", stone.toxicity, nil, stone.toxicity_reason)

    data = {
      "@context" => "https://schema.org",
      "@type" => "Thing",
      "name" => stone.name,
      "description" => stone.summary,
      "url" => AtlasApi.stone_url(stone.slug, base),
      "sameAs" => stone.sources.grep(/mindat\.org|wikipedia\.org|wikidata\.org/),
      "additionalProperty" => props
    }
    data["alternateName"] = stone.aka if stone.aka.any?
    image = AtlasApi.absolute(entry.image_url, base)
    data["image"] = image if image
    data.delete("sameAs") if data["sameAs"].empty?
    data
  end

  private

  def mohs_value(stone)
    return nil if stone.mohs.empty?

    lo = atlas_num(stone.mohs_min)
    hi = atlas_num(stone.mohs_max)
    lo == hi ? lo : { "@type" => "QuantitativeValue", "minValue" => lo, "maxValue" => hi }
  end

  def atlas_num(n) = (n % 1).zero? ? n.to_i : n

  def atlas_property(name, value, unit = nil, description = nil)
    prop = { "@type" => "PropertyValue", "name" => name, "value" => value }
    prop["unitText"] = unit if unit
    prop["description"] = description if description.present?
    prop
  end
end
