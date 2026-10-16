# frozen_string_literal: true

module Atlas
  # Read-only wrapper over one stone's YAML hash. Accessors return plain Ruby
  # values with safe defaults so views never need nil checks.
  class Stone
    attr_reader :data

    def initialize(data) = (@data = data.freeze)

    def slug = data["slug"]
    def name = data["name"]
    def aka = Array(data["aka"])
    def kind = data["kind"]
    def natural? = !%w[glass synthetic treated jewellery].include?(kind)
    def species = data["species"]
    def family = data["family"]
    def formula = data["formula"]
    def crystal_system = data["crystal_system"]
    def colors = Array(data["colors"])
    def origins = Array(data["origins"])
    def summary = data["summary"].to_s

    # [min, max] as floats; mohs_label "7" or "5.5–6"
    def mohs = Array(data["mohs"]).map(&:to_f)
    def mohs_min = mohs.min
    def mohs_max = mohs.max
    def mohs_label = mohs.uniq.size == 1 ? fmt(mohs.first) : "#{fmt(mohs_min)}–#{fmt(mohs_max)}"

    # ---- Safety ------------------------------------------------------------
    def safety_entry(key) = (data.dig("safety", key.to_s) || {})
    def safety(key) = safety_entry(key)["verdict"]
    def safety_reason(key) = safety_entry(key)["reason"].to_s
    def toxicity = data.dig("safety", "toxicity", "level") || "none"
    def toxicity_reason = data.dig("safety", "toxicity", "reason").to_s
    def elixir = data.dig("safety", "elixir") || "indirect"

    # Cleansing methods that are safe for this stone, derived from safety.
    CLEANSE_METHODS = {
      "smoke" => "Smoke (sage, palo santo, incense)",
      "sound" => "Sound (singing bowl, bell, tuning fork)",
      "moonlight" => "Moonlight",
      "selenite" => "Resting on selenite or clear quartz",
      "breath" => "Breath and intention",
      "earth" => "Burying in dry earth",
      "water" => "Running water",
      "sunlight" => "Sunlight",
      "salt_water" => "Salt water",
      "dry_salt" => "A bowl of dry salt (stone not touching)"
    }.freeze

    def safe_cleanse_methods
      m = %w[smoke sound moonlight selenite breath]
      m << "earth" if mohs_min >= 3 && safety("water") != "avoid"
      m << "water" if safety("water") == "safe"
      m << "sunlight" if safety("sun") == "safe"
      m << "salt_water" if safety("salt") == "safe" && safety("water") == "safe"
      m << "dry_salt"
      m
    end

    def unsafe_cleanse_methods = CLEANSE_METHODS.keys - safe_cleanse_methods

    # ---- Tradition (metaphysical; always rendered as tradition, not fact) --
    def chakras = Array(data.dig("tradition", "chakras"))
    def elements = Array(data.dig("tradition", "elements"))
    def planets = Array(data.dig("tradition", "planets"))
    def vedic_planet = data.dig("tradition", "vedic_planet")
    def zodiac = Array(data.dig("tradition", "zodiac"))
    def intentions = Array(data.dig("tradition", "intentions"))
    def energy = data.dig("tradition", "energy")
    def birth_months = (data.dig("tradition", "birth_months") || {})
    def modern_birthstone_for = Array(birth_months["modern"])
    def traditional_birthstone_for = Array(birth_months["traditional"])
    def any_birthstone_for = (modern_birthstone_for + traditional_birthstone_for + Array(birth_months["other"])).uniq

    def cautions = Array(data["cautions"])
    def zodiac_cautions = Array(data["zodiac_cautions"]) # [{ "sign" =>, "why" => }]

    # ---- Identification ----------------------------------------------------
    def common_fakes = Array(data.dig("identify", "common_fakes"))
    def tests = Array(data.dig("identify", "tests"))

    # ---- Pairings ----------------------------------------------------------
    def pairs_good = Array(data.dig("pairs", "good"))
    def pairs_avoid = Array(data.dig("pairs", "avoid"))
    def pair_with?(slug) = pairs_good.any? { |p| p["slug"] == slug }
    def avoid_with?(slug) = pairs_avoid.any? { |p| p["slug"] == slug }

    # ---- Price / names / sources ------------------------------------------
    def price_tier = data.dig("price", "tier")
    def price_note = data.dig("price", "note").to_s
    def names = (data["names"] || {})
    def local_name(lang) = names[lang.to_s]
    def sources = Array(data["sources"])

    def to_h = data
    def ==(other) = other.is_a?(Stone) && other.slug == slug
    alias eql? ==
    def hash = slug.hash

    private

    def fmt(n) = (n % 1).zero? ? n.to_i.to_s : n.to_s
  end
end
