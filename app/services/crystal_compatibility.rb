# frozen_string_literal: true

# Crystal Compatibility engine. Pure Ruby over Atlas::Stone (or anything that
# delegates to one, such as AtlasEntry); no view code, no database.
#
#   CrystalCompatibility.check("amethyst", "rose-quartz")            # => Result
#   CrystalCompatibility.check(a, b, context: "bedroom")
#   CrystalCompatibility.best_partners("amethyst", limit: 6)         # => [Result, ...] (never :avoid)
#   CrystalCompatibility.avoid_partners("amethyst")                  # => [Result, ...] (only :avoid)
#   CrystalCompatibility.matrix(%w[amethyst selenite malachite])     # => Matrix
#
# The verdict is built from tradition (curated pairings in the Atlas, shared
# intentions, chakras, elements, energy tone) and Vedic planetary friendship.
# Physical facts (hardness, cleansing, toxicity) are returned as *practical*
# reasons: they are shown next to the verdict but never change its score.
class CrystalCompatibility
  VERDICTS = {
    great: { label: "Great together", min: 76, tone: :good },
    good: { label: "Works well", min: 66, tone: :good },
    neutral: { label: "Neutral", min: 40, tone: :info },
    avoid: { label: "Traditionally not paired", min: 0, tone: :bad }
  }.freeze

  CONTEXTS = {
    "bracelet" => { label: "Bracelet or jewellery", blurb: "Worn together on the body" },
    "bedroom" => { label: "Bedroom & sleep", blurb: "On a nightstand or under a pillow" },
    "meditation" => { label: "Meditation", blurb: "Held or placed around you" },
    "pocket" => { label: "Pocket or bag", blurb: "Carried loose" }
  }.freeze
  CONTEXT_ALIASES = {
    "sleep" => "bedroom", "bed" => "bedroom", "bedroom-sleep" => "bedroom", "sleeping" => "bedroom",
    "jewellery" => "bracelet", "jewelry" => "bracelet", "necklace" => "bracelet", "ring" => "bracelet",
    "bag" => "pocket", "carry" => "pocket", "meditate" => "meditation"
  }.freeze

  CHAKRA_ORDER = Atlas::CHAKRAS
  # Traditional element scheme: fire and air feed each other, earth and water
  # support each other; fire/water and air/earth pull against each other.
  ELEMENT_SUPPORT = [%w[air fire], %w[earth water]].freeze
  ELEMENT_CLASH = [%w[fire water], %w[air earth]].freeze
  MEDITATION_INTENTIONS = %w[concentration spiritual-growth intuition peace-calm clarity].freeze

  # sign: :plus (why they work), :minus (watch out), :neutral (good to know),
  #       :practical (physical care; never changes the score)
  # basis: :tradition, :vedic or :physical
  # tone:  :good, :warn, :info (drives the icon and colour in the views)
  Reason = Struct.new(:sign, :basis, :topic, :text, :points, :source, :tone, :brief, keyword_init: true) do
    def plus? = sign == :plus
    def minus? = sign == :minus
    def practical? = sign == :practical
    def neutral? = sign == :neutral
  end

  Cleanse = Struct.new(:shared, :blocked, keyword_init: true) # shared: [method keys]; blocked: [{method:, who: [{stone:, verdict:, reason:}]}]
  VedicCheck = Struct.new(:status, :grahas, :asymmetric, :primary, keyword_init: true) # status: :enemy :friend :same :neutral :n_a; primary: [bool, bool] (main Navaratna stone vs substitute)

  Result = Struct.new(:a, :b, :score, :verdict, :reasons, :cleanse, :vedic, :context, :headline, :summary,
                      :contested, :forced, keyword_init: true) do
    def label = VERDICTS.fetch(verdict)[:label]
    def tone = VERDICTS.fetch(verdict)[:tone]
    def contested? = contested
    def forced? = forced
    def plus = reasons.select(&:plus?)
    def minus = reasons.select(&:minus?)
    def neutral = reasons.select(&:neutral?)
    def practical = reasons.select(&:practical?)
    def avoid? = verdict == :avoid
    def names = [a.name, b.name]
    def slugs = [a.slug, b.slug]
    def top_reason = plus.max_by { |r| r.points.to_i }
    def explicit_good? = reasons.any? { |r| r.topic == :pairing && r.plus? }
    def explicit_avoid? = reasons.any? { |r| r.topic == :pairing && r.minus? }
    def other(stone) = stone.slug == a.slug ? b : a
  end

  Matrix = Struct.new(:stones, :results, :score, :verdict, :worst, keyword_init: true) do
    def label = VERDICTS.fetch(verdict)[:label]
    def tone = VERDICTS.fetch(verdict)[:tone]
    def cell(x, y)
      return nil if x.slug == y.slug

      results.find { |r| (r.a.slug == x.slug && r.b.slug == y.slug) || (r.a.slug == y.slug && r.b.slug == x.slug) }
    end
    def store_apart = results.select { |r| r.practical.any? { |p| p.topic == :hardness && p.tone == :warn } }
  end

  class << self
    def check(a, b, context: nil)
      a = resolve(a)
      b = resolve(b)
      return nil if a.nil? || b.nil? || a.slug == b.slug

      Evaluation.new(a, b, normalize_context(context)).call
    end

    def best_partners(stone, limit: 6, among: nil, context: nil)
      partner_report(stone, limit: limit, among: among, context: context).best
    end

    def avoid_partners(stone, among: nil, context: nil)
      partner_report(stone, among: among, context: context).avoid
    end

    # best + avoid lists from a single pass over the candidates (use this when
    # you need both: each check costs about a millisecond).
    PartnerReport = Struct.new(:best, :avoid, keyword_init: true)

    def partner_report(stone, limit: 6, among: nil, context: nil)
      me = resolve(stone)
      all = rank_against(stone, among, context)
      best = all.reject(&:avoid?).sort_by { |r| [-r.score, r.explicit_good? ? 0 : 1, r.other(me).name] }.first(limit.to_i.clamp(0, 100))
      avoid = all.select(&:avoid?).sort_by { |r| [r.score, r.other(me).name] }
      PartnerReport.new(best: best, avoid: avoid)
    end

    # Pairwise results for 2-4 stones.
    def matrix(stones, context: nil)
      list = Array(stones).filter_map { |s| resolve(s) }.uniq(&:slug).first(4)
      results = list.combination(2).filter_map { |x, y| check(x, y, context: context) }
      return Matrix.new(stones: list, results: [], score: nil, verdict: nil, worst: nil) if results.empty?

      scores = results.map(&:score)
      score = ((scores.sum.to_f / scores.size + scores.min) / 2).round
      worst = results.min_by(&:score)
      verdict = results.any?(&:avoid?) ? :avoid : verdict_for(score)
      Matrix.new(stones: list, results: results, score: score, verdict: verdict, worst: worst)
    end

    # Pairs the atlas says to keep apart (curated avoid lists and Vedic enemies).
    def known_conflicts(stones = nil, limit: 8)
      list = (stones || Atlas.stones).filter_map { |s| resolve(s) }
      by_slug = list.index_by(&:slug)
      pairs = {}
      list.each do |s|
        s.pairs_avoid.each do |p|
          o = by_slug[p["slug"]]
          pairs[[s.slug, o.slug].sort] = [s, o] if o
        end
      end
      vedic = list.select(&:vedic_planet)
      vedic.combination(2).each do |x, y|
        pairs[[x.slug, y.slug].sort] ||= [x, y] if Atlas::Vedic.mutual(x.vedic_planet, y.vedic_planet) == :enemy
      end
      found = pairs.values.filter_map { |x, y| check(x, y) }.select(&:avoid?)
      # Pairs of main Navaratna stones first (the classic prohibitions), then by score.
      found.sort_by { |r| [-Array(r.vedic.primary).count(true), r.score, r.a.name] }.first(limit)
    end

    # "lapis-lazuli-and-amethyst-together" => ["lapis-lazuli", "amethyst"]. Stone
    # slugs contain hyphens, so try every "-and-" split against known slugs.
    def split_pair_slug(slug, known = Atlas.slugs)
      middle = slug.to_s[/\A(.+)-together\z/, 1]
      return nil unless middle

      known = known.to_a
      idx = 0
      while (i = middle.index("-and-", idx))
        left = middle[0...i]
        right = middle[(i + 5)..]
        return [left, right] if known.include?(left) && known.include?(right) && left != right

        idx = i + 1
      end
      nil
    end

    def normalize_context(value)
      key = value.to_s.strip.downcase
      key = CONTEXT_ALIASES.fetch(key, key)
      CONTEXTS.key?(key) ? key : nil
    end

    def verdict_for(score)
      VERDICTS.find { |_, v| score >= v[:min] }.first
    end

    def graha_name(key)
      g = Atlas::Vedic::GRAHAS[key.to_s] or return key.to_s.capitalize
      g[:en]
    end

    # Accepts a slug, an Atlas::Stone or an AtlasEntry.
    def resolve(x)
      return nil if x.nil?
      return Atlas[x] if x.is_a?(String) || x.is_a?(Symbol)

      x.respond_to?(:slug) && x.respond_to?(:pairs_good) ? x : nil
    end

    private

    def rank_against(stone, among, context)
      s = resolve(stone)
      return [] unless s

      ctx = normalize_context(context)
      (among || Atlas.stones).filter_map { |o| check(s, o, context: ctx) }
    end
  end

  # One A-B evaluation. Kept private to the engine: callers use .check.
  class Evaluation
    BASE = 50
    VEDIC_ENEMY_CAP = 24
    EXPLICIT_AVOID_CAP = 38
    CONTESTED_CAP = 55

    def initialize(a, b, context)
      @a = a
      @b = b
      @ctx = context
      @reasons = []
      @vedic = CrystalCompatibility::VedicCheck.new(status: :n_a, grahas: [], asymmetric: false)
      @contested = false
      @forced = nil
    end

    def call
      explicit_pairs
      vedic
      intentions
      chakras
      elements
      energy
      context_tradition
      practical
      finish
    end

    private

    attr_reader :a, :b, :ctx

    def name(s) = s.name
    def both = "#{a.name} and #{b.name}"
    def list(items) = items.to_sentence(two_words_connector: " and ", last_word_connector: ", and ")
    def label_for(intent) = Atlas::INTENTION_LABELS.fetch(intent, intent.to_s.humanize)
    def chakra(c) = Atlas::CHAKRA_LABELS.fetch(c, c.to_s.humanize)

    def add(sign, basis, topic, text, points = 0, source: nil, tone: nil, brief: nil)
      tone ||= { plus: :good, minus: :warn, neutral: :info, practical: :info }[sign]
      @reasons << CrystalCompatibility::Reason.new(sign:, basis:, topic:, text:, points:, source:, tone:, brief:)
    end

    # ---- Tradition: curated pairs ------------------------------------------

    def classify(why)
      t = why.to_s
      return :vedic if t.match?(/vedic|jyotish|graha|planetary/i)
      return :tradition if t.match?(/tradition|energy|energi|chakra|aura|vibration/i)
      return :physical if t.match?(/scratch|dissolv|soluble|\bwater\b|\bsun\b|sunlight|cleans|rust|toxic|leach|corrod|harder|softer|care rules/i)

      :tradition
    end

    def explicit_pairs
      good = [[a, b], [b, a]].filter_map { |from, to| (p = from.pairs_good.find { |x| x["slug"] == to.slug }) && [from, p] }
      bad = [[a, b], [b, a]].filter_map { |from, to| (p = from.pairs_avoid.find { |x| x["slug"] == to.slug }) && [from, p] }

      seen = []
      good.each_with_index do |(from, p), i|
        why = p["why"].to_s.strip
        next if seen.include?(why)

        seen << why
        add(:plus, classify(why), :pairing, why, i.zero? ? (good.size > 1 ? 30 : 22) : 0, source: "Listed in #{from.name}'s pairings")
      end

      seen = []
      bad.each_with_index do |(from, p), i|
        why = p["why"].to_s.strip
        next if seen.include?(why)

        seen << why
        basis = classify(why)
        if basis == :physical
          add(:practical, :physical, :pairing, why, 0, source: "Listed in #{from.name}'s pairings", tone: :warn)
        else
          add(:minus, basis, :pairing, why, i.zero? ? (bad.size > 1 ? -40 : -30) : 0, source: "Listed in #{from.name}'s pairings", tone: :warn)
          @forced = :explicit
        end
      end

      if @forced == :explicit && good.any?
        @contested = true
        who_good = good.first.first
        who_bad = bad.first.first
        add(:neutral, :tradition, :contested,
            "The atlas entries disagree here: #{who_good.name}'s entry recommends the pairing, while #{who_bad.name}'s entry says to keep them apart. We have scored the middle ground, and the reason for each is shown above.")
      end
    end

    # ---- Vedic -----------------------------------------------------------------

    def vedic_role(stone, graha)
      info = Atlas::Vedic::NAVARATNA[graha]
      return nil unless info && info[:substitutes].include?(stone.slug)

      "#{stone.name} counts as a #{CrystalCompatibility.graha_name(graha)} stone in Jyotish because it is a recognised substitute (upratna) for #{info[:stone]}."
    end

    def vedic_primary?(stone)
      Atlas::Vedic::NAVARATNA.dig(stone.vedic_planet, :slug) == stone.slug
    end

    def vedic
      ga = a.vedic_planet.presence
      gb = b.vedic_planet.presence
      return unless ga && gb

      rel = Atlas::Vedic.mutual(ga, gb)
      asym = Atlas::Vedic.relation(ga, gb) != Atlas::Vedic.relation(gb, ga)
      primary = [vedic_primary?(a), vedic_primary?(b)]
      @vedic = CrystalCompatibility::VedicCheck.new(status: rel, grahas: [ga, gb], asymmetric: asym, primary: primary)
      ha = Atlas::Vedic::GRAHAS[ga][:hi]
      hb = Atlas::Vedic::GRAHAS[gb][:hi]

      case rel
      when :enemy
        text = "Vedic astrology advises against wearing #{a.name} (#{CrystalCompatibility.graha_name(ga)}) with #{b.name} (#{CrystalCompatibility.graha_name(gb)}). " \
               "In the classical friendship table (naisargika maitri), #{ha} and #{hb} are enemies."
        text += " The table is lopsided here: one planet counts the other as an enemy and the reverse is not recorded, and most practitioners take the cautious reading." if asym
        notes = [vedic_role(a, ga), vedic_role(b, gb)].compact
        text += " #{notes.join(' ')}" if notes.any?
        add(:minus, :vedic, :vedic, text, -40, tone: :warn)
        if %w[bedroom meditation].include?(ctx)
          add(:neutral, :vedic, :vedic_room,
              "This rule is about wearing both stones on the body. The classical sources are less clear about stones kept in the same room, so ask your astrologer if it matters to you.")
        end
        if primary.none?
          add(:neutral, :vedic, :vedic_substitute,
              "Both are substitute stones (upratna), not the main Navaratna gems. Many astrologers treat substitutes as milder, so some are more relaxed about combining them. The rule is still the traditional default, so ask your astrologer if you wear them for planetary reasons.")
        end
        @forced = :vedic
        if @reasons.any? { |r| r.topic == :pairing && r.plus? }
          @contested = true
          add(:neutral, :tradition, :contested,
              "Crystal tradition and Vedic astrology disagree about this pair: the atlas lists it as a good combination, but the Vedic planetary rule says no. If you follow Jyotish, that rule normally wins.")
        end
      when :friend
        add(:plus, :vedic, :vedic,
            "In Vedic astrology their planets are friends: #{ha} and #{hb} are listed as friendly grahas, so astrologers do not object to wearing the two together.", 12)
      when :same
        add(:plus, :vedic, :vedic,
            "Both stones stand for the same planet in Vedic astrology (#{CrystalCompatibility.graha_name(ga)}), so they pull the same way. Astrologers usually pick stones to match a chart, so check with one if you wear them for planetary reasons.", 3)
      else
        add(:neutral, :vedic, :vedic,
            "Their planets (#{CrystalCompatibility.graha_name(ga)} and #{CrystalCompatibility.graha_name(gb)}) are neither friends nor enemies in the classical table, so Vedic astrology raises no objection.")
      end
    end

    # ---- Tradition: intentions, chakras, elements, energy ------------------

    def intentions
      shared = a.intentions & b.intentions
      if shared.any?
        pts = { 1 => 3, 2 => 6, 3 => 9 }.fetch(shared.size, 11)
        labels = shared.map { |i| label_for(i) }
        add(:plus, :tradition, :intentions,
            "They are used for the same things: #{list(labels)}. Two stones aimed at one goal reinforce each other in crystal tradition.", pts)
      elsif a.intentions.any? && b.intentions.any?
        mine = list(a.intentions.first(3).map { |i| label_for(i).downcase })
        theirs = list(b.intentions.first(3).map { |i| label_for(i).downcase })
        add(:neutral, :tradition, :intentions,
            "They are used for different things (#{a.name}: #{mine}; #{b.name}: #{theirs}), so each does its own job rather than reinforcing the other.")
      end
    end

    def chakras
      return if a.chakras.empty? || b.chakras.empty?

      shared = a.chakras & b.chakras
      if shared.any?
        pts = shared.size == 1 ? 4 : 6
        add(:plus, :tradition, :chakras,
            "Both work with the #{list(shared.map { |c| chakra(c) })} chakra#{'s' if shared.size > 1}, so tradition reads them as pulling in the same direction.", pts)
        return
      end

      adjacent = a.chakras.product(b.chakras).find { |x, y| (CHAKRA_ORDER.index(x).to_i - CHAKRA_ORDER.index(y).to_i).abs == 1 }
      if adjacent
        add(:plus, :tradition, :chakras,
            "Their chakras sit next to each other (#{chakra(adjacent[0])} and #{chakra(adjacent[1])}), which tradition reads as complementary.", 2)
      else
        add(:neutral, :tradition, :chakras,
            "They work with different chakras (#{a.name}: #{list(a.chakras.map { |c| chakra(c) })}; #{b.name}: #{list(b.chakras.map { |c| chakra(c) })}). Tradition does not treat that as a clash.")
      end
    end

    def elements
      return if a.elements.empty? || b.elements.empty?

      same = []
      support = []
      clash = []
      a.elements.each do |x|
        b.elements.each do |y|
          pair = [x, y].sort
          if x == y then same << x
          elsif ELEMENT_SUPPORT.include?(pair) then support << [x, y]
          elsif ELEMENT_CLASH.include?(pair) then clash << [x, y]
          end
        end
      end
      good_n = same.size + support.size
      pts = ((good_n - clash.size) * 4).clamp(-5, 6)
      desc = ->(pairs) { list(pairs.map { |x, y| "#{x.capitalize} and #{y.capitalize}" }) }

      parts = []
      parts << "both carry #{list(same.map(&:capitalize))}, so they reinforce each other" if same.any?
      parts << "#{desc.call(support)} support each other" if support.any?
      parts << "#{desc.call(clash)} pull against each other" if clash.any?
      return if parts.empty?

      if good_n.positive? && clash.empty?
        add(:plus, :tradition, :elements, "In the traditional element scheme #{parts.join('; ')}.", pts)
      elsif clash.any? && good_n.zero?
        add(:minus, :tradition, :elements, "In the traditional element scheme #{parts.join('; ')}. It is a soft clash rather than a ban, and many people pair them anyway.", pts)
      else
        add(:neutral, :tradition, :elements, "The element scheme pulls both ways: #{parts.join('; ')}. Tradition treats this as roughly even.", pts)
      end
    end

    def energy
      ea = a.energy
      eb = b.energy
      return if ea.blank? || eb.blank?

      kinds = [ea, eb].sort
      sleepish = %w[bedroom meditation].include?(ctx)
      if ea == eb
        if ea == "energizing" && ctx == "bedroom"
          add(:minus, :tradition, :energy, "Both are energising stones in tradition, which is a lot for a bedroom. Tradition keeps energising stones out of the room where you sleep.", -8)
        else
          add(:plus, :tradition, :energy, "Both are #{ea} stones in tradition, so their tone matches.", 2)
        end
      elsif kinds == %w[calming energizing]
        calm, spark = ea == "calming" ? [a, b] : [b, a]
        if sleepish
          what = ctx == "bedroom" ? "sleep" : "meditation"
          add(:minus, :tradition, :energy,
              "#{calm.name} is calming and #{spark.name} is energising. Tradition says that mix works against #{what}, which wants one steady tone. Keep #{spark.name} for the day.", -14)
        elsif %w[bracelet pocket].include?(ctx)
          add(:plus, :tradition, :energy,
              "Calming plus energising is the classic daytime balance in crystal tradition: #{calm.name} takes the edge off, #{spark.name} keeps you moving.", 2)
        else
          add(:minus, :tradition, :energy,
              "#{calm.name} is calming and #{spark.name} is energising. Tradition treats that as fine for daytime balance, but not the pair to put by your bed or use for meditation.", -6)
        end
      else
        anchor = [a, b].find { |s| %w[grounding balancing].include?(s.energy) }
        other = anchor.equal?(a) ? b : a
        verb = anchor.energy == "grounding" ? "anchors" : "evens out"
        add(:plus, :tradition, :energy, "#{anchor.name} is #{anchor.energy} in tradition, so it #{verb} the #{other.energy} tone of #{other.name}.", 1)
        if ctx == "bedroom" && other.energy == "energizing"
          add(:minus, :tradition, :energy, "#{other.name} is an energising stone, and tradition keeps those out of the bedroom.", -4)
        end
      end
    end

    def context_tradition
      case ctx
      when "meditation"
        shared = (a.intentions & b.intentions) & MEDITATION_INTENTIONS
        if shared.any?
          add(:plus, :tradition, :context, "Both are used for #{list(shared.map { |i| label_for(i).downcase })}, which suits meditation.", 3)
        end
      when "bedroom"
        if (a.intentions & b.intentions).include?("sleep")
          add(:plus, :tradition, :context, "Both are traditionally used for sleep, which suits a bedroom.", 3)
        end
      end
    end

    # ---- Practical (physical; never changes the score) ----------------------

    def mohs_text(s) = s.mohs.empty? ? "unknown" : s.mohs_label
    def mid(s) = s.mohs.empty? ? nil : (s.mohs_min + s.mohs_max) / 2.0

    def practical
      hardness
      cleansing
      elixirs
      context_practical
    end

    def hardness
      ma = mid(a)
      mb = mid(b)
      return unless ma && mb

      harder, softer = ma >= mb ? [a, b] : [b, a]
      diff = (ma - mb).abs
      desc = "#{harder.name} (Mohs #{harder.mohs_label}) will scratch #{softer.name} (Mohs #{softer.mohs_label})"
      if diff >= 2
        extra = case ctx
                when "bracelet" then " On one bracelet the harder stone wears the softer every time you move your wrist, so pick a partner closer in hardness or wear them on separate pieces."
                when "pocket" then " Loose in a pocket or bag they knock together, so carry each in its own pouch."
                else " Keep them in separate pouches or compartments."
                end
        add(:practical, :physical, :hardness, "Store apart: #{desc}.#{extra}", 0, tone: :warn,
            brief: "#{harder.name} will scratch #{softer.name}, so keep them in separate pouches")
      elsif diff >= 1
        add(:practical, :physical, :hardness, "Close in hardness (Mohs #{a.mohs_label} and #{b.mohs_label}), but #{harder.name} can still mark #{softer.name} over time. A soft cloth between them helps.", 0, tone: :info)
      else
        add(:practical, :physical, :hardness, "Similar hardness (Mohs #{a.mohs_label} and #{b.mohs_label}), so they can share a pouch or a bracelet without scratching each other.", 0, tone: :good)
      end
    end

    def methods_for(stone)
      stone.safe_cleanse_methods
    rescue StandardError
      %w[smoke sound moonlight selenite breath dry_salt]
    end

    def cleansing
      shared = methods_for(a) & methods_for(b)
      blocked = []
      who = lambda do |key, test|
        [a, b].filter_map do |s|
          v = s.safety(key)
          { stone: s, verdict: v, reason: s.safety_reason(key) } if test.call(v)
        end
      end

      water = who.call("water", ->(v) { v != "safe" })
      blocked << { method: "water", who: water } if water.any?

      salt = who.call("salt", ->(v) { v != "safe" })
      salt = water if salt.empty? && water.any?
      blocked << { method: "salt_water", who: salt } if salt.any?

      sun = who.call("sun", ->(v) { v != "safe" })
      blocked << { method: "sunlight", who: sun } if sun.any?

      unless shared.include?("earth")
        earth = [a, b].filter_map do |s|
          next if methods_for(s).include?("earth")

          reason = s.safety("water") == "avoid" ? "Damp soil counts as water exposure, so the water warning above applies." : "At Mohs #{mohs_text(s)} it is too soft to bury safely."
          { stone: s, verdict: nil, reason: reason }
        end
        blocked << { method: "earth", who: earth } if earth.any?
      end

      @cleanse = CrystalCompatibility::Cleanse.new(shared: shared, blocked: blocked)
      return if blocked.empty?

      skip = blocked.map do |bl|
        label = Atlas::Stone::CLEANSE_METHODS[bl[:method]].to_s.sub(/ \(.*\)/, "").downcase
        label = "long sun exposure" if bl[:method] == "sunlight" && bl[:who].all? { |w| w[:verdict] == "limit" }
        "#{label} (#{list(bl[:who].map { |w| w[:stone].name }.uniq)})"
      end
      add(:practical, :physical, :cleanse,
          "If you cleanse them together, skip #{list(skip)}. Smoke, sound, moonlight, or resting on selenite or clear quartz work for both.", 0, tone: :warn,
          brief: "if you cleanse them together, skip #{list(skip)}")
    end

    def elixirs
      toxic = [a, b].find { |s| s.toxicity == "caution" }
      low = [a, b].find { |s| s.toxicity == "low" }
      never = [a, b].find { |s| s.elixir == "never" }
      if toxic
        add(:practical, :physical, :elixir, "Don't make a shared elixir or put either stone in drinking water. #{toxic.name}: #{toxic.toxicity_reason}", 0, tone: :warn,
            brief: "don't make a shared elixir, because #{toxic.name} is a toxicity caution")
      elsif low
        add(:practical, :physical, :elixir, "Skip the shared elixir, because #{low.name} is a low-toxicity stone. #{low.name}: #{low.toxicity_reason}", 0, tone: :warn,
            brief: "skip the shared elixir")
      elsif never
        add(:practical, :physical, :elixir, "Don't make a shared elixir. #{never.name}: #{never.safety_reason('water')}", 0, tone: :warn,
            brief: "don't make a shared elixir, because #{never.name} should never sit in water")
      end
    end

    def context_practical
      case ctx
      when "bedroom"
        [a, b].each do |s|
          next unless s.safety("sleep") == "caution"

          add(:practical, :physical, :sleep, "For the bedroom, #{s.name}: #{s.safety_reason('sleep')}", 0, tone: :warn)
        end
      when "bracelet", "pocket"
        [a, b].each do |s|
          case s.safety("wear")
          when "special"
            add(:practical, :physical, :wear, "#{s.name} is only for occasional wear. #{s.safety_reason('wear')}", 0, tone: :warn)
          when "care"
            add(:practical, :physical, :wear, "#{s.name} needs care when worn. #{s.safety_reason('wear')}", 0, tone: :info)
          end
        end
        if ctx == "bracelet"
          [a, b].each do |s|
            next if s.safety("water") == "safe"

            add(:practical, :physical, :water, "Bracelets get wet. #{s.name}: #{s.safety_reason('water')}", 0, tone: :warn)
          end
        end
      end
    end

    # ---- Verdict -------------------------------------------------------------

    def first_sentence(text) = text.to_s[/\A.*?[.!?](?=\s|\z)/m] || text.to_s

    def finish
      # A curated Vedic avoid that the planetary table already explains is one
      # warning, not two: keep both texts, count the penalty once.
      if @vedic.status == :enemy
        @reasons.each { |r| r.points = 0 if r.topic == :pairing && r.minus? && r.basis == :vedic }
      end
      raw = @reasons.sum { |r| r.points.to_i }
      # Both directions saturate: overlapping traditions are correlated, so a
      # long list of matches should not read as a perfect 100, nor a pile of
      # objections as a flat 0.
      score = BASE + (raw <=> 0) * 47 * (1 - Math.exp(-raw.abs / 38.0))
      score = score.round.clamp(2, 98)
      score = [score, VEDIC_ENEMY_CAP].min if @forced == :vedic
      score = [score, EXPLICIT_AVOID_CAP].min if @forced == :explicit && !@contested
      score = [score, CONTESTED_CAP].min if @contested && @forced == :explicit
      verdict = CrystalCompatibility.verdict_for(score)
      verdict = :avoid if @forced == :vedic || (@forced == :explicit && !@contested)

      headline, summary = narrative(verdict)
      CrystalCompatibility::Result.new(
        a: a, b: b, score: score, verdict: verdict, reasons: ordered_reasons, cleanse: @cleanse, vedic: @vedic,
        context: ctx, headline: headline, summary: summary, contested: @contested, forced: @forced
      )
    end

    ORDER = { plus: 0, minus: 1, neutral: 2, practical: 3 }.freeze
    def ordered_reasons
      @reasons.each_with_index.sort_by do |r, i|
        pairing = r.topic == :pairing ? 0 : 1
        vedic = r.topic == :vedic ? 0 : 1
        [ORDER[r.sign], pairing, vedic, -r.points.to_i.abs, i]
      end.map(&:first)
    end

    def narrative(verdict)
      lead = ordered_reasons
      top_plus = lead.find { |r| r.plus? && r.points.to_i.positive? }
      top_minus = lead.find { |r| r.minus? && r.points.to_i.negative? }
      headline = case verdict
                 when :great then "#{both} are a natural pair."
                 when :good then "#{both} work well together."
                 when :neutral
                   if top_plus && !top_minus then "#{both} are a mild match."
                   elsif top_minus && !top_plus then "#{both} are a slightly awkward match."
                   elsif top_plus && top_minus then "Tradition is split on #{both}."
                   else "Nothing in tradition pulls #{both} together or apart."
                   end
                 else
                   if @forced == :vedic && @contested then "Vedic astrology says no to #{both}, though crystal tradition pairs them."
                   elsif @forced == :vedic then "Vedic astrology advises against wearing #{both} together."
                   else "Tradition keeps #{both} apart."
                   end
                 end

      body =
        case verdict
        when :great, :good
          top_plus ? first_sentence(top_plus.text) : nil
        when :avoid
          main = lead.find { |r| r.minus? && %i[vedic pairing].include?(r.topic) } || lead.find(&:minus?)
          main ? first_sentence(main.text) : nil
        else
          sentences = [top_plus, top_minus].compact.map { |r| first_sentence(r.text) }
          sentences << "Nothing here is strong either way, so use each stone for its own job and combine them if you like the look." if sentences.size < 2
          sentences.join(" ")
        end
      body = [body, "Sources disagree, though: see the note below."].compact.join(" ") if @contested
      warn = lead.find { |r| r.practical? && r.tone == :warn && r.topic == :hardness } || lead.find { |r| r.practical? && r.tone == :warn }
      if warn
        note = warn.brief ? "#{warn.brief[0].upcase}#{warn.brief[1..]}" : first_sentence(warn.text)
        body = [body, "On the practical side: #{note.sub(/[.!?]\z/, '')}."].compact.join(" ")
      end
      [headline, body.to_s.strip]
    end
  end
end
