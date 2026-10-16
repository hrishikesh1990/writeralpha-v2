# frozen_string_literal: true

require "test_helper"

class AuthenticityCheckTest < ActiveSupport::TestCase
  def stone(slug: "amethyst", name: "Amethyst", species: "quartz", fakes: nil, tests: nil)
    Atlas::Stone.new(
      "slug" => slug, "name" => name, "species" => species, "kind" => "variety",
      "identify" => {
        "common_fakes" => fakes || ["Purple glass", "Dyed quartz or dyed chalcedony",
                                    "Lab-grown (hydrothermal) amethyst sold as natural", "Purple fluorite sold as amethyst"],
        "tests" => tests || [
          { "id" => "color", "weight" => 2, "how" => "Hold it over white paper.", "real" => "Uneven.", "fake" => "Perfectly even colour." },
          { "id" => "magnification", "weight" => 3, "how" => "Use a 10x loupe.", "real" => "Feathers.",
            "fake" => "Round gas bubbles and swirl lines, which point to glass." },
          { "id" => "temperature", "weight" => 1, "how" => "Touch it to your cheek.", "real" => "Cold.", "fake" => "Warms within seconds, like glass or plastic." },
          { "id" => "hardness", "weight" => 2, "how" => "Try to scratch a piece of plain glass. This can chip a faceted stone.", "real" => "Scratches glass.", "fake" => "Fluorite (Mohs 4) cannot scratch glass." },
          { "id" => "acetone", "weight" => 2, "how" => "Rub a spot with a swab dipped in nail-polish remover.", "real" => "Swab stays clean.", "fake" => "Purple colour on the swab means the stone is dyed." },
          { "id" => "price", "weight" => 1, "how" => "Compare the price.", "real" => "Inexpensive.", "fake" => "Bargain price for a flawless stone." }
        ]
      }
    )
  end

  def check(answers, s = stone) = AuthenticityCheck.new(s, answers).result

  test "no answers is inconclusive and recommends the most telling non-destructive test" do
    r = check({})
    assert_equal :inconclusive, r.verdict
    assert_equal "Inconclusive — try these next", r.label
    assert_equal "magnification", r.next_tests.first.id
    assert_not r.started?
    assert_equal 0, r.progress
    assert_includes r.caveat, "only a gemmologist (or a lab report) can confirm".sub("only", "Only")
  end

  test "tests are ordered non-destructive first, then by weight" do
    ids = AuthenticityCheck.ordered_tests(stone).map(&:id)
    assert_equal %w[magnification color temperature price hardness acetone], ids
    tests = AuthenticityCheck.ordered_tests(stone).index_by(&:id)
    assert tests["hardness"].destructive?
    assert tests["acetone"].destructive?
    assert_not tests["magnification"].destructive?
  end

  test "a single weight-3 fake outweighs several weak real answers" do
    r = check("magnification" => "fake", "temperature" => "real", "price" => "real")
    assert_equal :imitation, r.verdict
    assert_equal "Signs of an imitation", r.label
  end

  test "one weight-3 fake on its own is enough to show signs of imitation, one weak answer is not" do
    assert_equal :imitation, check("magnification" => "fake").verdict
    assert_equal :inconclusive, check("temperature" => "fake").verdict
    assert_equal :inconclusive, check("magnification" => "real").verdict
  end

  test "fewer than two informative answers is inconclusive" do
    r = check("magnification" => "real", "color" => "unsure", "temperature" => "skipped")
    assert_equal :inconclusive, r.verdict
    assert_equal 1, r.informative
    assert_equal 3, r.answered
    assert_match(/at least two/, r.summary)
  end

  test "two good real answers read as consistent with genuine, never certain" do
    r = check("magnification" => "real", "color" => "real")
    assert_equal :genuine, r.verdict
    assert_equal "Consistent with genuine", r.label
    assert_match(/consistent with a genuine Amethyst/, r.summary)
    assert_match(/not proof/, r.summary)
    assert_match(/gemmologist/, r.caveat)
    assert_empty r.pointing_to
  end

  test "weak real answers alone never reassure" do
    r = check("temperature" => "real", "price" => "real")
    assert_equal :inconclusive, r.verdict
  end

  test "conflicting strong evidence is inconclusive" do
    r = check("color" => "fake", "hardness" => "real", "acetone" => "real")
    assert_equal :inconclusive, r.verdict
    assert_nil r.lean
    assert_match(/different directions/, r.summary)
    lean = check("magnification" => "fake", "color" => "real", "hardness" => "real", "acetone" => "real")
    assert_equal :inconclusive, lean.verdict # 6.0 vs 3.75: a strong fake against decent passes is a real conflict
    assert_equal :imitation, lean.lean
    mild = check("color" => "fake", "hardness" => "real")
    assert_equal :inconclusive, mild.verdict
    assert_equal :imitation, mild.lean
    assert_match(/leans towards an imitation/, mild.summary)
  end

  test "bubbles point to glass" do
    r = check("magnification" => "fake", "color" => "real")
    assert_equal ["Purple glass"], r.pointing_to
    assert_match(/glass/, r.summary)
  end

  test "dye on the swab points to dyed stones" do
    r = check("acetone" => "fake", "color" => "fake")
    assert_equal :imitation, r.verdict
    assert_equal ["Dyed quartz or dyed chalcedony"], r.pointing_to
  end

  test "next tests skip answered, unsure and skipped tests and prefer non-destructive" do
    r = check("magnification" => "unsure", "color" => "skipped")
    ids = r.next_tests.map(&:id)
    assert_equal %w[temperature price], ids.first(2)
    assert(r.next_tests.none?(&:destructive?))
  end

  test "destructive tests are offered only when nothing else is left" do
    r = check("magnification" => "real", "color" => "unsure", "temperature" => "unsure", "price" => "skipped")
    assert_equal %w[hardness acetone], r.next_tests.map(&:id)
    assert(r.next_tests.all?(&:destructive?))
  end

  test "when every test is answered the next step is a gemmologist" do
    all = stone.tests.to_h { |t| [t["id"], "unsure"] }
    r = check(all)
    assert_empty r.next_tests
    assert_match(/gemmologist or a lab report/, r.next_step)
  end

  test "suspecting glass nudges glass-related tests up" do
    s = stone(tests: [
      { "id" => "price", "weight" => 2, "how" => "Compare.", "real" => "x", "fake" => "Bargain." },
      { "id" => "temperature", "weight" => 2, "how" => "Cheek.", "real" => "cold", "fake" => "Warms like glass." },
      { "id" => "bubbles", "weight" => 3, "how" => "Loupe.", "real" => "none", "fake" => "Bubbles." }
    ])
    r = check({ "bubbles" => "fake" }, s)
    assert_equal "temperature", r.next_tests.first.id
  end

  test "garbage input is ignored without raising" do
    [nil, "x", 5, [], [1, 2], { "nope" => "fake" }, { "magnification" => "banana" }, { magnification: "FAKE " },
     { "magnification" => ["fake"] }, { "magnification" => { "a" => 1 } }].each do |input|
      assert_nothing_raised { AuthenticityCheck.new(stone, input).result }
    end
    assert_equal :imitation, check(magnification: "FAKE ").verdict
    assert_equal :inconclusive, check("nope" => "fake").verdict
    assert_equal "skipped", AuthenticityCheck.new(stone, "color" => "skip").answer_for("color")
  end

  test "a stone with no tests still returns a result" do
    s = Atlas::Stone.new("slug" => "x", "name" => "X")
    r = AuthenticityCheck.new(s, "a" => "fake").result
    assert_equal :inconclusive, r.verdict
    assert_equal 0, r.total
    assert_match(/do not have home tests/, r.next_step)
  end

  test "bad weights and duplicate or missing ids are tolerated" do
    s = stone(tests: [{ "id" => "color", "weight" => 9, "how" => "a" }, { "id" => "color", "weight" => 1 }, { "weight" => 2 },
                      { "id" => "weight", "weight" => nil }, "junk"])
    tests = AuthenticityCheck.ordered_tests(s)
    assert_equal %w[color weight], tests.map(&:id)
    assert_equal [3, 1], tests.map(&:weight)
  end

  test "diamonds, rubies and sapphires carry the lab-grown note" do
    assert_match(/no home test can tell/, check({}, stone(slug: "diamond", name: "Diamond", species: "diamond")).lab_note)
    assert_match(/no home test can tell/, check({}, stone(slug: "ruby", name: "Ruby", species: "corundum")).lab_note)
    assert_match(/no home test can tell/, check({}, stone(slug: "blue-sapphire", name: "Blue Sapphire", species: "Corundum")).lab_note)
    assert_nil check({}).lab_note
  end

  test "works on the real atlas stones" do
    Atlas.stones.each do |s|
      next if s.tests.empty?

      all_fake = AuthenticityCheck.new(s, s.tests.to_h { |t| [t["id"], "fake"] }).result
      all_real = AuthenticityCheck.new(s, s.tests.to_h { |t| [t["id"], "real"] }).result
      assert_equal :imitation, all_fake.verdict, s.slug
      assert_equal :genuine, all_real.verdict, s.slug
      assert_match(/gemmologist/, all_real.caveat)
    end
  end

  test "malachite resin test points at resin or plastic fakes" do
    m = Atlas["malachite"]
    skip "malachite not in atlas" unless m
    r = AuthenticityCheck.new(m, "flame" => "fake", "weight" => "fake").result
    assert_equal :imitation, r.verdict
    assert(r.pointing_to.any? { |f| f =~ /resin|plastic/i }, r.pointing_to.inspect)
  end
end
