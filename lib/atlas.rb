# frozen_string_literal: true

require "yaml"
require "set"

# The Atlas: a curated, sourced knowledge base of every live gemstone, one
# YAML file per stone in data/atlas/stones/<slug>.yml. It is the single source
# of structured facts (safety, hardness, chakras, planets, identification
# tests, pairings, local names) that the tools and hub pages read.
#
# Plain Ruby on purpose: `bin/atlas-validate` loads it without booting Rails,
# and the Rails app autoloads the same files (config.autoload_lib).
#
#   Atlas["amethyst"]          # => Atlas::Stone or nil
#   Atlas.stones               # => [Atlas::Stone, ...] sorted by name
#   Atlas.slugs                # => ["agate", ...]
module Atlas
  # ---- Controlled vocabularies (the validator enforces these) --------------
  KINDS = %w[mineral variety rock mineraloid organic glass synthetic treated jewellery].freeze
  CHAKRAS = %w[root sacral solar_plexus heart throat third_eye crown].freeze
  CHAKRA_LABELS = {
    "root" => "Root", "sacral" => "Sacral", "solar_plexus" => "Solar Plexus", "heart" => "Heart",
    "throat" => "Throat", "third_eye" => "Third Eye", "crown" => "Crown"
  }.freeze
  ELEMENTS = %w[fire earth air water].freeze
  PLANETS = %w[sun moon mercury venus mars jupiter saturn uranus neptune pluto].freeze
  # Jyotish grahas. Navaratna mapping lives in Atlas::Vedic.
  VEDIC_PLANETS = %w[surya chandra mangal budh guru shukra shani rahu ketu].freeze
  ZODIAC = %w[aries taurus gemini cancer leo virgo libra scorpio sagittarius capricorn aquarius pisces].freeze
  MONTHS = %w[january february march april may june july august september october november december].freeze
  ENERGIES = %w[calming energizing grounding balancing].freeze

  # Intentions = the 15 healing-power slugs already used by the site's filter
  # pages, plus the extra intents people actually search for.
  INTENTIONS = %w[
    peace-calm concentration protection love wealth confidence creativity grounding healing
    sleep communication intuition transformation courage emotional-balance
    anxiety self-love grief luck energy clarity motivation spiritual-growth career friendship
  ].freeze
  INTENTION_LABELS = INTENTIONS.to_h { |i| [i, i.split("-").map(&:capitalize).join(" ").sub("Peace Calm", "Peace & Calm")] }.freeze

  SAFETY_KEYS = %w[water salt sun sleep wear].freeze
  SAFETY_VERDICTS = {
    "water" => %w[safe brief avoid],   # brief = a quick rinse, never soak
    "salt" => %w[safe avoid],
    "sun" => %w[safe limit avoid],     # limit = fades or heats with long exposure
    "sleep" => %w[ok caution],
    "wear" => %w[daily care special]   # care = avoid knocks/chemicals; special = occasional wear only
  }.freeze
  TOXICITY = %w[none low caution].freeze
  ELIXIR = %w[direct indirect never].freeze
  PRICE_TIERS = %w[budget mid premium luxury].freeze
  CAUTION_BASIS = %w[physical tradition].freeze
  TEST_IDS = %w[
    hardness streak bubbles temperature weight magnification uv price color inclusions
    light magnet scratch acetone water_dissolve flame shape seller certificate refractive
  ].freeze
  NAME_LANGS = %w[hi bn es ta te mr].freeze

  class << self
    def dir
      ENV["ATLAS_DIR"].to_s.empty? ? File.expand_path("../data/atlas/stones", __dir__) : ENV["ATLAS_DIR"]
    end

    def [](slug) = index[slug.to_s]
    def stones = index.values.sort_by(&:name)
    def slugs = index.keys.sort
    def any? = !index.empty?

    def index
      stamp = Dir.glob(File.join(dir, "*.yml")).sum { |f| File.mtime(f).to_i }
      return @index if @index && @stamp == stamp

      @stamp = stamp
      @index = Dir.glob(File.join(dir, "*.yml")).sort.each_with_object({}) do |file, h|
        stone = load_file(file)
        h[stone.slug] = stone if stone
      end.freeze
    end

    def reload! = (@index = nil)

    # A malformed or half-written file is skipped (and logged), never fatal:
    # one bad stone must not take every tool page down.
    def load_file(file)
      data = YAML.safe_load_file(file, permitted_classes: [], aliases: false)
      unless data.is_a?(Hash) && data["slug"].is_a?(String) && data["name"].is_a?(String)
        return warn_skip(file, "not a stone map")
      end

      Stone.new(data)
    rescue Psych::Exception, SystemCallError => e
      warn_skip(file, e.message)
    end

    def warn_skip(file, why)
      msg = "[atlas] skipped #{File.basename(file)}: #{why}"
      defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger ? Rails.logger.warn(msg) : Kernel.warn(msg)
      nil
    end

    # Stones matching a predicate on any field, e.g. Atlas.where { |s| s.safety("water") == "avoid" }
    def where(&) = stones.select(&)
  end
end
