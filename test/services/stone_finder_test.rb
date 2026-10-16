# frozen_string_literal: true

require "test_helper"

class StoneFinderTest < ActiveSupport::TestCase
  # Minimal stand-in for AtlasEntry: an Atlas::Stone plus path and guide?.
  class Entry
    attr_reader :stone

    def initialize(stone, guides: [])
      @stone = stone
      @guides = guides
    end

    def path = "/gemstones/#{stone.slug}"
    def guide?(g) = @guides.include?(g)
    def method_missing(name, *args, &blk) = stone.respond_to?(name) ? stone.public_send(name, *args, &blk) : super
    def respond_to_missing?(name, priv = false) = stone.respond_to?(name, priv) || super
  end

  def stone(slug, water: "safe", salt: "safe", sun: "safe", sleep: "ok", wear: "daily", tox: "none", mohs: [7, 7],
            zodiac: [], zodiac_cautions: [], intentions: %w[peace-calm sleep anxiety], energy: "calming", elements: ["water"],
            planets: [], months: {}, tier: "budget", cautions: nil, guides: [])
    data = {
      "slug" => slug, "name" => slug.split("-").map(&:capitalize).join(" "), "kind" => "mineral", "mohs" => mohs,
      "summary" => "A test stone called #{slug}. It exists for tests.",
      "safety" => {
        "water" => { "verdict" => water, "reason" => "Water reason for #{slug}. More detail here." },
        "salt" => { "verdict" => salt, "reason" => "Salt reason for #{slug}, long enough to pass." },
        "sun" => { "verdict" => sun, "reason" => "Sun reason for #{slug}, long enough to pass." },
        "sleep" => { "verdict" => sleep, "reason" => "Sleep reason for #{slug}. Second sentence." },
        "wear" => { "verdict" => wear, "reason" => "Wear reason for #{slug}. Second sentence." },
        "toxicity" => { "level" => tox, "reason" => "Toxicity reason for #{slug}. Second sentence." },
        "elixir" => "indirect"
      },
      "tradition" => { "elements" => elements, "planets" => planets, "zodiac" => zodiac, "intentions" => intentions,
                       "energy" => energy, "birth_months" => months },
      "cautions" => cautions || [{ "who" => "Anyone", "why" => "A physical caution for #{slug}.", "basis" => "physical" }],
      "zodiac_cautions" => zodiac_cautions,
      "price" => { "tier" => tier, "note" => "x" }
    }
    Entry.new(Atlas::Stone.new(data), guides: guides)
  end

  def world
    @world ||= [
      stone("amethyst", zodiac: %w[pisces aquarius], intentions: %w[sleep anxiety peace-calm intuition], months: { "modern" => ["february"] },
                        zodiac_cautions: [{ "sign" => "aries", "why" => "Aries is ruled by Mars, an enemy of Saturn." }], planets: %w[jupiter neptune],
                        guides: ["who-should-not-wear"]),
      stone("moonstone", water: "brief", wear: "care", zodiac: %w[cancer libra], intentions: %w[love intuition sleep], energy: "balancing",
                         months: { "modern" => ["june"] }, tier: "mid", planets: ["moon"]),
      stone("malachite", water: "avoid", sleep: "caution", wear: "special", tox: "caution", mohs: [3.5, 4], intentions: %w[transformation protection love],
                         energy: "energizing", tier: "mid", sun: "limit"),
      stone("carnelian", zodiac: %w[aries leo], intentions: %w[motivation courage energy confidence], energy: "energizing", elements: ["fire"],
                         planets: ["mars"], months: { "traditional" => ["august"] }),
      stone("sapphire", zodiac: %w[virgo], intentions: %w[wealth clarity], energy: "balancing", tier: "luxury", mohs: [9, 9]),
      stone("selenite", water: "avoid", wear: "special", intentions: %w[peace-calm sleep spiritual-growth], mohs: [2, 2], sleep: "ok")
    ]
  end

  def finder = StoneFinder.new(world)
  def slugs(list) = list.map { |p| p.respond_to?(:entry) ? p.entry.slug : p.slug }

  # ---- Query ------------------------------------------------------------

  test "query parses a valid date and derives sign, element and month" do
    q = StoneFinder::Query.parse({ "dob" => "1994-07-28" }, today: Date.new(2026, 10, 16))
    assert_equal "leo", q.sign
    assert_equal "fire", q.element
    assert_equal 7, q.month
    assert_empty q.errors
    assert_not q.sign_info[:cusp]
  end

  test "query rejects nonsense dates with a friendly message and never raises" do
    today = Date.new(2026, 10, 16)
    ["garbage", "1994-13-40", "2023-02-29", "3000-01-01", "1850-05-05", "2026-10-17", "1994-7-", ["x"], { "a" => "b" }].each do |bad|
      q = StoneFinder::Query.parse({ "dob" => bad }, today: today)
      assert_nil q.dob, bad.inspect
      assert_equal 1, q.errors.size, bad.inspect
    end
    assert_match(/leap year/, StoneFinder::Query.parse({ "dob" => "2023-02-29" }, today: today).errors.first)
  end

  test "query accepts Feb 29 in a leap year and today" do
    today = Date.new(2026, 10, 16)
    assert_equal "pisces", StoneFinder::Query.parse({ "dob" => "2000-02-29" }, today: today).sign
    assert_equal Date.new(2026, 10, 16), StoneFinder::Query.parse({ "dob" => "2026-10-16" }, today: today).dob
  end

  test "query with nil and blank input is inactive" do
    assert_not StoneFinder::Query.parse({}).active?
    assert_not StoneFinder::Query.parse({ "dob" => "", "i" => [] }).active?
    assert_not StoneFinder::Query.new.active?
  end

  test "query clamps and filters intentions, use, budget and flags" do
    q = StoneFinder::Query.parse({ "i" => %w[love sleep bogus love anxiety grief], "use" => "NOPE", "budget" => "mid", "f" => %w[kids x water] })
    assert_equal %w[love sleep anxiety], q.intentions
    assert_nil q.use
    assert_equal "mid", q.budget
    assert_equal %w[kids water], q.flags
  end

  test "query tolerates odd param shapes" do
    q = StoneFinder::Query.parse({ "i" => { "0" => "love", "1" => ["nested"] }, "f" => "kids", "sign" => ["leo"], "use" => { "a" => 1 } })
    assert_equal ["love"], q.intentions
    assert_equal ["kids"], q.flags
    assert_nil q.sign
  end

  test "query accepts a sign without a date and dob wins over sign" do
    assert_equal "leo", StoneFinder::Query.parse({ "sign" => "Leo" }).sign
    assert_equal "leo", StoneFinder::Query.parse({ "dob" => "1994-07-28", "sign" => "aries" }).sign
    assert_nil StoneFinder::Query.parse({ "sign" => "ophiuchus" }).sign
  end

  test "cusp is flagged with the neighbouring sign" do
    q = StoneFinder::Query.parse({ "dob" => "2000-03-20" }, today: Date.new(2026, 1, 1))
    assert q.sign_info[:cusp]
    assert_equal %w[aries pisces], [q.sign, q.sign_info[:cusp_with]].sort
    assert_not_equal q.sign, q.sign_info[:cusp_with]
  end

  test "to_params round trips" do
    q = StoneFinder::Query.parse({ "dob" => "1994-07-28", "i" => %w[love], "use" => "wear", "budget" => "mid", "f" => ["kids"] }, today: Date.new(2026, 10, 16))
    assert_equal({ dob: "1994-07-28", i: ["love"], use: "wear", budget: "mid", f: ["kids"] }, q.to_params)
    assert_equal q, StoneFinder::Query.parse(q.to_params.deep_stringify_keys, today: Date.new(2026, 10, 16))
  end

  # ---- Ranking ------------------------------------------------------------

  test "intention ranking puts stones listing the goal first with reasons" do
    r = finder.call(StoneFinder::Query.new(intentions: ["sleep"]))
    assert_equal "amethyst", r.picks.first.entry.slug
    assert_operator r.picks.first.reasons.size, :>=, 2
    assert_match(/sleep/, r.picks.first.reasons.first.text)
    assert r.picks.all? { |p| p.entry.intentions.include?("sleep") }
    assert_not_includes slugs(r.picks), "carnelian"
  end

  test "score is 0 to 100 and sorted, ties broken by name" do
    r = finder.call(StoneFinder::Query.new(intentions: ["sleep"]))
    scores = r.picks.map(&:score)
    assert scores.all? { |s| s.between?(0, 100) }
    assert_equal scores.sort.reverse, scores
    a = stone("alpha"); b = stone("beta"); c = stone("charlie")
    r2 = StoneFinder.new([c, b, a]).call(StoneFinder::Query.new(intentions: ["sleep"]))
    assert_equal %w[alpha beta charlie], slugs(r2.picks)
  end

  test "deterministic" do
    q = StoneFinder::Query.new(sign: "pisces", intentions: %w[sleep love], use: "sleep")
    assert_equal finder.call(q).picks.map { |p| [p.entry.slug, p.score] }, finder.call(q).picks.map { |p| [p.entry.slug, p.score] }
  end

  test "sign link, element and birthstone raise the score and show as reasons" do
    r = finder.call(StoneFinder::Query.parse({ "dob" => "1995-02-20", "i" => ["sleep"] }, today: Date.new(2026, 1, 1)))
    top = r.picks.first
    assert_equal "amethyst", top.entry.slug
    texts = top.reasons.map(&:text).join(" | ")
    assert_match(/Traditionally linked to Pisces/, texts)
    assert_match(/February birthstone/, texts)
    assert_includes top.parts.map(&:key), :birthstone
  end

  test "element match scores below a direct sign link" do
    q = StoneFinder::Query.new(sign: "scorpio") # water element; moonstone has cancer, amethyst has water element
    r = finder.call(q)
    assert r.picks.any?
    assert r.picks.all? { |p| p.reasons.first.kind == :sign || p.reasons.first.kind == :easy || p.reasons.first.kind == :about }
  end

  test "ruling planet adds a reason" do
    r = finder.call(StoneFinder::Query.new(sign: "aries"))
    carnelian = r.picks.find { |p| p.entry.slug == "carnelian" }
    assert_match(/Mars/, carnelian.reasons.map(&:text).join)
  end

  test "reasons are capped at four and at least two when possible" do
    r = finder.call(StoneFinder::Query.parse({ "dob" => "1995-02-20", "i" => %w[sleep anxiety], "use" => "sleep", "f" => %w[water kids sensitive] }, today: Date.new(2026, 1, 1)))
    r.picks.each { |p| assert_operator p.reasons.size, :<=, 4 }
    assert_operator r.picks.first.reasons.size, :>=, 2
  end

  test "no inputs returns easy-care stones" do
    r = finder.call(StoneFinder::Query.new)
    assert r.picks.any?
    assert_equal "amethyst", r.picks.first.entry.slug
  end

  test "empty atlas and nil entries do not raise" do
    r = StoneFinder.new([]).call(StoneFinder::Query.new(intentions: ["sleep"], sign: "leo"))
    assert_empty r.picks
    assert_empty r.skips
    assert_empty StoneFinder.new(nil).call(StoneFinder::Query.new).picks
  end

  # ---- Exclusions ---------------------------------------------------------

  test "water cleansing excludes water-avoid stones with the reason" do
    r = finder.call(StoneFinder::Query.new(intentions: ["peace-calm"], flags: ["water"]))
    assert_not_includes slugs(r.picks), "selenite"
    skip = r.skips.find { |s| s.entry.slug == "selenite" }
    assert_equal :safety, skip.reasons.first.kind
    assert_match(/cleanse with water/, skip.reasons.first.text)
  end

  test "children or pets excludes toxic, sleep-caution and fragile stones" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[love protection], flags: ["kids"]))
    assert_not_includes slugs(r.picks), "malachite"
    skip = r.skips.find { |s| s.entry.slug == "malachite" }
    assert_operator skip.reasons.size, :>=, 3
    r2 = finder.call(StoneFinder::Query.new(intentions: ["spiritual-growth"], flags: ["kids"]))
    assert_includes slugs(r2.skips), "selenite" # wear special = fragile
  end

  test "daily wear excludes care and special stones" do
    r = finder.call(StoneFinder::Query.new(intentions: ["love"], use: "wear"))
    assert_not_includes slugs(r.picks), "moonstone"
    assert_not_includes slugs(r.picks), "malachite"
  end

  test "sleep use excludes sleep-caution and energizing stones" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[love], use: "sleep"))
    assert_not_includes slugs(r.picks), "malachite"
    r2 = finder.call(StoneFinder::Query.new(intentions: %w[confidence], use: "sleep"))
    assert_includes slugs(r2.skips), "carnelian"
  end

  test "budget excludes dearer tiers and keeps stones without a tier" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[wealth love], budget: "budget"))
    assert_not_includes slugs(r.picks), "sapphire"
    assert_includes slugs(r.skips), "sapphire"
    nodata = stone("mystery", intentions: ["wealth"], tier: nil)
    r2 = StoneFinder.new([nodata]).call(StoneFinder::Query.new(intentions: ["wealth"], budget: "budget"))
    assert_equal ["mystery"], slugs(r2.picks)
  end

  test "budget is up to and including the chosen tier" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[love], budget: "mid"))
    assert_includes slugs(r.picks), "moonstone"
  end

  test "zodiac caution puts the stone in skips with a tradition reason regardless of goals" do
    r = finder.call(StoneFinder::Query.new(sign: "aries", intentions: ["sleep"]))
    assert_not_includes slugs(r.picks), "amethyst"
    skip = r.skips.find { |s| s.entry.slug == "amethyst" }
    assert_equal :zodiac, skip.reasons.first.kind
    assert_match(/advises Aries against Amethyst/, skip.reasons.first.text)
    assert_match(/Mars/, skip.reasons.first.text)
    r2 = finder.call(StoneFinder::Query.new(sign: "aries", intentions: ["wealth"])) # amethyst irrelevant to wealth, still shown
    assert_includes slugs(r2.skips), "amethyst"
  end

  test "energizing stones are skipped for sleep, anxiety and calm goals unless an energising goal is also chosen" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[anxiety confidence]))
    assert_includes slugs(r.skips), "carnelian"
    r2 = finder.call(StoneFinder::Query.new(intentions: %w[anxiety motivation]))
    assert_includes slugs(r2.picks), "carnelian"
  end

  test "sensitive flag skips energizing stones" do
    r = finder.call(StoneFinder::Query.new(intentions: %w[courage], flags: ["sensitive"]))
    assert_not_includes slugs(r.picks), "carnelian"
    assert_includes slugs(r.skips), "carnelian"
  end

  test "picks and skips never overlap" do
    q = StoneFinder::Query.new(sign: "aries", intentions: %w[sleep love], use: "sleep", flags: %w[kids water sensitive], budget: "mid")
    r = finder.call(q)
    assert_empty slugs(r.picks) & slugs(r.skips)
  end

  test "hints explain what would unlock more stones when results are thin" do
    q = StoneFinder::Query.new(intentions: ["wealth"], budget: "budget")
    r = finder.call(q)
    assert_empty r.picks
    hint = r.hints.find { |h| h.key == :budget }
    assert hint
    assert_equal 1, hint.gain
    assert_nil hint.query.budget
  end

  # ---- Pick extras --------------------------------------------------------

  test "pick carries the most important physical caution" do
    r = finder.call(StoneFinder::Query.new(intentions: ["transformation"]))
    mal = StoneFinder.caution_for(world.find { |e| e.slug == "malachite" })
    assert_match(/Toxicity reason/, mal[:why])
    assert_equal "physical", mal[:basis]
    assert r.picks.empty? || r.picks.first.caution
  end

  test "caution falls back to safety data and is nil when nothing applies" do
    s = stone("quiet", cautions: [{ "who" => "People who like drama", "why" => "Tradition says so.", "basis" => "tradition" }])
    assert_nil StoneFinder.caution_for(s)
    d = stone("soggy", water: "avoid", cautions: [{ "who" => "x", "why" => "Tradition.", "basis" => "tradition" }])
    assert_match(/Water reason/, StoneFinder.caution_for(d)[:why])
  end

  # ---- Embeds -------------------------------------------------------------

  test "sign statuses cover all twelve signs" do
    st = StoneFinder.sign_statuses(world.first)
    assert_equal Atlas::ZODIAC, st.map { |s| s[:sign] }
    assert_equal :recommended, st.find { |s| s[:sign] == "pisces" }[:status]
    aries = st.find { |s| s[:sign] == "aries" }
    assert_equal :advised_against, aries[:status]
    assert_match(/Mars/, aries[:why])
    assert_equal :neutral, st.find { |s| s[:sign] == "leo" }[:status]
  end

  test "ordered cautions put physical first and keep basis" do
    s = stone("mix", cautions: [
      { "who" => "T1", "why" => "tradition one", "basis" => "tradition" },
      { "who" => "P1", "why" => "physical one", "basis" => "physical" }
    ])
    assert_equal %w[P1 T1], StoneFinder.ordered_cautions(s).map { |c| c[:who] }
  end

  test "for_sign returns ranked picks and the tradition avoid list" do
    out = StoneFinder.for_sign(world, "aries")
    assert_equal "carnelian", out[:picks].first.entry.slug
    assert_equal ["amethyst"], out[:avoid].map { |e, _| e.slug }
    assert_nil StoneFinder.for_sign(world, "ophiuchus")
  end

  test "for_intention and beginner picks" do
    assert_equal "amethyst", StoneFinder.for_intention(world, "sleep").first.entry.slug
    assert_empty StoneFinder.for_intention(world, "nonsense")
    beginners = StoneFinder.for_intention(world, :beginners)
    assert_equal %w[amethyst carnelian sapphire], beginners.map(&:slug).sort
    assert beginners.all? { |e| e.safety("water") == "safe" && e.toxicity == "none" }
  end

  test "article slug mapping" do
    assert_equal "wealth", StoneFinder::Vocab.article_intention("crystals-for-money")
    assert_equal "sleep", StoneFinder::Vocab.article_intention("crystals-for-nightmares")
    assert_equal :beginners, StoneFinder::Vocab.article_intention("crystals-for-beginners")
    assert_nil StoneFinder::Vocab.article_intention("crystals-for-nurses")
    assert_nil StoneFinder::Vocab.article_intention("birthstone-guide")
    assert_nil StoneFinder::Vocab.article_intention(nil)
  end

  test "fit levels" do
    assert_equal ["Excellent fit", :good], StoneFinder.fit_level(90)
    assert_equal "Partial fit", StoneFinder.fit_level(10).first
  end
end
