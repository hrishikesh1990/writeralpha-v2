# frozen_string_literal: true

module Atlas
  # Validates one stone hash against the Atlas schema (see data/atlas/SCHEMA.md).
  # Returns [errors, warnings]; errors block import, warnings are advisory.
  class Validator
    REQUIRED_TOP = %w[slug name kind mohs summary safety tradition identify pairs price sources].freeze
    SLUG_RE = /\A[a-z0-9]+(-[a-z0-9]+)*\z/

    def self.validate(data, known_slugs: nil) = new(data, known_slugs).run

    def initialize(data, known_slugs)
      @d = data || {}
      @known = known_slugs && Set.new(known_slugs)
      @errors = []
      @warnings = []
    end

    def run
      REQUIRED_TOP.each { |k| err("missing top-level key '#{k}'") unless @d.key?(k) }
      return [@errors, @warnings] unless @errors.empty?

      err("slug '#{@d['slug']}' is not kebab-case") unless @d["slug"].to_s.match?(SLUG_RE)
      enum("kind", @d["kind"], KINDS)
      check_mohs
      check_summary
      check_safety
      check_tradition
      check_cautions
      check_identify
      check_pairs
      check_price
      check_names
      check_sources
      [@errors, @warnings]
    end

    private

    def err(m) = @errors << m
    def warn(m) = @warnings << m

    def enum(path, val, allowed)
      err("#{path}: '#{val}' not in #{allowed.join('|')}") unless allowed.include?(val)
    end

    def enum_list(path, vals, allowed, min: 0, max: 99)
      vals = Array(vals)
      err("#{path}: expected #{min}..#{max} items, got #{vals.size}") unless vals.size.between?(min, max)
      vals.each { |v| enum(path, v, allowed) }
      err("#{path}: duplicates") if vals.uniq.size != vals.size
    end

    def text(path, val, min: 1, max: 600)
      s = val.to_s.strip
      err("#{path}: missing text") if s.empty? && min.positive?
      err("#{path}: too long (#{s.size} > #{max})") if s.size > max
    end

    def check_mohs
      m = @d["mohs"]
      unless m.is_a?(Array) && m.size == 2 && m.all? { |x| x.is_a?(Numeric) && x.between?(1, 10) } && m[0] <= m[1]
        err("mohs: must be [min, max] numbers 1..10, min<=max")
      end
    end

    def check_summary = text("summary", @d["summary"], min: 40, max: 400)

    def check_safety
      s = @d["safety"]
      return err("safety: must be a map") unless s.is_a?(Hash)

      SAFETY_KEYS.each do |k|
        e = s[k]
        next err("safety.#{k}: missing") unless e.is_a?(Hash)

        enum("safety.#{k}.verdict", e["verdict"], SAFETY_VERDICTS[k])
        text("safety.#{k}.reason", e["reason"], min: 15, max: 300)
      end
      t = s["toxicity"]
      if t.is_a?(Hash)
        enum("safety.toxicity.level", t["level"], TOXICITY)
        text("safety.toxicity.reason", t["reason"], min: 10, max: 300)
      else
        err("safety.toxicity: missing")
      end
      enum("safety.elixir", s["elixir"], ELIXIR)
      if t.is_a?(Hash) && t["level"] == "caution" && s["elixir"] == "direct"
        err("safety: toxicity caution but elixir direct")
      end
      if s.dig("water", "verdict") == "avoid" && s.dig("salt", "verdict") == "safe"
        err("safety: water avoid but salt safe is contradictory")
      end
      mohs_min = Array(@d["mohs"]).first.to_f
      if mohs_min < 5 && s.dig("salt", "verdict") == "safe"
        warn("safety.salt: safe on a stone under Mohs 5 — double-check")
      end
    end

    def check_tradition
      t = @d["tradition"]
      return err("tradition: must be a map") unless t.is_a?(Hash)

      enum_list("tradition.chakras", t["chakras"], CHAKRAS, min: 1, max: 4)
      enum_list("tradition.elements", t["elements"], ELEMENTS, min: 1, max: 2)
      enum_list("tradition.planets", t["planets"], PLANETS, min: 0, max: 3)
      enum("tradition.vedic_planet", t["vedic_planet"], VEDIC_PLANETS) unless t["vedic_planet"].nil?
      enum_list("tradition.zodiac", t["zodiac"], ZODIAC, min: 1, max: 5)
      enum_list("tradition.intentions", t["intentions"], INTENTIONS, min: 3, max: 8)
      enum("tradition.energy", t["energy"], ENERGIES)
      bm = t["birth_months"] || {}
      err("tradition.birth_months: must be a map") unless bm.is_a?(Hash)
      %w[modern traditional other].each { |k| enum_list("tradition.birth_months.#{k}", bm[k], MONTHS, max: 3) } if bm.is_a?(Hash)
    end

    def check_cautions
      c = @d["cautions"]
      err("cautions: need 2..8 entries") unless c.is_a?(Array) && c.size.between?(2, 8)
      Array(c).each_with_index do |e, i|
        text("cautions[#{i}].who", e["who"], min: 5, max: 120)
        text("cautions[#{i}].why", e["why"], min: 15, max: 400)
        enum("cautions[#{i}].basis", e["basis"], CAUTION_BASIS)
      end
      Array(@d["zodiac_cautions"]).each_with_index do |e, i|
        enum("zodiac_cautions[#{i}].sign", e["sign"], ZODIAC)
        text("zodiac_cautions[#{i}].why", e["why"], min: 15, max: 300)
      end
      overlap = Array(@d["zodiac_cautions"]).map { |z| z["sign"] } & Array(@d.dig("tradition", "zodiac"))
      err("zodiac_cautions overlap tradition.zodiac: #{overlap.join(',')}") if overlap.any?
    end

    def check_identify
      i = @d["identify"]
      return err("identify: must be a map") unless i.is_a?(Hash)

      f = Array(i["common_fakes"])
      err("identify.common_fakes: need 1..6") unless f.size.between?(1, 6)
      tests = Array(i["tests"])
      err("identify.tests: need 4..8 tests") unless tests.size.between?(4, 8)
      tests.each_with_index do |t, n|
        enum("identify.tests[#{n}].id", t["id"], TEST_IDS)
        %w[how real fake].each { |k| text("identify.tests[#{n}].#{k}", t[k], min: 10, max: 300) }
        err("identify.tests[#{n}].weight must be 1..3") unless [1, 2, 3].include?(t["weight"])
      end
      err("identify.tests: duplicate ids") if tests.map { |t| t["id"] }.uniq.size != tests.size
    end

    def check_pairs
      p = @d["pairs"]
      return err("pairs: must be a map") unless p.is_a?(Hash)

      good = Array(p["good"])
      avoid = Array(p["avoid"])
      err("pairs.good: need 3..8") unless good.size.between?(3, 8)
      err("pairs.avoid: max 4") if avoid.size > 4
      (good + avoid).each do |e|
        err("pairs: bad slug '#{e['slug']}'") unless e["slug"].to_s.match?(SLUG_RE)
        err("pairs: '#{e['slug']}' pairs with itself") if e["slug"] == @d["slug"]
        text("pairs.#{e['slug']}.why", e["why"], min: 15, max: 250)
        warn("pairs: '#{e['slug']}' is not a live stone") if @known && !@known.include?(e["slug"])
      end
      both = good.map { |e| e["slug"] } & avoid.map { |e| e["slug"] }
      err("pairs: in both good and avoid: #{both.join(',')}") if both.any?
    end

    def check_price
      enum("price.tier", @d.dig("price", "tier"), PRICE_TIERS)
      text("price.note", @d.dig("price", "note"), min: 15, max: 300)
    end

    def check_names
      n = @d["names"] || {}
      return err("names: must be a map") unless n.is_a?(Hash)

      n.each_key { |k| enum("names.#{k}", k, NAME_LANGS) }
    end

    def check_sources
      s = Array(@d["sources"])
      err("sources: need 2..8 URLs") unless s.size.between?(2, 8)
      s.each { |u| err("sources: '#{u}' is not an https URL") unless u.to_s.start_with?("https://") }
    end
  end
end
