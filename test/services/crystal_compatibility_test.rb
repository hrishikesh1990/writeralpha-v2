# frozen_string_literal: true

require "test_helper"

class CrystalCompatibilityTest < ActiveSupport::TestCase
  SAFE = ->(v, r = "Fine.") { { "verdict" => v, "reason" => "#{r} Padding text for the validator." } }

  # An in-memory Atlas::Stone with sensible defaults; pass nested overrides.
  def stone(slug, overrides = {})
    data = {
      "slug" => slug, "name" => slug.tr("-", " ").split.map(&:capitalize).join(" "), "mohs" => [7, 7],
      "safety" => {
        "water" => SAFE.("safe"), "salt" => SAFE.("safe"), "sun" => SAFE.("safe"),
        "sleep" => SAFE.("ok"), "wear" => SAFE.("daily"),
        "toxicity" => { "level" => "none", "reason" => "Inert." }, "elixir" => "direct"
      },
      "tradition" => {
        "chakras" => [], "elements" => [], "vedic_planet" => nil, "intentions" => [], "energy" => nil
      },
      "pairs" => { "good" => [], "avoid" => [] }
    }
    Atlas::Stone.new(data.deep_merge(overrides))
  end

  # Mirrors the engine's scoring curve (saturating in both directions).
  def sat(raw) = (50 + (raw <=> 0) * 47 * (1 - Math.exp(-raw.abs / 38.0))).round

  def trad(**t) = { "tradition" => t.transform_keys(&:to_s) }

  # ---- Basics -----------------------------------------------------------------

  test "a stone with itself, or an unknown stone, has no verdict" do
    a = stone("alpha")
    assert_nil CrystalCompatibility.check(a, a)
    assert_nil CrystalCompatibility.check(a, nil)
    assert_nil CrystalCompatibility.check("alpha-does-not-exist", "also-missing")
    assert_nil CrystalCompatibility.check(a, Object.new)
  end

  test "score is clamped 0..100 and verdict matches score band" do
    a = stone("alpha", trad(intentions: %w[sleep peace-calm anxiety grief], chakras: %w[heart], elements: %w[water], energy: "calming")
                         .merge("pairs" => { "good" => [{ "slug" => "beta", "why" => "Tradition says a lovely pair." }] }))
    b = stone("beta", trad(intentions: %w[sleep peace-calm anxiety grief], chakras: %w[heart], elements: %w[water], energy: "calming")
                         .merge("pairs" => { "good" => [{ "slug" => "alpha", "why" => "Tradition says a lovely pair too." }] }))
    r = CrystalCompatibility.check(a, b)
    assert_includes 0..100, r.score
    assert_equal :great, r.verdict
    assert_equal "Great together", r.label
    assert r.score >= 76
  end

  test "no data in common is neutral and exactly the base score" do
    r = CrystalCompatibility.check(stone("alpha"), stone("beta"))
    assert_equal 50, r.score
    assert_equal :neutral, r.verdict
    assert_equal "Neutral", r.label
  end

  # ---- Explicit pairs -----------------------------------------------------------

  test "explicit good pair in either file is the strongest positive signal" do
    a = stone("alpha", "pairs" => { "good" => [{ "slug" => "beta", "why" => "Tradition says they amplify each other." }] })
    b = stone("beta")
    r1 = CrystalCompatibility.check(a, b)
    r2 = CrystalCompatibility.check(b, a)
    assert_equal r1.score, r2.score
    assert_equal sat(22), r1.score
    reason = r1.plus.first
    assert_equal :pairing, reason.topic
    assert_equal :tradition, reason.basis
    assert_match(/amplify/, reason.text)
    assert_equal "Listed in Alpha's pairings", reason.source
  end

  test "pairing listed in both files scores higher than in one" do
    a = stone("alpha", "pairs" => { "good" => [{ "slug" => "beta", "why" => "Tradition: one." }] })
    b = stone("beta", "pairs" => { "good" => [{ "slug" => "alpha", "why" => "Tradition: two." }] })
    one = CrystalCompatibility.check(a, stone("beta"))
    both = CrystalCompatibility.check(a, b)
    assert_operator both.score, :>, one.score
    assert_equal 2, both.plus.count { |x| x.topic == :pairing }
  end

  test "explicit tradition avoid forces the avoid verdict and caps the score" do
    a = stone("alpha", trad(intentions: %w[sleep calming], chakras: %w[heart]).merge("pairs" => { "avoid" => [{ "slug" => "beta", "why" => "Traditionally opposed energies." }] }))
    b = stone("beta", trad(intentions: %w[sleep], chakras: %w[heart]))
    r = CrystalCompatibility.check(a, b)
    assert_equal :avoid, r.verdict
    assert_equal "Traditionally not paired", r.label
    assert_operator r.score, :<=, 38
    assert r.forced?
    assert_equal :minus, r.reasons.find { |x| x.topic == :pairing }.sign
  end

  test "a physical avoid reason is practical advice and does not label the pair as traditionally avoided" do
    a = stone("alpha", "pairs" => { "avoid" => [{ "slug" => "beta", "why" => "Beta will scratch alpha if they share a pouch." }] })
    r = CrystalCompatibility.check(a, stone("beta"))
    refute_equal :avoid, r.verdict
    assert_equal 50, r.score
    assert_equal :practical, r.reasons.find { |x| x.topic == :pairing }.sign
  end

  test "when one entry recommends and the other forbids, tradition is flagged as contested" do
    a = stone("alpha", "pairs" => { "good" => [{ "slug" => "beta", "why" => "Tradition says great." }] })
    b = stone("beta", "pairs" => { "avoid" => [{ "slug" => "alpha", "why" => "Traditionally opposed." }] })
    r = CrystalCompatibility.check(a, b)
    assert r.contested?
    assert_operator r.score, :<=, 55
    assert r.reasons.any? { |x| x.topic == :contested }
    assert_match(/disagree/, r.summary)
  end

  # ---- Vedic --------------------------------------------------------------------

  test "Vedic enemies force avoid with the explicit sentence" do
    ruby = stone("ruby", "name" => "Ruby", "tradition" => { "vedic_planet" => "surya", "intentions" => %w[confidence energy love], "chakras" => %w[heart], "elements" => %w[fire], "energy" => "energizing" })
    sapphire = stone("blue-sapphire", "name" => "Blue Sapphire", "tradition" => { "vedic_planet" => "shani", "intentions" => %w[confidence energy love], "chakras" => %w[heart], "elements" => %w[fire], "energy" => "energizing" })
    r = CrystalCompatibility.check(ruby, sapphire)
    assert_equal :avoid, r.verdict
    assert_equal :enemy, r.vedic.status
    assert_operator r.score, :<=, 24
    v = r.minus.find { |x| x.basis == :vedic }
    assert_includes v.text, "Vedic astrology advises against wearing Ruby (Sun) with Blue Sapphire (Saturn)"
    assert_equal :vedic, r.forced
    assert_match(/Vedic astrology advises/, r.headline)
  end

  test "Vedic enemy is overridden by nothing, even an explicit good pairing, and the disagreement is shown" do
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" }, "pairs" => { "good" => [{ "slug" => "blue-sapphire", "why" => "Tradition pairs them for power." }] })
    sapphire = stone("blue-sapphire", "tradition" => { "vedic_planet" => "shani" })
    r = CrystalCompatibility.check(ruby, sapphire)
    assert_equal :avoid, r.verdict
    assert r.contested?
    assert r.reasons.any? { |x| x.topic == :contested && x.text.include?("Vedic") }
  end

  test "asymmetric Vedic enmity is reported honestly" do
    # Venus lists the Moon as an enemy; the Moon lists no enemies.
    pearl = stone("pearl", "tradition" => { "vedic_planet" => "chandra" })
    diamond = stone("diamond", "tradition" => { "vedic_planet" => "shukra" })
    r = CrystalCompatibility.check(pearl, diamond)
    assert_equal :avoid, r.verdict
    assert r.vedic.asymmetric
    assert_match(/lopsided/, r.minus.find { |x| x.basis == :vedic }.text)
  end

  test "Vedic friends add points, same planet adds a little, neutral planets add nothing" do
    base = CrystalCompatibility.check(stone("a1"), stone("b1")).score
    friends = CrystalCompatibility.check(stone("a1", "tradition" => { "vedic_planet" => "shukra" }), stone("b1", "tradition" => { "vedic_planet" => "shani" }))
    assert_equal :friend, friends.vedic.status
    assert_equal sat(12), friends.score
    same = CrystalCompatibility.check(stone("a1", "tradition" => { "vedic_planet" => "shani" }), stone("b1", "tradition" => { "vedic_planet" => "shani" }))
    assert_equal :same, same.vedic.status
    assert_equal sat(3), same.score
    enemy = CrystalCompatibility.check(stone("a1", "tradition" => { "vedic_planet" => "guru" }), stone("b1", "tradition" => { "vedic_planet" => "shukra" }))
    assert_equal :enemy, enemy.vedic.status
    neutral = CrystalCompatibility.check(stone("a1", "tradition" => { "vedic_planet" => "mangal" }), stone("b1", "tradition" => { "vedic_planet" => "ketu" }))
    assert_equal :neutral, neutral.vedic.status # Ketu counts Mars a friend; Mars does not return it
    assert_equal base, neutral.score
    assert_equal :neutral, neutral.neutral.first.sign
  end

  test "Vedic rule only applies when both stones have a graha" do
    r = CrystalCompatibility.check(stone("a1", "tradition" => { "vedic_planet" => "surya" }), stone("b1"))
    assert_equal :n_a, r.vedic.status
    assert_equal 50, r.score
  end

  test "Vedic note about rooms appears for bedroom and meditation contexts only" do
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" })
    sapphire = stone("blue-sapphire", "tradition" => { "vedic_planet" => "shani" })
    assert CrystalCompatibility.check(ruby, sapphire, context: "bedroom").reasons.any? { |x| x.topic == :vedic_room }
    refute CrystalCompatibility.check(ruby, sapphire, context: "bracelet").reasons.any? { |x| x.topic == :vedic_room }
    assert_equal :avoid, CrystalCompatibility.check(ruby, sapphire, context: "bedroom").verdict
  end

  test "two substitute stones get the milder-substitutes note, primary stones do not" do
    clear = stone("clear-quartz", "tradition" => { "vedic_planet" => "shukra" })
    citrine = stone("citrine", "tradition" => { "vedic_planet" => "guru" }, "pairs" => { "good" => [{ "slug" => "clear-quartz", "why" => "Tradition pairs them." }] })
    r = CrystalCompatibility.check(clear, citrine)
    assert_equal :avoid, r.verdict
    assert r.contested?
    assert_equal [false, false], r.vedic.primary
    assert r.reasons.any? { |x| x.topic == :vedic_substitute }
    assert_match(/Vedic astrology says no to Clear Quartz and Citrine, though crystal tradition pairs them/, r.headline)
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" })
    sapphire = stone("sapphire", "tradition" => { "vedic_planet" => "shani" })
    r2 = CrystalCompatibility.check(ruby, sapphire)
    assert_equal [true, true], r2.vedic.primary
    refute r2.reasons.any? { |x| x.topic == :vedic_substitute }
  end

  test "Vedic substitute stones are named as substitutes" do
    amethyst = stone("amethyst", "tradition" => { "vedic_planet" => "shani" })
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" })
    text = CrystalCompatibility.check(amethyst, ruby).minus.find { |x| x.basis == :vedic }.text
    assert_match(/Amethyst counts as a Saturn stone in Jyotish because it is a recognised substitute \(upratna\) for Blue Sapphire/, text)
  end

  # ---- Intentions, chakras, elements, energy ------------------------------------------

  test "more shared intentions score higher" do
    mk = ->(n) { stone("a1", trad(intentions: %w[sleep love luck wealth][0, n])) }
    other = stone("b1", trad(intentions: %w[sleep love luck wealth]))
    scores = (1..4).map { |n| CrystalCompatibility.check(mk.call(n), other).score }
    assert_equal scores.sort.uniq, scores
  end

  test "different intentions are noted but do not cost points" do
    r = CrystalCompatibility.check(stone("a1", trad(intentions: %w[love])), stone("b1", trad(intentions: %w[wealth])))
    assert_equal 50, r.score
    assert_equal :intentions, r.neutral.first.topic
  end

  test "same or adjacent chakras are harmonious, distant ones are neutral" do
    same = CrystalCompatibility.check(stone("a1", trad(chakras: %w[heart])), stone("b1", trad(chakras: %w[heart root])))
    assert_equal sat(4), same.score
    adjacent = CrystalCompatibility.check(stone("a1", trad(chakras: %w[heart])), stone("b1", trad(chakras: %w[throat])))
    assert_equal sat(2), adjacent.score
    far = CrystalCompatibility.check(stone("a1", trad(chakras: %w[root])), stone("b1", trad(chakras: %w[crown])))
    assert_equal 50, far.score
    assert_equal :chakras, far.neutral.first.topic
  end

  test "elements: support and same help, clash hurts softly, unrelated is silent" do
    el = ->(a, b) { CrystalCompatibility.check(stone("a1", trad(elements: a)), stone("b1", trad(elements: b))) }
    assert_equal sat(4), el.call(%w[fire], %w[air]).score
    assert_equal sat(4), el.call(%w[earth], %w[water]).score
    assert_equal sat(4), el.call(%w[water], %w[water]).score
    clash = el.call(%w[fire], %w[water])
    assert_equal sat(-4), clash.score
    assert_equal :minus, clash.reasons.first.sign
    assert_match(/soft clash/, clash.reasons.first.text)
    assert_equal 50, el.call(%w[fire], %w[earth]).score
    assert_empty el.call(%w[fire], %w[earth]).reasons.select { |x| x.topic == :elements }
    mixed = el.call(%w[air water], %w[earth])
    assert_equal :neutral, mixed.reasons.find { |x| x.topic == :elements }.sign
  end

  test "calming with energising is a soft minus by default, plus in daytime contexts, and a strong minus for sleep" do
    calm = stone("calm", trad(energy: "calming"))
    spark = stone("spark", trad(energy: "energizing"))
    default = CrystalCompatibility.check(calm, spark)
    assert_equal sat(-6), default.score
    assert_match(/fine for daytime balance, but not the pair to put by your bed or use for meditation/, default.minus.first.text)
    assert_equal sat(2), CrystalCompatibility.check(calm, spark, context: "bracelet").score
    assert_equal sat(2), CrystalCompatibility.check(calm, spark, context: "pocket").score
    sleep = CrystalCompatibility.check(calm, spark, context: "bedroom")
    assert_equal sat(-14), sleep.score
    assert_equal :avoid, sleep.verdict
    assert_match(/works against sleep/, sleep.minus.first.text)
    med = CrystalCompatibility.check(calm, spark, context: "meditation")
    assert_match(/works against meditation/, med.minus.first.text)
  end

  test "grounding and balancing partners help; same energy helps" do
    assert_equal sat(1), CrystalCompatibility.check(stone("a1", trad(energy: "grounding")), stone("b1", trad(energy: "energizing"))).score
    assert_equal sat(1), CrystalCompatibility.check(stone("a1", trad(energy: "balancing")), stone("b1", trad(energy: "calming"))).score
    assert_equal sat(2), CrystalCompatibility.check(stone("a1", trad(energy: "calming")), stone("b1", trad(energy: "calming"))).score
  end

  test "bedroom context penalises energising stones" do
    r = CrystalCompatibility.check(stone("a1", trad(energy: "energizing")), stone("b1", trad(energy: "energizing")), context: "bedroom")
    assert_equal sat(-8), r.score
    r = CrystalCompatibility.check(stone("a1", trad(energy: "energizing")), stone("b1", trad(energy: "grounding")), context: "bedroom")
    assert_equal sat(-3), r.score
  end

  # ---- Practical ----------------------------------------------------------------------

  test "hardness gap of 2 or more says store apart and never changes the score" do
    hard = stone("hard", "mohs" => [7, 7])
    soft = stone("soft", "mohs" => [2, 2])
    r = CrystalCompatibility.check(hard, soft)
    p = r.practical.find { |x| x.topic == :hardness }
    assert_equal "Store apart: Hard (Mohs 7) will scratch Soft (Mohs 2). Keep them in separate pouches or compartments.", p.text
    assert_equal :physical, p.basis
    assert_equal 0, p.points
    assert_equal CrystalCompatibility.check(stone("hard"), stone("soft")).score, r.score
    assert_match(/On the practical side: Hard will scratch Soft, so keep them in separate pouches\./, r.summary)
  end

  test "hardness notes: close, similar, and context variants" do
    close = CrystalCompatibility.check(stone("a1", "mohs" => [7, 7]), stone("b1", "mohs" => [6, 6]))
    assert_match(/Close in hardness/, close.practical.find { |x| x.topic == :hardness }.text)
    same = CrystalCompatibility.check(stone("a1", "mohs" => [7, 7]), stone("b1", "mohs" => [6.5, 7.5]))
    assert_match(/Similar hardness/, same.practical.find { |x| x.topic == :hardness }.text)
    bracelet = CrystalCompatibility.check(stone("a1", "mohs" => [7, 7]), stone("b1", "mohs" => [3, 3]), context: "bracelet")
    assert_match(/bracelet the harder stone wears the softer/, bracelet.practical.find { |x| x.topic == :hardness }.text)
    pocket = CrystalCompatibility.check(stone("a1", "mohs" => [7, 7]), stone("b1", "mohs" => [3, 3]), context: "pocket")
    assert_match(/own pouch/, pocket.practical.find { |x| x.topic == :hardness }.text)
  end

  test "missing hardness does not raise" do
    a = Atlas::Stone.new("slug" => "x", "name" => "X")
    b = Atlas::Stone.new("slug" => "y", "name" => "Y")
    r = CrystalCompatibility.check(a, b)
    assert_equal :neutral, r.verdict
    assert r.practical.none? { |x| x.topic == :hardness }
  end

  test "cleansing: intersection of safe methods and why water, salt and sun are blocked" do
    sel = stone("selenite", "mohs" => [2, 2], "safety" => { "water" => SAFE.("avoid", "Gypsum dissolves in water."), "salt" => SAFE.("avoid", "Salt dissolves it."), "sun" => SAFE.("limit", "Heat dries it out.") })
    quartz = stone("quartz")
    r = CrystalCompatibility.check(sel, quartz)
    shared = r.cleanse.shared
    assert_equal sel.safe_cleanse_methods & quartz.safe_cleanse_methods, shared
    refute_includes shared, "water"
    assert_includes shared, "smoke"
    methods = r.cleanse.blocked.map { |b| b[:method] }
    assert_includes methods, "water"
    assert_includes methods, "salt_water"
    assert_includes methods, "sunlight"
    water = r.cleanse.blocked.find { |b| b[:method] == "water" }
    assert_equal "Selenite", water[:who].first[:stone].name
    assert_match(/Gypsum dissolves/, water[:who].first[:reason])
    assert r.practical.any? { |x| x.topic == :cleanse && x.text.include?("skip") }
  end

  test "two quartz-like stones have nothing blocked and no cleanse warning" do
    r = CrystalCompatibility.check(stone("a1"), stone("b1"))
    assert_empty r.cleanse.blocked
    assert r.practical.none? { |x| x.topic == :cleanse }
    assert_includes r.cleanse.shared, "water"
    assert_includes r.cleanse.shared, "sunlight"
  end

  test "toxicity caution warns against a shared elixir" do
    tox = stone("malachite", "safety" => { "toxicity" => { "level" => "caution", "reason" => "Copper leaches into water." }, "elixir" => "never" })
    r = CrystalCompatibility.check(tox, stone("b1"))
    p = r.practical.find { |x| x.topic == :elixir }
    assert_match(/Don't make a shared elixir/, p.text)
    assert_match(/Copper leaches/, p.text)
    assert_equal :warn, p.tone
  end

  test "bedroom, bracelet and pocket contexts add physical notes from the atlas" do
    wary = stone("wary", "safety" => { "sleep" => SAFE.("caution", "Sheds splinters."), "wear" => SAFE.("special", "Too soft to wear."), "water" => SAFE.("avoid", "Dissolves.") })
    other = stone("b1")
    assert CrystalCompatibility.check(wary, other, context: "bedroom").practical.any? { |x| x.topic == :sleep && x.text.include?("Sheds splinters") }
    bracelet = CrystalCompatibility.check(wary, other, context: "bracelet")
    assert bracelet.practical.any? { |x| x.topic == :wear && x.text.include?("occasional wear") }
    assert bracelet.practical.any? { |x| x.topic == :water }
    refute CrystalCompatibility.check(wary, other).practical.any? { |x| %i[sleep wear water].include?(x.topic) }
    assert_equal CrystalCompatibility.check(wary, other).score, bracelet.score
  end

  # ---- Context handling -----------------------------------------------------------------

  test "contexts normalise, aliases work, junk is ignored" do
    assert_equal "bedroom", CrystalCompatibility.normalize_context("sleep")
    assert_equal "bedroom", CrystalCompatibility.normalize_context(" Bedroom ")
    assert_equal "bracelet", CrystalCompatibility.normalize_context("jewelry")
    assert_nil CrystalCompatibility.normalize_context("<script>")
    assert_nil CrystalCompatibility.normalize_context(nil)
    assert_nil CrystalCompatibility.normalize_context(["x"])
    assert_equal "bedroom", CrystalCompatibility.check(stone("a1"), stone("b1"), context: "sleep").context
  end

  test "meditation and bedroom contexts reward matching intentions" do
    med = %w[concentration clarity]
    assert_equal sat(6), CrystalCompatibility.check(stone("a1", trad(intentions: med)), stone("b1", trad(intentions: med))).score
    assert_equal sat(9), CrystalCompatibility.check(stone("a1", trad(intentions: med)), stone("b1", trad(intentions: med)), context: "meditation").score
    zz = %w[sleep]
    assert_equal sat(3), CrystalCompatibility.check(stone("a1", trad(intentions: zz)), stone("b1", trad(intentions: zz))).score
    assert_equal sat(6), CrystalCompatibility.check(stone("a1", trad(intentions: zz)), stone("b1", trad(intentions: zz)), context: "bedroom").score
  end

  # ---- Ranking, matrix, helpers -------------------------------------------------------------

  test "best_partners ranks by score, drops avoid, honours limit" do
    me = stone("me", trad(intentions: %w[love sleep], chakras: %w[heart]).merge("pairs" => { "good" => [{ "slug" => "friend", "why" => "Tradition loves it." }] }))
    friend = stone("friend")
    shares = stone("shares", trad(intentions: %w[love sleep], chakras: %w[heart]))
    plain = stone("plain")
    foe = stone("foe", "pairs" => { "avoid" => [{ "slug" => "me", "why" => "Traditionally opposed." }] })
    list = CrystalCompatibility.best_partners(me, among: [plain, foe, shares, friend, me], limit: 5)
    assert_equal %w[friend shares plain], list.map { |r| r.other(me).slug }
    assert_equal 1, CrystalCompatibility.best_partners(me, among: [plain, foe, shares, friend], limit: 1).size
    assert_equal %w[foe], CrystalCompatibility.avoid_partners(me, among: [plain, foe, shares, friend]).map { |r| r.other(me).slug }
    assert_empty CrystalCompatibility.best_partners("not-a-stone")
    report = CrystalCompatibility.partner_report(me, limit: 2, among: [plain, foe, shares, friend])
    assert_equal %w[friend shares], report.best.map { |r| r.other(me).slug }
    assert_equal %w[foe], report.avoid.map { |r| r.other(me).slug }
  end

  test "matrix gives pairwise results for 3 and 4 stones, dedupes and caps at 4" do
    ss = %w[a1 b1 c1 d1 e1].map { |s| stone(s) }
    m3 = CrystalCompatibility.matrix(ss.first(3))
    assert_equal 3, m3.results.size
    assert_equal 3, m3.stones.size
    assert m3.cell(ss[0], ss[1])
    assert_same m3.cell(ss[0], ss[1]), m3.cell(ss[1], ss[0])
    assert_nil m3.cell(ss[0], ss[0])
    assert_equal 6, CrystalCompatibility.matrix(ss).results.size
    assert_equal 1, CrystalCompatibility.matrix([ss[0], ss[1], ss[1]]).results.size
    empty = CrystalCompatibility.matrix([ss[0]])
    assert_empty empty.results
    assert_nil empty.verdict
  end

  test "matrix verdict is avoid when any pair is avoid, and the worst pair is reported" do
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" })
    sapphire = stone("blue-sapphire", "tradition" => { "vedic_planet" => "shani" })
    other = stone("other")
    m = CrystalCompatibility.matrix([ruby, sapphire, other])
    assert_equal :avoid, m.verdict
    assert_equal %w[ruby blue-sapphire], m.worst.slugs
    assert_equal "Traditionally not paired", m.label
  end

  test "matrix reports pairs that need to be stored apart" do
    m = CrystalCompatibility.matrix([stone("hard", "mohs" => [9, 9]), stone("soft", "mohs" => [3, 3]), stone("mid", "mohs" => [8, 8])])
    assert_equal 2, m.store_apart.size
    assert m.store_apart.all? { |r| r.slugs.include?("soft") }
  end

  test "known_conflicts finds Vedic enemies and curated avoids" do
    ruby = stone("ruby", "tradition" => { "vedic_planet" => "surya" })
    sapphire = stone("blue-sapphire", "tradition" => { "vedic_planet" => "shani" })
    a = stone("alpha", "pairs" => { "avoid" => [{ "slug" => "beta", "why" => "Traditionally opposed." }] })
    list = CrystalCompatibility.known_conflicts([ruby, sapphire, a, stone("beta"), stone("gamma")])
    assert_equal [%w[alpha beta], %w[blue-sapphire ruby]], list.map { |r| r.slugs.sort }.sort
    assert list.all?(&:avoid?)
  end

  test "split_pair_slug resolves hyphenated stone names in either position" do
    known = %w[amethyst lapis-lazuli black-tourmaline rose-quartz clear-quartz]
    assert_equal %w[amethyst rose-quartz], CrystalCompatibility.split_pair_slug("amethyst-and-rose-quartz-together", known)
    assert_equal %w[lapis-lazuli amethyst], CrystalCompatibility.split_pair_slug("lapis-lazuli-and-amethyst-together", known)
    assert_equal %w[black-tourmaline amethyst], CrystalCompatibility.split_pair_slug("black-tourmaline-and-amethyst-together", known)
    assert_equal %w[clear-quartz black-tourmaline], CrystalCompatibility.split_pair_slug("clear-quartz-and-black-tourmaline-together", known)
    assert_nil CrystalCompatibility.split_pair_slug("amethyst-and-unknown-together", known)
    assert_nil CrystalCompatibility.split_pair_slug("amethyst-and-amethyst-together", known)
    assert_nil CrystalCompatibility.split_pair_slug("amethyst-and-rose-quartz", known)
    assert_nil CrystalCompatibility.split_pair_slug(nil, known)
    assert_nil CrystalCompatibility.split_pair_slug("-and--together", known)
  end

  test "entries that delegate to a stone are accepted and kept in results" do
    entry = Struct.new(:stone) do
      delegate_missing_to :stone
      def respond_to_missing?(*) = true
    end
    e = entry.new(stone("alpha"))
    r = CrystalCompatibility.check(e, stone("beta"))
    assert_same e, r.a
  end

  # ---- Real Atlas files (skipped when the stones are not present yet) ----------------------------

  test "amethyst and selenite from the real atlas" do
    skip "atlas files not present" unless Atlas["amethyst"] && Atlas["selenite"]
    r = CrystalCompatibility.check("amethyst", "selenite")
    assert_includes %i[great good], r.verdict
    assert r.explicit_good?
    assert r.practical.any? { |x| x.text.start_with?("Store apart: Amethyst (Mohs 7) will scratch Selenite (Mohs 2)") }
    assert_includes r.cleanse.shared, "smoke"
    refute_includes r.cleanse.shared, "water"
    assert_equal r.score, CrystalCompatibility.check("selenite", "amethyst").score
  end

  test "amethyst and carnelian from the real atlas are traditionally not paired" do
    skip "atlas files not present" unless Atlas["amethyst"] && Atlas["carnelian"]
    r = CrystalCompatibility.check("amethyst", "carnelian")
    assert_equal :avoid, r.verdict
  end

  test "amethyst and malachite warn about elixirs" do
    skip "atlas files not present" unless Atlas["amethyst"] && Atlas["malachite"]
    r = CrystalCompatibility.check("amethyst", "malachite")
    assert r.practical.any? { |x| x.topic == :elixir && x.text.include?("Don't make a shared elixir") }
  end

  test "every pair in the real atlas evaluates without raising" do
    stones = Atlas.stones
    stones.combination(2) do |x, y|
      r = CrystalCompatibility.check(x, y, context: %w[bracelet bedroom meditation pocket nil].sample)
      assert_includes 0..100, r.score
      assert r.headline.present?
      assert VERDICTS_OK.include?(r.verdict)
    end
  end

  VERDICTS_OK = %i[great good neutral avoid].freeze
end
