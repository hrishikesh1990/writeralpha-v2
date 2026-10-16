require "test_helper"

class CrystalSafetyTest < ActiveSupport::TestCase
  def stone(slug, mohs:, water:, salt:, sun:, sleep: "ok", wear: "daily", tox: "none", elixir: "direct", aka: [])
    reason = ->(what) { "#{slug} #{what} reason. It continues with more detail." }
    v = ->(key, verdict) { { "verdict" => verdict, "reason" => reason.call(key) } }
    Atlas::Stone.new(
      "slug" => slug, "name" => slug.tr("-", " ").split.map(&:capitalize).join(" "), "aka" => aka, "mohs" => mohs,
      "safety" => { "water" => v.call("water", water), "salt" => v.call("salt", salt), "sun" => v.call("sun", sun),
                    "sleep" => v.call("sleep", sleep), "wear" => v.call("wear", wear),
                    "toxicity" => { "level" => tox, "reason" => "#{slug} tox" }, "elixir" => elixir }
    )
  end

  setup do
    @amethyst = stone("amethyst", mohs: [7, 7], water: "safe", salt: "safe", sun: "limit", aka: ["purple quartz"])
    @selenite = stone("selenite", mohs: [2, 2], water: "avoid", salt: "avoid", sun: "limit", wear: "special", elixir: "never")
    @pyrite = stone("pyrite", mohs: [6, 6.5], water: "avoid", salt: "avoid", sun: "safe", elixir: "never")
    @malachite = stone("malachite", mohs: [3.5, 4], water: "avoid", salt: "avoid", sun: "limit", sleep: "caution",
                                    wear: "care", tox: "caution", elixir: "never")
    @opal = stone("opal", mohs: [5.5, 6.5], water: "brief", salt: "avoid", sun: "safe")
    @quartz = stone("clear-quartz", mohs: [7, 7], water: "safe", salt: "safe", sun: "safe")
    @all = [@amethyst, @selenite, @pyrite, @malachite, @opal, @quartz]
  end

  test "rows carry verdicts, reasons, toxicity, elixir and hardness" do
    r = CrystalSafety.row(@malachite)
    assert_equal "avoid", r.verdict("water")
    assert_match(/water reason/, r.reason("water"))
    assert_equal "caution", r.toxicity
    assert_equal "never", r.elixir
    assert_equal "3.5–4", r.mohs_label
    assert_equal 3.5, r.mohs_min
    assert_equal 6, CrystalSafety.rows(@all).size - 0
  end

  test "rows survive a half-filled stone" do
    bare = Atlas::Stone.new("slug" => "mystery", "name" => "Mystery")
    r = CrystalSafety.row(bare)
    assert_nil r.verdict("water")
    assert_equal "", r.reason("water")
    refute r.mohs?
    assert_equal "none", r.toxicity
    # and the planner does not raise on it
    plan = CrystalSafety.common_methods([bare, @amethyst])
    assert_includes plan.safe.map(&:key), "moonlight"
    assert plan.blocked.map(&:key).include?("water")
  end

  test "filter chips combine with AND, keep-dry inverts water, query matches aka" do
    rows = CrystalSafety.rows(@all)
    assert_equal %w[amethyst clear-quartz], CrystalSafety.filter(rows, keys: ["water"]).map(&:slug).sort
    assert_equal %w[clear-quartz], CrystalSafety.filter(rows, keys: %w[water sun]).map(&:slug)
    assert_equal %w[malachite opal pyrite selenite], CrystalSafety.filter(rows, keys: ["dry"]).map(&:slug).sort
    refute_includes CrystalSafety.filter(rows, keys: ["nontoxic"]).map(&:slug), "malachite"
    refute_includes CrystalSafety.filter(rows, keys: ["sleep"]).map(&:slug), "malachite"
    assert_equal rows.size, CrystalSafety.filter(rows, keys: %w[bogus]).size
    assert_equal %w[amethyst], CrystalSafety.filter(rows, query: "purple").map(&:slug)
    assert_equal %w[selenite], CrystalSafety.filter(rows, query: "  SELEN ").map(&:slug)
  end

  test "sorting by name and hardness" do
    rows = CrystalSafety.rows(@all)
    assert_equal "Amethyst", CrystalSafety.sort(rows, "name").first.name
    assert_equal "Selenite", CrystalSafety.sort(rows, "softest").first.name
    assert_includes %w[Amethyst Clear\ Quartz], CrystalSafety.sort(rows, "hardest").first.name
    assert_equal "Amethyst", CrystalSafety.sort(rows, "nonsense").first.name
  end

  test "group by water gives ordered groups with counts" do
    groups = CrystalSafety.group(CrystalSafety.rows(@all), "water")
    assert_equal %w[safe brief avoid], groups.map(&:key)
    assert_equal [2, 1, 3], groups.map(&:count)
    assert_equal %w[Amethyst Clear\ Quartz], groups.first.rows.map(&:name)
  end

  test "group puts unrated stones in their own group and drops empty groups" do
    bare = Atlas::Stone.new("slug" => "mystery", "name" => "Mystery")
    groups = CrystalSafety.group(CrystalSafety.rows([@amethyst, bare]), "sun")
    assert_equal %w[limit unrated], groups.map(&:key)
    assert_empty CrystalSafety.group([], "water")
    assert_empty CrystalSafety.group(CrystalSafety.rows(@all), "nonsense")
  end

  test "group by mohs bands by the softest end" do
    groups = CrystalSafety.group(CrystalSafety.rows(@all), "mohs")
    assert_equal %w[hard medium soft], groups.map(&:key)
    assert_equal %w[Amethyst Clear\ Quartz], groups.first.rows.map(&:name).sort
    assert_equal %w[Opal Pyrite], groups[1].rows.map(&:name).sort
  end

  test "mohs ladder places a stone on every rung its range touches" do
    ladder = CrystalSafety.mohs_ladder(CrystalSafety.rows(@all))
    assert_equal (1..10).to_a.reverse, ladder.map { |l| l[:rung] }
    by = ladder.to_h { |l| [l[:rung], l[:rows].map(&:slug)] }
    assert_includes by[7], "amethyst"
    assert_includes by[2], "selenite"
    assert_includes by[5], "opal"  # 5.5 to 6.5 spans rungs 5, 6
    assert_includes by[6], "opal"
    assert_includes by[6], "pyrite"
    assert_empty by[10]
    assert_equal "Quartz", ladder.find { |l| l[:rung] == 7 }[:scale]
  end

  test "planner: amethyst, selenite and pyrite share only the dry methods" do
    plan = CrystalSafety.common_methods([@amethyst, @selenite, @pyrite])
    assert_equal %w[smoke sound moonlight selenite breath dry_salt].sort, plan.safe.map(&:key).sort
    water = plan.methods.find { |m| m.key == "water" }
    assert water.blocked?
    assert_equal %w[Pyrite Selenite], water.blockers.map { |b| b.row.name }.sort
    assert_equal %w[Amethyst], water.allowed.map(&:name)
    assert_match(/selenite water reason/, water.blockers.find { |b| b.row.slug == "selenite" }.reason)
    refute plan.all_clear?
  end

  test "planner: sunlight is a caution when stones only tolerate brief exposure" do
    plan = CrystalSafety.common_methods([@amethyst, @quartz])
    sun = plan.methods.find { |m| m.key == "sunlight" }
    assert sun.caution?
    assert_equal %w[Amethyst], sun.blockers.map { |b| b.row.name }
    assert_equal :limit, sun.blockers.first.level
    assert plan.methods.find { |m| m.key == "water" }.safe?
    assert plan.methods.find { |m| m.key == "salt_water" }.safe?
  end

  test "planner: brief water is not treated as safe" do
    plan = CrystalSafety.common_methods([@quartz, @opal])
    water = plan.methods.find { |m| m.key == "water" }
    assert water.caution?, "a quick-rinse-only stone must stop running water being listed as safe"
    assert plan.methods.find { |m| m.key == "salt_water" }.blocked?
  end

  test "planner: soft stones block burying even when water is not the issue" do
    soft = stone("soft-thing", mohs: [2, 2], water: "safe", salt: "safe", sun: "safe")
    plan = CrystalSafety.common_methods([soft])
    earth = plan.methods.find { |m| m.key == "earth" }
    assert earth.blocked?
    assert_match(/Mohs 2/, earth.blockers.first.reason)
    assert plan.single?
  end

  test "planner: every method is accounted for exactly once" do
    plan = CrystalSafety.common_methods(@all)
    assert_equal Atlas::Stone::CLEANSE_METHODS.keys.sort, plan.methods.map(&:key).sort
    assert_equal plan.methods.size, plan.safe.size + plan.caution.size + plan.blocked.size
    assert_empty CrystalSafety.common_methods([]).blocked
  end

  test "blurb joins short sentences and trims long ones at a word" do
    assert_equal "Agate is slightly porous. Salt water seeps into cracks and dulls the polish.",
                 CrystalSafety.blurb("Agate is slightly porous. Salt water seeps into cracks and dulls the polish. Rinse it afterwards.")
    assert_equal "", CrystalSafety.blurb(nil)
    assert_equal "Short one that is already long enough to stand alone as a blurb on its own line.",
                 CrystalSafety.blurb("Short one that is already long enough to stand alone as a blurb on its own line. Second.")
    long = CrystalSafety.blurb("word " * 80, max: 50)
    assert_operator long.length, :<=, 50
    assert long.end_with?("…")
    refute_match(/wor…/, long)
  end

  test "faq answers each question with a plain lead and the atlas reason" do
    qa = CrystalSafety.faq(CrystalSafety.row(@selenite)).index_by(&:key)
    assert_equal %w[water salt sun moonlight bath sleep], qa.keys
    assert_equal "No", qa["water"].lead
    assert_match(/selenite water reason/, qa["water"].answer)
    assert_equal "Only briefly", qa["sun"].lead
    assert_equal "Yes", qa["moonlight"].lead
    assert_match(/indoor windowsill/, qa["moonlight"].answer)
    assert_equal "No", qa["bath"].lead
    assert_equal "Yes", qa["sleep"].lead
    assert_equal "Can Selenite go in water?", qa["water"].question
  end

  test "faq is honest about brief, toxic and safe stones" do
    opal = CrystalSafety.faq(CrystalSafety.row(@opal)).index_by(&:key)
    assert_equal "Only a quick rinse", opal["water"].lead
    assert_equal "Only a quick rinse", opal["bath"].lead
    assert_match(/sit wet/, opal["moonlight"].answer)

    mal = CrystalSafety.faq(CrystalSafety.row(@malachite)).index_by(&:key)
    assert_equal "No", mal["bath"].lead
    assert_equal "With caution", mal["sleep"].lead
    assert_match(/malachite tox/, mal["bath"].answer)
    assert_match(/malachite water reason/, mal["bath"].answer)

    ame = CrystalSafety.faq(CrystalSafety.row(@amethyst)).index_by(&:key)
    assert_equal "Yes", ame["water"].lead
    assert_equal "Yes", ame["bath"].lead
    assert_match(/amethyst water reason/, ame["bath"].answer)
    refute_match(/indoor windowsill/, ame["moonlight"].answer)
  end

  test "faq never raises on an unrated stone" do
    bare = Atlas::Stone.new("slug" => "mystery", "name" => "Mystery")
    qa = CrystalSafety.faq(CrystalSafety.row(bare))
    assert_equal 6, qa.size
    assert_equal "Not rated yet", qa.first.lead
    assert qa.all? { |q| q.answer.present? }
  end

  test "elixir guidance follows the atlas field" do
    assert_equal "direct", CrystalSafety.elixir_guidance(CrystalSafety.row(@amethyst))[:verdict]
    never = CrystalSafety.elixir_guidance(CrystalSafety.row(@malachite))
    assert_equal "never", never[:verdict]
    assert_match(/toxic/, never[:text])
    assert_match(/not a health treatment/, never[:text])
    assert_match(/Water harms/, CrystalSafety.elixir_guidance(CrystalSafety.row(@selenite))[:text])
  end

  test "plan sentences name the safe methods and the stones that block the rest" do
    plan = CrystalSafety.common_methods([@amethyst, @selenite, @pyrite])
    assert_match(/smoke, sound, moonlight/, plan.safe_sentence)
    assert_match(/running water \(Selenite and Pyrite\)/, plan.blocked_sentence)
    assert_nil CrystalSafety.common_methods([@quartz, @amethyst]).blocked_sentence
  end

  test "join_list and flags and filter_counts" do
    assert_equal "", CrystalSafety.join_list([])
    assert_equal "a", CrystalSafety.join_list(["a"])
    assert_equal "a and b", CrystalSafety.join_list(%w[a b])
    assert_equal "a, b and c", CrystalSafety.join_list(%w[a b c])
    assert_equal %w[water salt sun nontoxic sleep], CrystalSafety.flags(CrystalSafety.row(@quartz))
    assert_equal %w[dry], CrystalSafety.flags(CrystalSafety.row(@selenite)) & %w[dry water]
    counts = CrystalSafety.filter_counts(CrystalSafety.rows(@all))
    assert_equal 2, counts["water"]
    assert_equal 4, counts["dry"]
  end

  test "works against the real Atlas files" do
    entries = Atlas.stones.first(10)
    rows = CrystalSafety.rows(entries)
    assert_equal entries.size, rows.size
    plan = CrystalSafety.common_methods(entries)
    assert_equal Atlas::Stone::CLEANSE_METHODS.size, plan.methods.size
  end
end
