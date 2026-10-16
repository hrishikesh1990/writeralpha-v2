# frozen_string_literal: true

# Stone Finder engine: ranks stones for one person and lists the ones to skip.
#
# Pure Ruby over AtlasEntry (or anything with the same interface: Atlas::Stone
# methods plus path and guide?). Deterministic: the same query and the same
# atlas always give the same answer, ties broken by name.
#
# How a score is built (every point is visible to the user):
#   fit = 100 * points earned / points available for the choices they made
#
#   goals        up to 40  split across chosen intentions; a stone's core
#                          purposes (first two listed) count in full, later
#                          ones 85% and 70%
#   sign         up to 19  16 (first listed sign) down to 8 for a traditional
#                          link, or 6 for a shared element, plus 3 when the
#                          sign's ruling planet is one of the stone's planets
#   birthstone   up to 8   modern list 8, traditional 7, other lists 4
#   use          up to 15  how well the stone suits the way it will be used
#   practical    4-8 each  only for the practical flags the user ticked
#   easy care    up to 10  always counted: water, toxicity, wear, sleep
#
# Hard exclusions never get a score; they go to the "skip" list with a reason.
class StoneFinder
  Reason = Data.define(:kind, :text)
  Part = Data.define(:key, :label, :points, :max)
  Pick = Data.define(:entry, :score, :fit, :reasons, :parts, :caution)
  Skip = Data.define(:entry, :score, :reasons)
  Hint = Data.define(:key, :text, :gain, :query)
  Result = Data.define(:query, :picks, :skips, :considered, :hints)

  WEIGHTS = { intentions: 40, sign: 19, birthstone: 8, use: 15, easy: 10 }.freeze
  PART_LABELS = {
    intentions: "Your goals", sign: "Your sign", birthstone: "Birthstone", use: "How you will use it",
    practical: "Your practical needs", easy: "Easy to live with"
  }.freeze
  PERSONAL_PARTS = %i[intentions sign birthstone use].freeze
  REASON_ORDER = %i[intention sign birthstone use practical easy about].freeze
  FIT_LEVELS = [[75, "Excellent fit", :good], [60, "Strong fit", :good], [45, "Good fit", :info], [0, "Partial fit", :info]].freeze

  # Mutable scratchpad for one stone while it is being evaluated.
  Evaluation = Struct.new(:entry, :parts, :reasons, :exclusions) do
    def earned = parts.sum(&:points)
    def possible = parts.sum(&:max)
    def personal = parts.select { |p| PERSONAL_PARTS.include?(p.key) }.sum(&:points)
    def part(key) = parts.find { |p| p.key == key }

    def score
      return 0 if possible.zero?

      (100.0 * earned / possible).round.clamp(0, 100)
    end
  end

  def self.call(entries, query = nil, limit: 6, **opts) = new(entries).call(query || Query.new(**opts), limit: limit)

  def self.fit_level(score)
    FIT_LEVELS.find { |min, _, _| score >= min }.then { |_, label, tone| [label, tone] }
  end

  attr_reader :entries

  def initialize(entries)
    @entries = Array(entries)
  end

  def call(query, limit: 6, hints: true)
    evaluated = entries.map { |e| evaluate(e, query) }
    ranked = ->(list) { list.sort_by { |ev| [-ev.score, ev.entry.name.to_s] } }

    picks = ranked.(evaluated.select { |ev| ev.exclusions.empty? && relevant?(ev, query) })
    skips = ranked.(evaluated.select { |ev| ev.exclusions.any? && (relevant?(ev, query) || sign_skip?(ev)) })
    hint_list = hints && picks.size < 3 ? relax_hints(query) : []

    Result.new(query: query, picks: picks.first(limit).map { |ev| build_pick(ev) },
               skips: skips.map { |ev| Skip.new(entry: ev.entry, score: ev.score, reasons: ev.exclusions) },
               considered: entries.size, hints: hint_list)
  end

  # ---- Page helpers used by the embeds ------------------------------------

  # Top stones for a sign with no other inputs, plus the stones its tradition
  # advises against (from every stone's zodiac_cautions).
  def self.for_sign(entries, sign, limit: 8)
    return nil unless Atlas::ZODIAC.include?(sign.to_s)

    q = Query.new(sign: sign)
    result = call(entries, q, limit: limit)
    avoid = Array(entries).filter_map do |e|
      c = e.zodiac_cautions.find { |z| z["sign"] == sign.to_s }
      [e, c["why"].to_s] if c
    end.sort_by { |e, _| e.name.to_s }
    { picks: result.picks, avoid: avoid }
  end

  # Top stones for one intention, or the "beginner" set.
  def self.for_intention(entries, intention, limit: 6)
    return beginner_picks(entries, limit: limit) if intention == :beginners
    return [] unless Atlas::INTENTIONS.include?(intention.to_s)

    call(entries, Query.new(intentions: [intention]), limit: limit).picks
  end

  # The most versatile safe stones: water safe, daily wear, non-toxic, safe to
  # sleep near. Versatile = lists the most intentions; cheaper first on ties.
  def self.beginner_picks(entries, limit: 6)
    Array(entries)
      .select { |e| e.safety("water") == "safe" && e.safety("wear") == "daily" && e.toxicity == "none" && e.safety("sleep") != "caution" }
      .sort_by { |e| [-e.intentions.size, Vocab::TIER_RANK.fetch(e.price_tier, 9), e.name.to_s] }
      .first(limit)
  end

  # "Can <sign> wear <stone>?" status for all 12 signs, in zodiac order.
  def self.sign_statuses(entry)
    Atlas::ZODIAC.map do |sign|
      caution = entry.zodiac_cautions.find { |z| z["sign"] == sign }
      status = if entry.zodiac.include?(sign) then :recommended
               elsif caution then :advised_against
               else :neutral
               end
      { sign: sign, status: status, why: caution && caution["why"].to_s }
    end
  end

  # Cautions with physical ones first, each tagged with its basis (original order within a basis).
  def self.ordered_cautions(entry)
    list = entry.cautions.map do |c|
      { who: c["who"].to_s, why: c["why"].to_s, basis: c["basis"] == "tradition" ? "tradition" : "physical" }
    end
    list.reject { |c| c[:who].empty? && c[:why].empty? }.sort_by.with_index { |c, i| [c[:basis] == "physical" ? 0 : 1, i] }
  end

  # The single most important physical thing to know before buying.
  def self.caution_for(entry)
    if entry.toxicity == "caution" && entry.toxicity_reason.present?
      return { who: "Anyone handling or wearing it", why: entry.toxicity_reason, basis: "physical" }
    end

    physical = ordered_cautions(entry).find { |c| c[:basis] == "physical" }
    return physical if physical

    if entry.safety("water") == "avoid" then derived("Anyone who cleans it with water", entry.safety_reason("water"))
    elsif entry.safety("sleep") == "caution" then derived("Anyone sleeping near it", entry.safety_reason("sleep"))
    elsif entry.safety("wear") == "special" then derived("Anyone planning to wear it often", entry.safety_reason("wear"))
    elsif entry.safety("sun") == "avoid" then derived("Anyone displaying it in sunlight", entry.safety_reason("sun"))
    elsif entry.safety("wear") == "care" then derived("Anyone wearing it every day", entry.safety_reason("wear"))
    end
  end

  def self.derived(who, why) = why.to_s.empty? ? nil : { who: who, why: why, basis: "physical" }
  private_class_method :derived

  private

  # ---- Evaluation -----------------------------------------------------------

  def evaluate(entry, query)
    ev = Evaluation.new(entry, [], [], [])
    score_intentions(ev, query)
    score_sign(ev, query)
    score_birthstone(ev, query)
    score_use(ev, query)
    score_practical(ev, query)
    score_easy(ev)
    exclude(ev, query)
    ev
  end

  def relevant?(ev, query)
    return true unless query.personal?
    return (ev.part(:intentions)&.points || 0).positive? if query.intentions.any?

    ev.personal.positive?
  end

  def sign_skip?(ev) = ev.exclusions.any? { |r| r.kind == :zodiac }

  def part(ev, key, points, max, label = PART_LABELS[key])
    ev.parts << Part.new(key: key, label: label, points: points.to_f, max: max.to_f)
  end

  def reason(ev, kind, text) = ev.reasons << Reason.new(kind: kind, text: text)

  def score_intentions(ev, q)
    return if q.intentions.empty?

    e = ev.entry
    per = WEIGHTS[:intentions].to_f / q.intentions.size
    matched = []
    core = []
    points = 0.0
    q.intentions.each do |i|
      idx = e.intentions.index(i) or next
      matched << i
      core << i if idx < 2
      points += per * (idx < 2 ? 1.0 : idx < 4 ? 0.85 : 0.7)
    end
    part(ev, :intentions, points, WEIGHTS[:intentions])
    return if matched.empty?

    names = matched.map { |i| Vocab.intention_name(i) }
    text =
      if q.intentions.size > 1 && matched.size == q.intentions.size
        "Covers all #{matched.size} of your goals: #{Vocab.list_phrase(names)}"
      elsif q.intentions.size > 1
        "Traditionally used for #{Vocab.list_phrase(names)} (#{matched.size} of your #{q.intentions.size} goals)"
      else
        "Traditionally used for #{names.first}#{core.any? ? ', one of its core purposes' : ''}"
      end
    reason(ev, :intention, text)
  end

  def score_sign(ev, q)
    return unless q.sign

    e = ev.entry
    pts = 0.0
    label = Vocab.sign_name(q.sign)
    if (idx = e.zodiac.index(q.sign))
      pts += 16 - 2 * idx
      reason(ev, :sign, "Traditionally linked to #{label}#{idx.zero? ? ', one of its main signs' : ''}")
    elsif q.element && e.elements.include?(q.element)
      pts += 6
      reason(ev, :sign, "Shares the #{q.element} element of #{label}")
    end
    ruler = Atlas::Astro::SIGN_RULER[q.sign]
    if ruler && e.planets.include?(ruler)
      pts += 3
      reason(ev, :sign, "Linked to #{ruler.capitalize}, the planet that rules #{label}")
    end
    part(ev, :sign, pts, WEIGHTS[:sign])
  end

  def score_birthstone(ev, q)
    return unless q.month

    e = ev.entry
    name = Atlas::MONTHS[q.month - 1]
    bm = e.birth_months
    pts, list =
      if Array(bm["modern"]).include?(name) then [8, "the modern list"]
      elsif Array(bm["traditional"]).include?(name) then [7, "the traditional list"]
      elsif Array(bm["other"]).include?(name) then [4, "other birthstone lists"]
      else [0, nil]
      end
    reason(ev, :birthstone, "A #{name.capitalize} birthstone (#{list})") if pts.positive?
    part(ev, :birthstone, pts, WEIGHTS[:birthstone])
  end

  def score_use(ev, q)
    return unless q.use

    e = ev.entry
    pts, text =
      case q.use
      when "wear"
        verdict = e.safety("wear")
        base = verdict == "daily" ? 9 : verdict == "care" ? 4 : 0
        hard = e.mohs_min >= 7 ? 6 : e.mohs_min >= 6 ? 3 : 0
        [base + hard, verdict == "daily" ? "Rated for daily wear (Mohs #{e.mohs_label})" : nil]
      when "sleep"
        calm = { "calming" => 15, "grounding" => 12, "balancing" => 9 }.fetch(e.energy.to_s, 4)
        pts = e.safety("sleep") == "ok" ? calm : 0
        [pts, pts >= 9 ? "Safe to sleep near, and tradition calls it #{e.energy}" : (pts.positive? ? "Safe to sleep near" : nil)]
      when "meditate"
        base = { "calming" => 12, "balancing" => 12, "grounding" => 10, "energizing" => 4 }.fetch(e.energy.to_s, 6)
        bonus = (e.intentions & %w[spiritual-growth intuition peace-calm clarity]).any? ? 3 : 0
        [base + bonus, bonus.positive? ? "A #{e.energy} stone, traditionally used for #{Vocab.list_phrase((e.intentions & %w[spiritual-growth intuition peace-calm clarity]).first(2).map { |i| Vocab.intention_name(i) })}" : nil]
      when "home"
        sun = { "safe" => 8, "limit" => 4 }.fetch(e.safety("sun").to_s, 0)
        pts = sun + (e.mohs_min >= 5 ? 4 : 0) + (e.safety("water") == "safe" ? 3 : 0)
        [pts, e.safety("sun") == "safe" ? "Stands up to a sunny shelf or windowsill" : (e.mohs_min >= 5 ? "Tough enough to live on a desk" : nil)]
      when "gift"
        pts = (e.toxicity == "none" ? 6 : 0) + { "daily" => 4, "care" => 2 }.fetch(e.safety("wear").to_s, 0) +
              (e.safety("sleep") == "ok" ? 2 : 0) + (%w[budget mid].include?(e.price_tier) ? 3 : 0)
        [pts, pts >= 11 ? "A no-surprises gift: non-toxic and easy to care for" : nil]
      end
    reason(ev, :use, text) if text
    part(ev, :use, pts, WEIGHTS[:use])
  end

  def score_practical(ev, q)
    return if q.flags.empty?

    e = ev.entry
    pts = 0.0
    max = 0.0
    if q.flag?("water")
      max += 5
      w = e.safety("water")
      pts += w == "safe" ? 5 : w == "brief" ? 2 : 0
      reason(ev, :practical, "Safe to rinse or cleanse with water") if w == "safe"
    end
    if q.flag?("sensitive")
      max += 8
      pts += { "calming" => 8, "grounding" => 8, "balancing" => 5 }.fetch(e.energy.to_s, 0)
      reason(ev, :practical, "A gentle stone: tradition calls it #{e.energy}") if %w[calming grounding].include?(e.energy)
    end
    if q.flag?("kids")
      max += 4
      pts += e.toxicity == "none" ? 4 : e.toxicity == "low" ? 1 : 0
      reason(ev, :practical, "Non-toxic, so lower worry around children and pets") if e.toxicity == "none"
    end
    part(ev, :practical, pts, max)
  end

  def score_easy(ev)
    e = ev.entry
    pts = 0.0
    traits = []
    case e.safety("water")
    when "safe" then pts += 3; traits << "safe in water"
    when "brief" then pts += 1
    end
    case e.toxicity
    when "none" then pts += 3; traits << "non-toxic"
    when "low" then pts += 1
    end
    case e.safety("wear")
    when "daily" then pts += 2; traits << "tough enough for daily wear"
    when "care" then pts += 1
    end
    if e.safety("sleep") == "ok" then pts += 2; traits << "safe to sleep near" end
    part(ev, :easy, pts, WEIGHTS[:easy])
    reason(ev, :easy, "Easy to live with: #{Vocab.list_phrase(traits)}") if pts >= 8
  end

  # ---- Hard exclusions ------------------------------------------------------

  def exclude(ev, q)
    e = ev.entry
    name = e.name
    out = ev.exclusions

    if q.budget && (rank = Vocab::TIER_RANK[e.price_tier]) && rank > Vocab::TIER_RANK[q.budget]
      out << Reason.new(kind: :setting, text: "Usually priced in the #{e.price_tier} tier, which is above the #{Vocab::BUDGETS[q.budget][:label].downcase} budget you chose.")
    end

    if q.flag?("water") && e.safety("water") == "avoid"
      out << Reason.new(kind: :safety, text: "You cleanse with water, and #{name} should not get wet. #{Vocab.first_sentence(e.safety_reason('water'))}")
    end

    if q.flag?("kids")
      if e.toxicity == "caution"
        out << Reason.new(kind: :safety, text: "Not advised with children or pets at home. #{Vocab.first_sentence(e.toxicity_reason)}")
      end
      if e.safety("sleep") == "caution"
        out << Reason.new(kind: :safety, text: "Flagged with a caution for children and pets nearby. #{Vocab.first_sentence(e.safety_reason('sleep'))}")
      end
      if e.safety("wear") == "special"
        out << Reason.new(kind: :safety, text: "Too fragile to leave within reach of children or pets. #{Vocab.first_sentence(e.safety_reason('wear'))}")
      end
    end

    if q.use == "wear" && %w[care special].include?(e.safety("wear"))
      lead = e.safety("wear") == "special" ? "Not suited to daily wear" : "Needs care, so it is not the best fit for daily wear"
      out << Reason.new(kind: :safety, text: "#{lead}. #{Vocab.first_sentence(e.safety_reason('wear'))}")
    end

    if q.use == "sleep" && e.safety("sleep") == "caution"
      out << Reason.new(kind: :safety, text: "Not advised for sleeping with it. #{Vocab.first_sentence(e.safety_reason('sleep'))}")
    end

    if q.sign && (z = e.zodiac_cautions.find { |c| c["sign"] == q.sign })
      out << Reason.new(kind: :zodiac, text: "Astrological tradition (mostly Vedic) advises #{Vocab.sign_name(q.sign)} against #{name}. #{z['why']}".strip)
    end

    if e.energy == "energizing"
      triggers = []
      calm = q.intentions & Vocab::CALM_INTENTIONS
      triggers << "your goals of #{Vocab.list_phrase(calm.map { |i| Vocab.intention_name(i) })}" if calm.any? && (q.intentions & Vocab::LIVELY_INTENTIONS).empty?
      triggers << "sleeping with it" if q.use == "sleep"
      triggers << "being sensitive to strong energy" if q.flag?("sensitive")
      if triggers.any?
        out << Reason.new(kind: :tradition, text: "Crystal tradition calls #{name} energizing, which works against #{triggers.join(', and against ')}.")
      end
    end
  end

  # ---- Output ---------------------------------------------------------------

  def build_pick(ev)
    reasons = ev.reasons.sort_by.with_index { |r, i| [REASON_ORDER.index(r.kind) || 9, i] }.first(4)
    if reasons.size < 2 && (about = Vocab.first_sentence(ev.entry.summary)).present?
      reasons << Reason.new(kind: :about, text: about)
    end
    fit, tone = self.class.fit_level(ev.score)
    Pick.new(entry: ev.entry, score: ev.score, fit: { label: fit, tone: tone }, reasons: reasons,
             parts: ev.parts.select { |p| p.max.positive? }, caution: self.class.caution_for(ev.entry))
  end

  # How many more stones would fit if one constraint were dropped.
  def relax_hints(query)
    base = call(query, limit: 999, hints: false).picks.size
    texts = {
      budget: "Raise your budget", use: "Leave out how you will use it",
      water: "Cleanse without water (smoke, sound or moonlight suit every stone)",
      kids: "Include stones that need more care around children and pets",
      sensitive: "Include the stones tradition calls energizing"
    }
    keys = []
    keys << :budget if query.budget
    keys << :use if query.use
    keys.concat(query.flags.map(&:to_sym))
    keys.filter_map do |key|
      relaxed = query.without(key)
      gain = call(relaxed, limit: 999, hints: false).picks.size - base
      Hint.new(key: key, text: texts[key], gain: gain, query: relaxed) if gain.positive?
    end.sort_by { |h| [-h.gain, h.key.to_s] }.first(3)
  end
end
