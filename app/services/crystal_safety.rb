# frozen_string_literal: true

# Engine for the Crystal Safety Checker. Pure Ruby: no view code, no database.
# It works on anything that quacks like an Atlas stone (an AtlasEntry or an
# Atlas::Stone), so it is unit-testable with plain objects.
#
#   rows = CrystalSafety.rows(entries)                  # the full matrix
#   CrystalSafety.filter(rows, keys: %w[water salt])    # stones that pass every chip
#   CrystalSafety.group(rows, "water")                  # grouped by verdict, with counts
#   CrystalSafety.common_methods(entries)               # multi-stone cleanse planner
module CrystalSafety
  KEYS = Atlas::SAFETY_KEYS # water salt sun sleep wear

  KEY_LABELS = {
    "water" => "Water", "salt" => "Salt", "sun" => "Sun", "sleep" => "Sleep", "wear" => "Wear",
    "toxicity" => "Toxicity", "mohs" => "Mohs"
  }.freeze

  # Filter chips on the matrix. Each is a predicate on a Row. Chips combine
  # with AND. "dry" is the inverse of "water": stones that must not soak.
  Filter = Struct.new(:key, :label, :test, keyword_init: true)
  FILTERS = [
    Filter.new(key: "water", label: "Can go in water", test: ->(r) { r.verdict("water") == "safe" }),
    Filter.new(key: "dry", label: "Never soak", test: ->(r) { %w[brief avoid].include?(r.verdict("water")) }),
    Filter.new(key: "salt", label: "Salt safe", test: ->(r) { r.verdict("salt") == "safe" }),
    Filter.new(key: "sun", label: "Sun safe", test: ->(r) { r.verdict("sun") == "safe" }),
    Filter.new(key: "nontoxic", label: "Non-toxic", test: ->(r) { r.toxicity == "none" }),
    Filter.new(key: "sleep", label: "OK to sleep with", test: ->(r) { r.verdict("sleep") == "ok" })
  ].freeze
  FILTER_KEYS = FILTERS.map(&:key).freeze

  SORTS = { "name" => "Name A to Z", "hardest" => "Hardest first", "softest" => "Softest first" }.freeze

  # Cleansing methods that only ever cost a stone nothing physical.
  # (Whether they cleanse anything is crystal tradition, not physics.)
  UNIVERSAL_METHODS = %w[smoke sound moonlight selenite breath dry_salt].freeze

  # One stone's row in the matrix. Verdict lookups never raise; a missing
  # verdict is nil and renders as "Not rated".
  Row = Struct.new(:entry, :slug, :name, :mohs_min, :mohs_max, :mohs_label, :verdicts, :reasons,
                   :toxicity, :toxicity_reason, :elixir, keyword_init: true) do
    def verdict(key) = verdicts[key.to_s]
    def reason(key) = reasons[key.to_s].to_s
    def rated?(key) = !verdict(key).nil?
    def mohs? = !mohs_min.nil?
    def path = entry.respond_to?(:path) ? entry.path : nil
  end

  # Verdict groups for a focus column, in display order.
  # [verdict, heading, short description, tone]
  GROUPS = {
    "water" => [
      ["safe", "Safe in water", "Rinsing or a short soak does no harm.", :good],
      ["brief", "Quick rinse only", "A rinse is fine; never soak, and dry it straight away.", :warn],
      ["avoid", "Keep dry", "Water damages or dissolves it, or draws something out of it.", :bad]
    ],
    "salt" => [
      ["safe", "Salt safe", "Salt and salt water do not harm the stone.", :good],
      ["avoid", "Avoid salt", "Salt scratches, corrodes, dissolves or seeps into it.", :bad]
    ],
    "sun" => [
      ["safe", "Sun safe", "Strong light and heat do not change it.", :good],
      ["limit", "Short exposure only", "Long exposure fades it or heats it. A few hours is the limit.", :warn],
      ["avoid", "Keep out of the sun", "Sunlight fades or damages it quickly.", :bad]
    ]
  }.freeze

  # Mohs bands for the hardness focus, placed by the softest end of the range.
  MOHS_BANDS = [
    ["hard", "Hard (7 and above)", "Mohs 7 and above.", :good, 7.0],
    ["medium", "Medium (5 to under 7)", "Mohs 5 to under 7.", :warn, 5.0],
    ["soft", "Soft (under 5)", "Mohs under 5. Store apart from harder stones.", :bad, 0.0]
  ].freeze

  # The scale itself, rung by rung (definition of the Mohs scale).
  MOHS_SCALE = {
    1 => "Talc", 2 => "Gypsum", 3 => "Calcite", 4 => "Fluorite", 5 => "Apatite",
    6 => "Orthoclase feldspar", 7 => "Quartz", 8 => "Topaz", 9 => "Corundum", 10 => "Diamond"
  }.freeze

  Group = Struct.new(:key, :label, :description, :tone, :rows, keyword_init: true) do
    def count = rows.size
  end

  Blocker = Struct.new(:row, :level, :reason, keyword_init: true) # level: :avoid or :limit

  # status: :safe (every stone), :caution (nobody must avoid it, but some stones
  # only tolerate it briefly), :blocked (at least one stone must not have it).
  MethodResult = Struct.new(:key, :label, :status, :blockers, :allowed, keyword_init: true) do
    def safe? = status == :safe
    def caution? = status == :caution
    def blocked? = status == :blocked
    def short = SHORT_METHOD_NAMES.fetch(key, label.downcase)
  end

  SHORT_METHOD_NAMES = {
    "smoke" => "smoke", "sound" => "sound", "moonlight" => "moonlight",
    "selenite" => "a selenite or clear quartz plate", "breath" => "breath",
    "earth" => "burying in dry earth", "water" => "running water", "sunlight" => "sunlight",
    "salt_water" => "salt water", "dry_salt" => "a bowl of dry salt"
  }.freeze

  Plan = Struct.new(:rows, :methods, keyword_init: true) do
    # "smoke, sound and moonlight" (nil when nothing is safe for every stone).
    def safe_sentence
      list = safe.map(&:short)
      list.empty? ? nil : CrystalSafety.join_list(list)
    end

    # "running water (Selenite and Pyrite); sunlight (Amethyst)" (nil when nothing is blocked).
    def blocked_sentence
      return nil if blocked.empty?

      blocked.map { |m| "#{m.short} (#{CrystalSafety.join_list(m.blockers.map { |b| b.row.name })})" }.join("; ")
    end

    def safe = methods.select(&:safe?)
    def caution = methods.select(&:caution?)
    def blocked = methods.select(&:blocked?)
    def single? = rows.size == 1
    # Stones that can take every method on their own: nobody blocks anything.
    def all_clear? = blocked.empty? && caution.empty?
  end

  module_function

  # ---- Matrix ---------------------------------------------------------------

  def row(entry)
    verdicts = KEYS.to_h { |k| [k, safe_call(entry, :safety, k)] }
    reasons = KEYS.to_h { |k| [k, safe_call(entry, :safety_reason, k).to_s] }
    mohs_min = safe_call(entry, :mohs_min)
    mohs_max = safe_call(entry, :mohs_max)
    Row.new(entry: entry, slug: entry.slug, name: entry.name.to_s,
            mohs_min: mohs_min, mohs_max: mohs_max,
            mohs_label: (mohs_min ? safe_call(entry, :mohs_label) : nil),
            verdicts: verdicts, reasons: reasons,
            toxicity: safe_call(entry, :toxicity) || "none",
            toxicity_reason: safe_call(entry, :toxicity_reason).to_s,
            elixir: safe_call(entry, :elixir) || "indirect")
  end

  def rows(entries) = Array(entries).map { |e| row(e) }

  # Rows passing every filter key (unknown keys are ignored) and the name query.
  def filter(rows, keys: [], query: nil)
    tests = Array(keys).filter_map { |k| FILTERS.find { |f| f.key == k.to_s }&.test }
    q = query.to_s.strip.downcase
    rows.select do |r|
      tests.all? { |t| t.call(r) } && (q.empty? || matches?(r, q))
    end
  end

  # Filter keys a row passes, for the matrix's client-side filtering.
  def flags(row) = FILTERS.select { |f| f.test.call(row) }.map(&:key)

  # How many stones pass each filter chip on its own.
  def filter_counts(rows) = FILTERS.to_h { |f| [f.key, rows.count { |r| f.test.call(r) }] }

  def sort(rows, by = "name")
    case by.to_s
    when "hardest" then rows.sort_by { |r| [-(r.mohs_max || -1), -(r.mohs_min || -1), r.name] }
    when "softest" then rows.sort_by { |r| [r.mohs_min || 99, r.mohs_max || 99, r.name] }
    else rows.sort_by { |r| r.name.downcase }
    end
  end

  # Counts per verdict for one column, for the "N stones" summaries.
  def counts(rows, key)
    rows.group_by { |r| r.verdict(key) }.transform_values(&:size)
  end

  # ---- Grouping for a focus column --------------------------------------------

  # Groups for "water" | "salt" | "sun" | "mohs", empty groups dropped.
  # Stones without a verdict land in a trailing "Not rated yet" group.
  def group(rows, focus)
    focus = focus.to_s
    return mohs_groups(rows) if focus == "mohs"

    defs = GROUPS[focus] or return []
    by_verdict = rows.group_by { |r| r.verdict(focus) }
    groups = defs.filter_map do |verdict, label, description, tone|
      members = sort(by_verdict.fetch(verdict, []))
      Group.new(key: verdict, label: label, description: description, tone: tone, rows: members) if members.any?
    end
    unrated = sort(rows.reject { |r| defs.any? { |d| d.first == r.verdict(focus) } })
    groups << Group.new(key: "unrated", label: "Not rated yet", description: "No safety data for this stone yet.", tone: :info, rows: unrated) if unrated.any?
    groups
  end

  def mohs_groups(rows)
    rated, unrated = rows.partition(&:mohs?)
    groups = MOHS_BANDS.filter_map do |key, label, description, tone, floor|
      members = rated.select { |r| mohs_band(r)[0] == key }.sort_by { |r| [-r.mohs_min, r.name] }
      Group.new(key: key, label: label, description: description, tone: tone, rows: members) if members.any?
    end
    groups << Group.new(key: "unrated", label: "Not rated yet", description: "No hardness data for this stone yet.", tone: :info, rows: sort(unrated)) if unrated.any?
    groups
  end

  def mohs_band(row)
    MOHS_BANDS.find { |_, _, _, _, floor| row.mohs_min >= floor }
  end

  # The Mohs ladder: rungs 1..10, each listing every stone whose hardness range
  # includes that whole number (a 6.5 to 7 stone sits on rung 7 only, because it
  # scratches rung 6). A range that holds no whole number, such as 7.5 to 7.8,
  # sits on the rung just below it. Returns
  # [{ rung:, scale:, rows: [Row] }, ...] hardest first.
  def mohs_ladder(rows)
    rated = rows.select(&:mohs?)
    (1..10).to_a.reverse.map do |rung|
      members = rated.select { |r| mohs_rungs(r).include?(rung) }
      { rung: rung, scale: MOHS_SCALE[rung], rows: members.sort_by { |r| [r.name.downcase] } }
    end
  end

  def mohs_rungs(row)
    low = row.mohs_min.ceil.clamp(1, 10)
    high = row.mohs_max.floor.clamp(1, 10)
    low <= high ? (low..high).to_a : [row.mohs_min.floor.clamp(1, 10)]
  end

  # ---- Cleanse planner --------------------------------------------------------

  # Which cleansing methods are safe for ALL given stones, and for each method
  # that is not, which stones block it and why. Methods come from
  # Atlas::Stone::CLEANSE_METHODS and each stone's own safe_cleanse_methods.
  def common_methods(entries)
    plan_rows = self.rows(Array(entries))
    methods = Atlas::Stone::CLEANSE_METHODS.map do |key, label|
      blockers = plan_rows.filter_map { |r| blocker_for(r, key) }
      allowed = plan_rows - blockers.map(&:row)
      status = if blockers.empty? then :safe
               elsif blockers.all? { |b| b.level == :limit } then :caution
               else :blocked
               end
      MethodResult.new(key: key, label: label, status: status, blockers: blockers, allowed: allowed)
    end
    Plan.new(rows: plan_rows, methods: methods)
  end

  # Why this stone can't have this method, or nil when it can.
  def blocker_for(row, key)
    return nil if safe_methods_for(row).include?(key)

    case key
    when "water"
      level = row.verdict("water") == "brief" ? :limit : :avoid
      Blocker.new(row: row, level: level, reason: fallback(row.reason("water"), "No water verdict is recorded for this stone."))
    when "sunlight"
      level = row.verdict("sun") == "limit" ? :limit : :avoid
      Blocker.new(row: row, level: level, reason: fallback(row.reason("sun"), "No sun verdict is recorded for this stone."))
    when "salt_water"
      reason = if row.verdict("salt") != "safe" then row.reason("salt")
               else row.reason("water") end
      Blocker.new(row: row, level: :avoid, reason: fallback(reason, "Salt water is a soak, and no safe-soak verdict is recorded for this stone."))
    when "earth"
      reason = if row.verdict("water") == "avoid" then "Soil holds damp and this stone must not get wet."
               elsif row.mohs? then "At Mohs #{row.mohs_label} it is soft enough for grit in the soil to scratch it."
               else "No hardness is recorded for this stone." end
      Blocker.new(row: row, level: :avoid, reason: reason)
    end
  end

  # The same rule Atlas::Stone#safe_cleanse_methods applies, but it never
  # raises on a half-filled entry: anything unrecorded counts as not safe.
  def safe_methods_for(row)
    row.entry.safe_cleanse_methods
  rescue StandardError
    UNIVERSAL_METHODS
  end

  # ---- Single-stone Q&A -------------------------------------------------------

  QA = Struct.new(:key, :question, :lead, :verdict, :answer, keyword_init: true)

  # The "Can <Stone> go in..." block: each answer starts with a plain
  # Yes / Only briefly / No and then gives the Atlas reason.
  def faq(row)
    name = row.name
    water = row.verdict("water")
    sun = row.verdict("sun")
    [
      qa("water", "Can #{name} go in water?", water, { "safe" => "Yes", "brief" => "Only a quick rinse", "avoid" => "No" }, row.reason("water")),
      qa("salt", "Can #{name} go in salt water?", row.verdict("salt"), { "safe" => "Yes", "avoid" => "No" }, row.reason("salt")),
      qa("sun", "Can #{name} go in the sun?", sun, { "safe" => "Yes", "limit" => "Only briefly", "avoid" => "No" }, row.reason("sun")),
      QA.new(key: "moonlight", question: "Can #{name} go in moonlight?", lead: "Yes", verdict: "safe", answer: moonlight_answer(row)),
      bath_qa(row),
      qa("sleep", "Can you sleep with #{name} under your pillow?", row.verdict("sleep"), { "ok" => "Yes", "caution" => "With caution" }, row.reason("sleep"))
    ]
  end

  def bath_qa(row)
    water = row.verdict("water")
    question = "Can #{row.name} go in the bath or shower?"
    if row.toxicity == "caution"
      return QA.new(key: "bath", question: question, lead: "No", verdict: "avoid",
                    answer: tidy("#{row.toxicity_reason} #{row.reason('water') if %w[brief avoid].include?(water)} Keep it out of bath water and any water you drink or wash with."))
    end

    case water
    when "safe"
      jewellery = row.verdict("wear") == "daily" ? "" : " #{row.reason('wear')}"
      QA.new(key: "bath", question: question, lead: "Yes", verdict: "safe",
             answer: tidy("Plain water does not harm the stone itself. #{row.reason('water')}#{jewellery}"))
    when "brief"
      QA.new(key: "bath", question: question, lead: "Only a quick rinse", verdict: "brief",
             answer: tidy("#{row.reason('water')} Do not wear it in the shower or leave it in a bath."))
    when "avoid"
      QA.new(key: "bath", question: question, lead: "No", verdict: "avoid",
             answer: tidy("#{row.reason('water')} Steam and splashes count as water, so keep it out of the bathroom."))
    else
      QA.new(key: "bath", question: question, lead: "Not rated yet", verdict: nil,
             answer: "No water verdict is recorded for this stone yet, so keep it dry until there is one.")
    end
  end

  def moonlight_answer(row)
    base = "Moonlight carries no heat or ultraviolet worth worrying about, so it is the gentlest way to cleanse any stone. Whether moonlight cleanses anything is crystal tradition, not physics."
    return base if row.verdict("water") == "safe"

    wet = row.verdict("water") == "avoid" ? "must not get wet" : "should not sit wet"
    "#{base} Use an indoor windowsill rather than an outdoor ledge: dew and rain are still water, and this stone #{wet}."
  end

  def qa(key, question, verdict, leads, reason)
    lead = leads[verdict] || "Not rated yet"
    answer = reason.to_s.strip.empty? ? "No verdict is recorded for this stone yet." : reason
    QA.new(key: key, question: question, lead: lead, verdict: verdict, answer: answer)
  end

  # What the Atlas elixir field means in practice. Returns { verdict:, label:, text: }.
  def elixir_guidance(row)
    text = case row.elixir
           when "direct" then "The atlas lists this stone as suitable for direct-contact elixirs: it is inert, non-porous, non-toxic and hard."
           when "indirect" then "Use the indirect method only: seal the stone in a clean glass jar or vial and stand that in the water. Never put the stone itself in water you will drink."
           when "never"
             why = row.toxicity == "none" ? "Water harms this stone." : "It is toxic or can leach into water."
             "Never make an elixir with this stone, directly or indirectly. #{why} Keep it out of any water you drink."
           end
    return nil unless text

    { verdict: row.elixir, label: { "direct" => "Direct elixir OK", "indirect" => "Indirect only", "never" => "No elixirs" }[row.elixir],
      text: "#{text} Elixirs are a crystal tradition, not a health treatment." }
  end

  # A short blurb of a reason for one-line lists: whole sentences until it is
  # at least `min` characters, cut at a word boundary if it runs past `max`.
  def blurb(text, min: 70, max: 150)
    s = tidy(text)
    return "" if s.empty?

    out = +""
    s.scan(/.+?(?:[.!?](?=\s|\z)|\z)/m).each do |sentence|
      candidate = out.empty? ? sentence.strip : "#{out} #{sentence.strip}"
      break if !out.empty? && out.length >= min && candidate.length > max

      out = candidate
      break if out.length >= min
    end
    return out if out.length <= max

    cut = out[0, max - 1]
    cut = cut[0, cut.rindex(" ")] if cut.rindex(" ")
    "#{cut.sub(/[,;:\s]+\z/, '')}…"
  end

  # "a", "a and b", "a, b and c"
  def join_list(items)
    items = Array(items).map(&:to_s)
    return items.first.to_s if items.size <= 1

    "#{items[0..-2].join(', ')} and #{items.last}"
  end

  # ---- internals --------------------------------------------------------------

  def matches?(row, query)
    return true if row.name.downcase.include?(query)

    entry = row.entry
    names = Array(safe_call(entry, :aka)) + Array(safe_call(entry, :names)&.values)
    names.any? { |n| n.to_s.downcase.include?(query) }
  end

  def safe_call(obj, meth, *args)
    obj.public_send(meth, *args)
  rescue StandardError
    nil
  end

  def tidy(text) = text.to_s.gsub(/\s+/, " ").strip

  def fallback(text, default) = text.to_s.strip.empty? ? default : text

  private_class_method :mohs_rungs, :matches?, :qa, :moonlight_answer, :safe_call, :fallback, :tidy
end
