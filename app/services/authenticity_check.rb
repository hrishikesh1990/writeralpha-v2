# frozen_string_literal: true

# Scores the evidence from a home authenticity checklist for one stone.
#
# Pure Ruby, no view code. Input is an Atlas stone (anything responding to
# slug/name/tests/common_fakes/species) and a hash of test id => answer, where
# an answer is "real" (looked real), "fake" (looked fake), "unsure" (could not
# tell) or "skipped". Unknown ids and unknown values are ignored.
#
#   check = AuthenticityCheck.new(stone, "magnification" => "fake", "weight" => "real")
#   check.result.verdict        # => :imitation
#   check.result.label          # => "Signs of an imitation"
#   check.result.pointing_to    # => ["Purple glass"]
#   check.result.next_tests     # => untried, non-destructive tests, most informative first
#
# The engine never claims certainty. A "real" answer can only make a stone
# *consistent with* genuine; every result carries the "only a gemmologist (or a
# lab report) can confirm" caveat, and diamonds, rubies and sapphires also carry
# the lab-grown note.
class AuthenticityCheck
  ANSWERS = %w[real fake unsure skipped].freeze
  ANSWER_ALIASES = { "skip" => "skipped", "cant_tell" => "unsure", "cant-tell" => "unsure", "unknown" => "unsure",
                     "genuine" => "real", "imitation" => "fake" }.freeze

  VERDICTS = {
    genuine: "Consistent with genuine",
    inconclusive: "Inconclusive so far",
    imitation: "Signs of an imitation"
  }.freeze

  # Evidence points per weight. Deliberately asymmetric: failing a test is
  # strong evidence, passing one is only mild reassurance (a good fake can pass).
  # One weight-3 "fake" (6.0) outweighs several weak "real" answers.
  FAKE_POINTS = { 1 => 1.0, 2 => 2.5, 3 => 6.0 }.freeze
  REAL_POINTS = { 1 => 0.5, 2 => 1.25, 3 => 3.0 }.freeze
  IMITATION_NET = 3.0     # fake points minus real points needed for "signs of an imitation"
  GENUINE_NET = -3.0      # likewise, the other way (about three decent passes)
  STRONG_FAKE = 2.5       # a weight-2 fake answer, the point where "consistent with genuine" is off the table

  WEIGHT_LABELS = { 1 => "Weak hint", 2 => "Good evidence", 3 => "Near-conclusive" }.freeze

  TITLES = {
    "hardness" => "Hardness", "streak" => "Streak", "bubbles" => "Bubbles", "temperature" => "Temperature",
    "weight" => "Weight in the hand", "magnification" => "Magnification", "uv" => "UV light",
    "price" => "Price check", "color" => "Colour", "inclusions" => "Inclusions", "light" => "Light",
    "magnet" => "Magnet", "scratch" => "Scratch", "acetone" => "Nail-polish remover",
    "water_dissolve" => "Water", "flame" => "Hot pin", "shape" => "Shape and cut", "seller" => "Seller check",
    "certificate" => "Certificate", "refractive" => "Light bending"
  }.freeze

  # Tests that can mark, scratch, heat or stain a stone.
  DESTRUCTIVE_IDS = %w[streak scratch acetone water_dissolve flame].freeze
  DESTRUCTIVE_HOW = /\b(destructive|can chip|may chip|scratch(es|ing)?|hot pin|flame|burn(s|ing)?|acetone|nail-polish remover|knife|steel (pin|needle|file)|files?|heat(ed|ing)?)\b/i
  NON_DESTRUCTIVE_HOW = /non-destructive/i

  # Home tests cannot separate lab-grown from natural for these.
  LAB_GROWN_CAVEAT_SLUGS = %w[diamond emerald].freeze
  LAB_GROWN_CAVEAT_SPECIES = %w[corundum diamond].freeze

  CAVEAT = "Home tests are guidance, not proof. Only a gemmologist (or a lab report) can confirm what a stone is."
  LAB_GROWN_NOTE = "Lab-grown diamonds, rubies and sapphires are the same material as natural ones, so no home test can tell them apart. Only a lab report (GIA, IGI or similar) can say."

  Test = Data.define(:id, :title, :weight, :how, :real, :fake, :destructive, :position) do
    def destructive? = destructive
    def weight_label = WEIGHT_LABELS.fetch(weight)
    def to_param = id
  end

  Result = Data.define(
    :verdict, :label, :tone, :summary, :why, :pointing_to, :next_tests, :next_step, :caveat, :lab_note,
    :real_score, :fake_score, :answered, :informative, :total, :evidence, :lean
  ) do
    def genuine? = verdict == :genuine
    def inconclusive? = verdict == :inconclusive
    def imitation? = verdict == :imitation
    def started? = answered.positive?
    def progress = total.zero? ? 0 : (answered * 100.0 / total).round
  end

  # ---- Fake matching vocabulary -------------------------------------------
  FAMILIES = {
    glass: %w[glass bubble bubbles swirl swirls mould moulded mold molded paste],
    plastic: %w[plastic resin acrylic polymer epoxy reconstituted bonded bound glued composite],
    dyed: %w[dye dyed dyeing dyes stain stained bleached colored coloured],
    surface: %w[painted printed coated coating foil backed lacquered],
    lab: %w[lab-grown synthetic hydrothermal flux verneuil cultured man-made lab],
    treated: %w[heated heat-treated treated irradiated filled fracture-filled]
  }.freeze
  WORD_FAMILY = FAMILIES.flat_map { |fam, words| words.map { |w| [w, fam] } }.to_h.freeze
  TEST_FAMILY_HINTS = { "bubbles" => [:glass], "acetone" => [:dyed], "flame" => [:plastic] }.freeze
  STOPWORDS = %w[sold look looks looking like feel feels stone stones piece pieces other something between
                 natural real fake with that this from than they them which usually often very more most
                 beads bead into onto your have been also only just when does over under about
                 purple green blue red pink yellow orange white black brown clear colour color grey gray
                 violet golden silver].freeze

  attr_reader :stone, :answers

  def self.call(stone, answers = {}) = new(stone, answers).result

  # Tests ordered for doing at home: non-destructive first, then by weight
  # (most telling first), then in the Atlas file's own order.
  def self.ordered_tests(stone) = new(stone).tests

  def self.normalize_answer(value)
    v = value.to_s.strip.downcase
    v = ANSWER_ALIASES.fetch(v, v)
    ANSWERS.include?(v) ? v : nil
  end

  # Stones that are famously sold in imitation (dyed howlite as turquoise, glass as moldavite,
  # heated amethyst as citrine, ...), in the order we list them. Only those that have tests show.
  # Anything else follows, ranked by how many imitations the Atlas lists.
  HEADLINE_FAKES = %w[turquoise moldavite jade lapis-lazuli citrine diamond amethyst cats-eye opal emerald].freeze

  # "Most faked stones": the headline list first, then by number of imitations on the market
  # and whether the Atlas has a near-conclusive (weight 3) test for them.
  def self.most_faked(entries, limit: 8)
    entries.select { |e| Array(e.tests).any? }
           .sort_by do |e|
             headline = HEADLINE_FAKES.index(e.slug.to_s) || HEADLINE_FAKES.size
             strong = Array(e.tests).any? { |t| t.is_a?(Hash) && t["weight"].to_i >= 3 } ? 1.5 : 0
             [headline, -(Array(e.common_fakes).size + strong), e.name.to_s]
           end
           .first(limit)
  end

  def self.lab_grown_caveat?(stone)
    LAB_GROWN_CAVEAT_SLUGS.include?(stone.slug.to_s) || LAB_GROWN_CAVEAT_SPECIES.include?(stone.try(:species).to_s.downcase)
  end

  def initialize(stone, answers = {})
    @stone = stone
    @answers = normalize(answers)
  end

  # All usable tests for the stone, in doing order.
  def tests
    @tests ||= begin
      seen = {}
      built = Array(stone.tests).each_with_index.filter_map do |raw, i|
        next unless raw.is_a?(Hash)

        id = raw["id"].to_s
        next if id.empty? || seen[id]

        seen[id] = true
        how = raw["how"].to_s.strip
        Test.new(id:, title: TITLES.fetch(id) { id.tr("_", " ").capitalize }, weight: clamp_weight(raw["weight"]),
                 how:, real: raw["real"].to_s.strip, fake: raw["fake"].to_s.strip,
                 destructive: DESTRUCTIVE_IDS.include?(id) || (how.match?(DESTRUCTIVE_HOW) && !how.match?(NON_DESTRUCTIVE_HOW)), position: i)
      end
      built.sort_by { |t| [t.destructive? ? 1 : 0, -t.weight, t.position] }
    end
  end

  def answer_for(test_id) = answers[test_id.to_s]

  def result
    @result ||= build_result
  end

  private

  def normalize(raw)
    return {} unless raw.respond_to?(:to_h)

    hash = begin
      raw.to_h
    rescue ArgumentError, TypeError
      {}
    end
    ids = tests.map(&:id)
    hash.each_with_object({}) do |(k, v), out|
      id = k.to_s
      next unless ids.include?(id)

      a = self.class.normalize_answer(v)
      out[id] = a if a
    end
  end

  def clamp_weight(value)
    w = value.to_i
    w.clamp(1, 3)
  end

  def build_result
    by_id = tests.index_by(&:id)
    real_tests = answers.select { |_, a| a == "real" }.keys.map { |id| by_id[id] }
    fake_tests = answers.select { |_, a| a == "fake" }.keys.map { |id| by_id[id] }
    real_score = real_tests.sum { |t| REAL_POINTS[t.weight] }
    fake_score = fake_tests.sum { |t| FAKE_POINTS[t.weight] }
    informative = real_tests.size + fake_tests.size
    net = fake_score - real_score
    strong_fake = fake_tests.any? { |t| t.weight == 3 }

    verdict =
      if informative.zero? then :inconclusive
      elsif fake_score >= STRONG_FAKE && net >= IMITATION_NET && (informative >= 2 || strong_fake) then :imitation
      elsif informative >= 2 && fake_score < STRONG_FAKE && net <= GENUINE_NET && real_tests.any? { |t| t.weight >= 2 } then :genuine
      else :inconclusive
      end

    lean = if verdict != :inconclusive || informative.zero? then nil
           elsif net >= 1.0 then :imitation
           elsif net <= -1.0 then :genuine
           end

    pointing = verdict == :genuine ? [] : pointing_to(fake_tests)
    next_tests = suggest(pointing, verdict)

    Result.new(
      verdict:, label: VERDICTS.fetch(verdict), tone: tone_for(verdict),
      summary: summary_for(verdict, lean, informative, real_tests, fake_tests, pointing, net),
      why: why_lines(real_tests, fake_tests, answers),
      pointing_to: pointing, next_tests:, next_step: next_step_text(next_tests, verdict),
      caveat: CAVEAT, lab_note: (LAB_GROWN_NOTE if self.class.lab_grown_caveat?(stone)),
      real_score:, fake_score:, answered: answers.size, informative:, total: tests.size,
      evidence: evidence_level(real_tests + fake_tests), lean:
    )
  end

  def tone_for(verdict) = { genuine: :good, inconclusive: :info, imitation: :warn }.fetch(verdict)

  def evidence_level(informative_tests)
    pts = informative_tests.sum(&:weight)
    if pts.zero? then :none elsif pts <= 3 then :thin elsif pts <= 6 then :moderate else :good end
  end

  # ---- Narrative ------------------------------------------------------------

  def summary_for(verdict, lean, informative, real_tests, fake_tests, pointing, net)
    name = stone.name.to_s
    case verdict
    when :genuine
      "So far, what you have seen is consistent with a genuine #{name}. That is encouraging, but passing home tests is not proof: a well-made imitation, or a lab-grown or treated stone, can pass them too."
    when :imitation
      worst = fake_tests.max_by(&:weight)
      lead = fake_tests.size > 1 ? "Several tests looked fake" : "Your #{worst.title.downcase} result looked fake"
      base = "Your answers show signs of an imitation. #{lead}, and results like that are rarely a false alarm."
      base + " Sellers often pass these on without knowing, so ask calmly rather than accuse."
    else
      if informative.zero?
        return "Answer the first test to begin. Two or three clear answers are enough to start telling the story." if answers.empty?

        return "Nothing has been clear enough to count yet. That is common with home tests, and skipping is always fine. The tests suggested next are the most telling ones left."
      end
      return "You have one clear answer so far. We need at least two before we lean either way." if informative == 1

      case lean
      when :imitation then "The evidence leans towards an imitation, but not strongly enough to say. One more clear result would help."
      when :genuine then "The evidence leans towards a genuine stone, but not strongly enough to say. One more clear result on a stronger test would help."
      else "Your results point in different directions, which is common: some tests are hard to read at home. A stronger test should break the tie."
      end
    end
  end

  def why_lines(real_tests, fake_tests, _answers)
    lines = fake_tests.map { |t| "#{t.title} looked fake (#{t.weight_label.downcase})." }
    lines += real_tests.map { |t| "#{t.title} looked real (#{t.weight_label.downcase})." }
    lines
  end

  def next_step_text(next_tests, verdict)
    if next_tests.any?
      first = next_tests.first
      "Next most useful: #{first.title.downcase} (#{first.weight_label.downcase})."
    elsif tests.any?
      "You have been through every test we have for this stone. A gemmologist or a lab report is the next step."
    else
      "We do not have home tests for this stone yet. A gemmologist or a lab report is the way to be sure."
    end
  end

  # ---- Next tests -----------------------------------------------------------

  # Untried (no answer at all) non-destructive tests, most informative first.
  # Tests that speak to the suspected fake get a nudge up. When only
  # destructive tests are left they are offered, clearly flagged, last.
  def suggest(pointing, verdict)
    untried = tests.reject { |t| answers.key?(t.id) }
    suspect_families = pointing.flat_map { |name| families_of(name) }.uniq
    ranked = untried.sort_by do |t|
      bonus = (families_of(t.fake, t.id) & suspect_families).any? ? 0.75 : 0
      [t.destructive? ? 1 : 0, -(t.weight + bonus), t.position]
    end
    safe = ranked.reject(&:destructive?)
    safe.any? ? safe.first(3) : ranked.first(2)
  end

  # ---- Which common fake does the pattern point to? --------------------------

  def pointing_to(fake_tests)
    return [] if fake_tests.empty?

    fakes = Array(stone.common_fakes).map(&:to_s).reject(&:empty?)
    stone_words = tokens(stone.name.to_s) + Array(stone.try(:aka)).flat_map { |a| tokens(a.to_s) }
    scored = fakes.map do |fake|
      fam = families_of(fake)
      words = significant(fake, stone_words)
      score = fake_tests.sum do |t|
        t_fam = families_of(t.fake, t.id)
        shared = (words & significant(t.fake, stone_words)).size
        t.weight * (((fam & t_fam).size * 3) + (shared * 1.5))
      end
      [fake, score]
    end
    top = scored.map(&:last).max.to_f
    return [] if top < 3.0

    scored.select { |_, s| s >= top * 0.6 }.sort_by { |_, s| -s }.first(2).map(&:first)
  end

  def tokens(text) = text.to_s.downcase.scan(/[a-z][a-z-]+/)

  def families_of(text, test_id = nil)
    fams = tokens(text).filter_map { |w| WORD_FAMILY[w] || WORD_FAMILY[w.split("-").first] }
    fams += TEST_FAMILY_HINTS.fetch(test_id.to_s, [])
    fams.uniq
  end

  def significant(text, stone_words)
    (tokens(text) - STOPWORDS - stone_words).select { |w| w.length >= 4 && !WORD_FAMILY.key?(w) }.uniq
  end
end
