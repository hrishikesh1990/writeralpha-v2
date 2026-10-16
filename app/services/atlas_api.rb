# frozen_string_literal: true

require "digest"
require "json"

# Serializer and query layer for the Open Gemstone Data API (/api/v1).
#
# Pure Ruby over AtlasEntry (or anything that quacks like it): no view code, no
# request objects. Field names here are the public, versioned contract; the
# /developers page renders its reference tables from FIELDS and FILTERS below,
# which in turn read the Atlas vocabularies, so docs, validation and data
# cannot drift apart.
#
#   AtlasApi.summary(entry)            # lean record for list responses
#   AtlasApi.detail(entry)             # full record (summary + everything else)
#   AtlasApi.envelope(data, count:)    # { data:, meta: { ... } }
#   AtlasApi.filter(entries, params)   # => [entries, applied, error]
module AtlasApi
  VERSION = "1"
  LICENSE = "CC BY 4.0"
  LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
  SITE = "https://writeralpha.com"
  DOCS_PATH = "/developers"
  ATTRIBUTION = "Data: WriterAlpha Gemstone Atlas (https://writeralpha.com/developers)"
  ATTRIBUTION_HTML = 'Data: <a href="https://writeralpha.com/developers">WriterAlpha Gemstone Atlas</a>'

  TRADITION_NOTE = "Everything under tradition (chakras, elements, planets, Vedic grahas, zodiac, intentions, birth months) " \
                   "comes from crystal-healing, astrological and birthstone tradition. It is reported as tradition, " \
                   "not as scientific fact, and nothing here is medical advice."

  KIND_LABELS = {
    "mineral" => "Mineral", "variety" => "Mineral variety", "rock" => "Rock", "mineraloid" => "Mineraloid",
    "organic" => "Organic gem material", "glass" => "Man-made glass", "synthetic" => "Lab-made (synthetic)",
    "treated" => "Treated stone", "jewellery" => "Jewellery"
  }.freeze

  # Filter parameters for GET /api/v1/stones. `values` is the allowed set (from
  # the Atlas vocabularies); `match` returns true when a stone satisfies one
  # value. Several values may be comma-separated (OR within a parameter, AND
  # between parameters).
  FILTERS = {
    "water" => { values: Atlas::SAFETY_VERDICTS["water"], doc: "Water safety verdict.",
                 match: ->(s, v) { s.safety("water") == v } },
    "salt" => { values: Atlas::SAFETY_VERDICTS["salt"], doc: "Salt (and salt water) safety verdict.",
                match: ->(s, v) { s.safety("salt") == v } },
    "sun" => { values: Atlas::SAFETY_VERDICTS["sun"], doc: "Sunlight safety verdict.",
               match: ->(s, v) { s.safety("sun") == v } },
    "sleep" => { values: Atlas::SAFETY_VERDICTS["sleep"], doc: "Safe to keep under a pillow or by the bed.",
                 match: ->(s, v) { s.safety("sleep") == v } },
    "wear" => { values: Atlas::SAFETY_VERDICTS["wear"], doc: "How suitable the stone is for wearing.",
                match: ->(s, v) { s.safety("wear") == v } },
    "toxicity" => { values: Atlas::TOXICITY, doc: "Toxicity level when handled or worn.",
                    match: ->(s, v) { s.toxicity == v } },
    "elixir" => { values: Atlas::ELIXIR, doc: "Whether the stone may be steeped in drinking water.",
                  match: ->(s, v) { s.elixir == v } },
    "kind" => { values: Atlas::KINDS, doc: "What sort of material it is (mineral, glass, treated ...).",
                match: ->(s, v) { s.kind == v } },
    "zodiac" => { values: Atlas::ZODIAC, doc: "Zodiac sign the stone is traditionally assigned to.",
                  match: ->(s, v) { s.zodiac.include?(v) } },
    "chakra" => { values: Atlas::CHAKRAS, doc: "Chakra in crystal tradition.",
                  match: ->(s, v) { s.chakras.include?(v) } },
    "element" => { values: Atlas::ELEMENTS, doc: "Element in crystal tradition.",
                   match: ->(s, v) { s.elements.include?(v) } },
    "planet" => { values: Atlas::PLANETS, doc: "Western planet in astrological tradition.",
                  match: ->(s, v) { s.planets.include?(v) } },
    "intention" => { values: Atlas::INTENTIONS, doc: "Intention the stone is traditionally used for.",
                     match: ->(s, v) { s.intentions.include?(v) } },
    "month" => { values: Atlas::MONTHS, doc: "Birth month (modern, traditional or alternate birthstone lists).",
                 match: ->(s, v) { s.any_birthstone_for.include?(v) } }
  }.freeze

  MOHS_PARAMS = %w[mohs_min mohs_max].freeze
  FILTER_PARAMS = (FILTERS.keys + MOHS_PARAMS + %w[q]).freeze

  # Reference for every field in a detail record, in order. `values` are the
  # enumerations pulled live from the Atlas constants.
  FIELDS = [
    { path: "slug", type: "string", doc: "Stable identifier; also the last segment of the hub URL." },
    { path: "name", type: "string", doc: "Display name." },
    { path: "aka", type: "string[]", doc: "Other names people search for.", detail: true },
    { path: "url", type: "string", doc: "Absolute URL of the stone's hub page." },
    { path: "api_url", type: "string", doc: "Absolute URL of this record in the API." },
    { path: "kind", type: "enum", doc: "What the material is. Glass and treated stones are labelled honestly.", values: Atlas::KINDS },
    { path: "species", type: "string | null", doc: "Mineral species, for example Quartz. Null for glass and rocks." },
    { path: "family", type: "string | null", doc: "Mineral family, lower-case.", detail: true },
    { path: "formula", type: "string | null", doc: "Chemical formula.", detail: true },
    { path: "crystal_system", type: "string | null", doc: "Crystal system, lower-case.", detail: true },
    { path: "mohs.min / mohs.max", type: "number", doc: "Mohs hardness range, 1 to 10. Equal for a single value." },
    { path: "colors", type: "string[]", doc: "Typical colours, lower-case." },
    { path: "origins", type: "string[]", doc: "Main producing countries.", detail: true },
    { path: "summary", type: "string", doc: "Plain-language description plus the one care fact that matters most.", detail: true },
    { path: "safety.water", type: "enum", doc: "Can it get wet. brief means a quick rinse, never a soak.", values: Atlas::SAFETY_VERDICTS["water"] },
    { path: "safety.salt", type: "enum", doc: "Salt and salt water.", values: Atlas::SAFETY_VERDICTS["salt"] },
    { path: "safety.sun", type: "enum", doc: "Sunlight. limit means fading or heating with long exposure.", values: Atlas::SAFETY_VERDICTS["sun"] },
    { path: "safety.sleep", type: "enum", doc: "Under a pillow or by the bed.", values: Atlas::SAFETY_VERDICTS["sleep"] },
    { path: "safety.wear", type: "enum", doc: "Wearability. care means avoid knocks or chemicals; special means occasional wear only.", values: Atlas::SAFETY_VERDICTS["wear"] },
    { path: "safety.toxicity", type: "enum", doc: "caution means toxic dust or leaching (copper, lead, arsenic, fibres).", values: Atlas::TOXICITY },
    { path: "safety.elixir", type: "enum", doc: "Whether the stone may be steeped in drinking water. direct, indirect (sealed glass only) or never.", values: Atlas::ELIXIR },
    { path: "safety_notes.*", type: "string", doc: "One concrete, physical reason for each safety value (water, salt, sun, sleep, wear, toxicity).", detail: true },
    { path: "cleanse.safe / cleanse.avoid", type: "string[]", doc: "Cleansing methods that are safe, and those to skip, derived from the safety values.", detail: true, values: Atlas::Stone::CLEANSE_METHODS.keys },
    { path: "tradition.chakras", type: "enum[]", doc: "Chakras in crystal tradition.", values: Atlas::CHAKRAS },
    { path: "tradition.zodiac", type: "enum[]", doc: "Signs the stone is most commonly assigned to.", values: Atlas::ZODIAC },
    { path: "tradition.elements", type: "enum[]", doc: "Elements in crystal tradition.", values: Atlas::ELEMENTS, detail: true },
    { path: "tradition.planets", type: "enum[]", doc: "Western astrological planets.", values: Atlas::PLANETS, detail: true },
    { path: "tradition.vedic_planet", type: "enum | null", doc: "Jyotish graha. Only for Navaratna stones and their recognised substitutes (upratna).", values: Atlas::VEDIC_PLANETS, detail: true },
    { path: "tradition.intentions", type: "enum[]", doc: "What the stone is traditionally used for.", values: Atlas::INTENTIONS, detail: true },
    { path: "tradition.energy", type: "enum | null", doc: "Overall energy in crystal tradition.", values: Atlas::ENERGIES, detail: true },
    { path: "tradition.birth_months", type: "object", doc: "Lists of months: modern (AGTA / Jewelers of America), traditional (pre-1912) and other (widely cited alternates).", values: Atlas::MONTHS, detail: true },
    { path: "tradition.note", type: "string", doc: "Reminder that this block is tradition, not scientific fact.", detail: true },
    { path: "cautions[]", type: "object[]", doc: "Who should take care. Each has who, why and basis. Physical cautions come first.", values: Atlas::CAUTION_BASIS, detail: true },
    { path: "zodiac_cautions[]", type: "object[]", doc: "Signs tradition advises against, each with sign and why (mostly Vedic planetary enmity).", detail: true },
    { path: "identification.common_fakes", type: "string[]", doc: "What is actually sold as this stone.", detail: true },
    { path: "identification.tests[]", type: "object[]", doc: "Home tests: id, weight (1 weak hint to 3 near-conclusive), how, real, fake.", values: Atlas::TEST_IDS, detail: true },
    { path: "pairs.good[] / pairs.avoid[]", type: "object[]", doc: "Pairings with a slug and a stated reason.", detail: true },
    { path: "price", type: "object | null", doc: "tier and a realistic note, without invented figures.", values: Atlas::PRICE_TIERS, detail: true },
    { path: "names", type: "object", doc: "Local names by language code.", values: Atlas::NAME_LANGS, detail: true },
    { path: "image_url", type: "string | null", doc: "Absolute URL of the stone's photo." },
    { path: "links", type: "object", doc: "hub, api, image and guides (a map of guide slug to URL, only for guides that exist).", detail: true },
    { path: "sources[]", type: "string[]", doc: "https URLs for the mineralogy and tradition facts.", detail: true }
  ].freeze

  class InvalidParameter < StandardError
    attr_reader :parameter, :allowed

    def initialize(parameter, value, allowed)
      @parameter = parameter
      @allowed = allowed
      expected = allowed.is_a?(Array) ? "Allowed values: #{allowed.join(', ')}." : "Expected #{allowed}."
      super("Invalid value #{value.to_s.truncate(40).inspect} for parameter #{parameter}. #{expected}")
    end
  end

  module_function

  # ---- URLs -----------------------------------------------------------------

  # Absolute origin for links. CANONICAL_HOST (production) wins; otherwise the
  # request's own origin, otherwise the public site.
  def base_url(request = nil)
    host = ENV["CANONICAL_HOST"].to_s.strip
    return "https://#{host.sub(%r{\Ahttps?://}, '').chomp('/')}" unless host.empty?
    return "#{request.protocol.delete_suffix('://')}://#{request.host_with_port}" if request

    SITE
  end

  def stone_url(slug, base) = "#{base}/gemstones/#{slug}"
  def api_url(slug, base) = "#{base}/api/v1/stones/#{slug}"

  def absolute(path, base)
    return nil if path.blank?

    image_base = ENV["IMAGE_BASE_URL"].presence
    path = "#{image_base.chomp('/')}/#{path.delete_prefix('/images/')}" if image_base && path.start_with?("/images/")
    path.start_with?("http") ? path : "#{base}#{path}"
  end

  # ---- Records --------------------------------------------------------------

  def summary(entry, base: SITE)
    {
      "slug" => entry.slug,
      "name" => entry.name,
      "url" => stone_url(entry.slug, base),
      "api_url" => api_url(entry.slug, base),
      "kind" => entry.kind,
      "species" => entry.species,
      "mohs" => { "min" => num(entry.mohs_min), "max" => num(entry.mohs_max) },
      "colors" => entry.stone.colors,
      "safety" => safety_verdicts(entry),
      "tradition" => { "chakras" => entry.chakras, "zodiac" => entry.zodiac },
      "image_url" => absolute(entry.image_url, base)
    }
  end

  # A strict superset of summary: every summary key keeps its type and place.
  def detail(entry, base: SITE)
    s = entry.stone
    rec = summary(entry, base:)
    rec["tradition"] = rec["tradition"].merge(
      "elements" => s.elements, "planets" => s.planets, "vedic_planet" => s.vedic_planet,
      "intentions" => s.intentions, "energy" => s.energy,
      "birth_months" => birth_months(s), "note" => TRADITION_NOTE
    )
    rec.merge(
      "aka" => s.aka,
      "family" => s.family,
      "formula" => s.formula,
      "crystal_system" => s.crystal_system,
      "origins" => s.origins,
      "summary" => s.summary,
      "safety_notes" => safety_notes(s),
      "cleanse" => { "safe" => s.safe_cleanse_methods, "avoid" => s.unsafe_cleanse_methods },
      "cautions" => s.cautions.map { |c| pick(c, "who", "why", "basis") },
      "zodiac_cautions" => s.zodiac_cautions.map { |c| pick(c, "sign", "why") },
      "identification" => {
        "common_fakes" => s.common_fakes,
        "tests" => s.tests.map { |t| pick(t, "id", "weight", "how", "real", "fake") }
      },
      "pairs" => { "good" => s.pairs_good.map { |p| pick(p, "slug", "why") },
                   "avoid" => s.pairs_avoid.map { |p| pick(p, "slug", "why") } },
      "price" => s.price_tier ? { "tier" => s.price_tier, "note" => s.price_note } : nil,
      "names" => s.names,
      "links" => links(entry, base),
      "sources" => s.sources
    )
  end

  def envelope(data, count:, filters: nil, base: SITE, now: Time.now.utc)
    meta = {
      "count" => count,
      "version" => VERSION,
      "license" => LICENSE,
      "license_url" => LICENSE_URL,
      "attribution" => ATTRIBUTION,
      "documentation_url" => "#{base}#{DOCS_PATH}",
      "generated_at" => now.iso8601
    }
    meta["filters"] = filters if filters
    { "data" => data, "meta" => meta }
  end

  def error(status:, code:, message:, allowed: nil, base: SITE)
    err = { "status" => status, "code" => code, "message" => message }
    err["allowed"] = allowed if allowed
    err["documentation_url"] = "#{base}#{DOCS_PATH}"
    { "error" => err }
  end

  # Stable cache validator for a response body's data.
  def etag_for(data, *extra) = Digest::SHA256.hexdigest([JSON.generate(data), *extra].join("|"))[0, 32]

  # ---- Filtering ------------------------------------------------------------

  # => [matching entries, applied filters (param => [values]), nil]
  # Raises InvalidParameter for an unknown value.
  def filter(entries, params)
    applied = {}
    FILTERS.each do |name, spec|
      raw = params[name]
      next if raw.nil? || raw.to_s.strip.empty?

      values = raw.to_s.downcase.split(",").map(&:strip).reject(&:empty?).map { |v| normalize(v, spec[:values]) }.uniq
      bad = values.find { |v| !spec[:values].include?(v) }
      raise InvalidParameter.new(name, bad, spec[:values]) if bad || values.empty?

      applied[name] = values
      entries = entries.select { |e| values.any? { |v| spec[:match].call(e.stone, v) } }
    end

    MOHS_PARAMS.each do |name|
      raw = params[name]
      next if raw.nil? || raw.to_s.strip.empty?

      num = Float(raw.to_s, exception: false)
      raise InvalidParameter.new(name, raw, "a number from 1 to 10") unless num && num.between?(1, 10)

      applied[name] = num(num)
      entries = entries.select { |e| name == "mohs_min" ? e.mohs_max >= num : e.mohs_min <= num }
    end

    if (q = params["q"].to_s.strip.downcase).present?
      raise InvalidParameter.new("q", q, "text of at most 80 characters") if q.length > 80

      applied["q"] = q
      entries = entries.select { |e| searchable(e.stone).any? { |t| t.include?(q) } }
    end
    [entries, applied, nil]
  end

  # Slugs use hyphens in intentions (peace-calm) but underscores in chakras
  # (third_eye); accept either spelling for both.
  def normalize(value, allowed)
    [value, value.tr("_ ", "-"), value.tr("- ", "_")].find { |v| allowed.include?(v) } || value
  end

  def searchable(stone)
    ([stone.slug, stone.name, stone.species, stone.family, stone.formula] + stone.aka).compact.map { |t| t.to_s.downcase }
  end

  # ---- helpers --------------------------------------------------------------

  def safety_verdicts(entry)
    h = Atlas::SAFETY_KEYS.to_h { |k| [k, entry.safety(k)] }
    h.merge("toxicity" => entry.toxicity, "elixir" => entry.elixir)
  end

  def safety_notes(stone)
    notes = Atlas::SAFETY_KEYS.to_h { |k| [k, stone.safety_reason(k)] }
    notes.merge("toxicity" => stone.toxicity_reason)
  end

  def birth_months(stone)
    bm = stone.birth_months
    { "modern" => Array(bm["modern"]), "traditional" => Array(bm["traditional"]), "other" => Array(bm["other"]) }
  end

  def guide_slugs = Gemstone::SUB_PAGES.map { |g| g[:path] }

  def links(entry, base)
    guides = guide_slugs.select { |g| guide?(entry, g) }.to_h { |g| [g, "#{base}/gemstones/#{entry.slug}/#{g}"] }
    { "hub" => stone_url(entry.slug, base), "api" => api_url(entry.slug, base),
      "image" => absolute(entry.image_url, base), "guides" => guides }
  end

  # AtlasEntry.all rows carry has_* flags; a full Gemstone (used on hub pages)
  # does not, so fall back to its stored content.
  def guide?(entry, guide)
    gem = entry.gemstone
    return entry.guide?(guide) if gem.attributes.key?("has_#{guide.tr('-', '_')}")

    gem.sub_page_content(guide).present?
  rescue StandardError
    false
  end

  def num(n) = (n % 1).zero? ? n.to_i : n

  def pick(hash, *keys) = keys.to_h { |k| [k, hash[k]] }
end
