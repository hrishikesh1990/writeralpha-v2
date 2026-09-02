# frozen_string_literal: true

# View helpers for the "Aura" gemstone screens: placeholder gradients, color
# swatches, quick facts and the directory's URL-driven filter state.
module GemstonesHelper
  # linear-gradient(145deg, light, dark) keyed by a stone's first color.
  STONE_GRADIENTS = {
    "Pink" => %w[#e8a7bf #b76e94], "Blue" => %w[#4a6fa5 #2c4a5e], "Red" => %w[#c05666 #7e2f3d],
    "Green" => %w[#5e9e77 #2f5c44], "Purple" => %w[#6d4aa0 #3d2a63], "Black" => %w[#4a4653 #211f27],
    "White" => %w[#d9d7e2 #a9a7ba], "Yellow" => %w[#e3c04c #a8862a], "Orange" => %w[#dd8a4e #a05426],
    "Brown" => %w[#a3765a #5f4231], "Gray" => %w[#9a97a5 #5f5d6a], "Gold" => %w[#d2a94b #8f6d24],
    "Multicolor" => %w[#b48fd0 #5f9bc0], "Colorless" => %w[#e4e2ee #b6b4c6]
  }.freeze

  # Directory swatches for colors whose hex_code is nil or too light to read.
  SWATCH_OVERRIDES = {
    "Multicolor" => "conic-gradient(#c4b5fd,#a5d8f3,#f3c6e2,#e3c04c,#c4b5fd)",
    "Colorless" => "linear-gradient(135deg,#fff,#d8d6e4)",
    "White" => "#f0eff5"
  }.freeze

  # Filter dimensions the directory understands as query params, and the
  # canonical (SEO) route each one maps to when it is the only active filter.
  CANONICAL_FILTER_ROUTES = {
    color: ->(v) { gemstones_by_color_path(color: v) },
    healing: ->(v) { gemstones_by_healing_path(value: v) },
    transparency: ->(v) { gemstones_by_transparency_path(value: v) },
    zodiac: ->(v) { gemstones_by_zodiac_path(value: v) },
    letter: ->(v) { gemstones_by_letter_path(value: v.downcase) },
    birth_month: ->(v) { gemstones_by_birth_month_path(value: v) },
    lustre: ->(v) { gemstones_by_lustre_path(value: v) },
    element: ->(v) { gemstones_by_element_path(value: v) },
    planet: ->(v) { gemstones_by_planet_path(value: v) },
    shape: ->(v) { gemstones_by_shape_path(value: v) },
    cut: ->(v) { gemstones_by_cut_path(value: v) }
  }.freeze

  def stone_gradient(gemstone)
    light, dark = STONE_GRADIENTS[gemstone.colors.first&.name] || STONE_GRADIENTS["Multicolor"]
    "linear-gradient(145deg,#{light},#{dark})"
  end

  def color_swatch(color)
    SWATCH_OVERRIDES[color.name] || color.hex_code || "#c4b5fd"
  end

  # Tinted chip: 10% of the color as background, the color itself as text.
  # Very light colors (white, yellow…) fall back to the muted UI palette.
  def color_chip_style(color)
    hex = color.hex_code.to_s.delete("#")
    return "background:rgba(124,58,237,0.10);color:#6d28d9" unless hex.match?(/\A\h{6}\z/)

    r, g, b = hex.scan(/../).map { |h| h.to_i(16) }
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    return "background:rgba(82,75,122,0.10);color:#6b6491" if luminance > 0.7

    "background:rgba(#{r},#{g},#{b},0.10);color:##{hex}"
  end

  # Hub <title>: describes the overview page without promising the full
  # "complete guide" (that lives at /meaning).
  def gemstone_hub_title(gemstone)
    "#{gemstone.name}: Properties, Healing Powers & Guides"
  end

  def gemstone_hub_description(gemstone)
    parts = []
    parts << "#{gemstone.name}, #{gemstone.subtitle.downcase.delete_prefix('the ')}." if gemstone.subtitle.present?
    parts << plain_excerpt(gemstone.description, length: 110) if gemstone.description.present?
    powers = gemstone.healing_powers.first(3).map(&:name)
    parts << "Healing powers: #{powers.join(', ')}." if powers.any?
    parts << "Mohs #{format_mohs(gemstone.mohs_hardness)}." if gemstone.mohs_hardness
    meta_description(parts.join(" ").presence || "#{gemstone.name} facts, meaning, healing powers and care guides.")
  end

  def filter_page_description(filter_name, filter_type, gemstones)
    names = gemstones.first(4).map(&:name)
    lead = "#{gemstones.size} #{filter_name.to_s.downcase} #{'gemstone'.pluralize(gemstones.size)}"
    lead += " — #{names.to_sentence(last_word_connector: ' and ')}" if names.any?
    meta_description("#{lead}. Meanings, healing powers, hardness and care tips for every #{filter_type.to_s.downcase} match.")
  end

  def format_mohs(value)
    return nil if value.nil?

    value == value.to_i ? value.to_i.to_s : value.to_s
  end

  # Quick facts shown on the hub hero (4×2) — label/value pairs, "—" when unknown.
  def gemstone_facts(gemstone)
    [
      ["Mohs hardness", format_mohs(gemstone.mohs_hardness)&.then { |m| "#{m} / 10" }],
      ["Transparency", gemstone.transparency&.name],
      ["Lustre", gemstone.lustre&.name],
      ["Birth month", gemstone.birth_month&.name],
      ["Element", gemstone.element.presence],
      ["Ruling planet", gemstone.ruling_planet.presence],
      ["Zodiac", gemstone.zodiac_signs.map(&:name).presence&.join(" · ")],
      ["Color", gemstone.colors.map(&:name).presence&.join(" · ")]
    ].map { |label, value| [label, value || "—"] }
  end

  # Path for a given set of active filters. One filter → canonical route,
  # several (or a search query) → /gemstones?… so combinations stay shareable.
  def directory_path_for(active)
    active = active.to_h.symbolize_keys.compact_blank
    query = active.delete(:q)
    return gemstones_path(active.merge(q: query).compact_blank) if query.present? || active.size > 1
    return gemstones_path if active.empty?

    key, value = active.first
    route = CANONICAL_FILTER_ROUTES[key]
    route ? instance_exec(value, &route) : gemstones_path(active)
  end

  def toggle_filter_path(active, key, value)
    directory_path_for(active.merge(key => (active[key] == value ? nil : value)))
  end

  def filter_pill_class(active)
    base = "inline-flex items-center rounded-full border px-3 py-1.5 text-[10.5px] leading-none card-transition"
    if active
      "#{base} border-violet/90 bg-violet/90 text-white hover:text-white"
    else
      "#{base} border-ui/14 bg-pill-off/90 text-ui hover:border-violet/35 hover:text-violet-deep"
    end
  end
end
