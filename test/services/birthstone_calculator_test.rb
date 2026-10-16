# frozen_string_literal: true

require "test_helper"

class BirthstoneCalculatorTest < ActiveSupport::TestCase
  # A tiny deterministic catalog so tests do not depend on which Atlas files exist.
  FakeEntry = Struct.new(:slug, :name, :zodiac, :planets, :elements, :zodiac_cautions, :summary, :names, :path, keyword_init: true) do
    def local_name(lang) = (names || {})[lang.to_s]
  end

  def stone(slug, name: slug.capitalize, zodiac: [], planets: [], elements: [], cautions: [], names: {}, path: "/gemstones/#{slug}")
    FakeEntry.new(slug: slug, name: name, zodiac: zodiac, planets: planets, elements: elements,
                  zodiac_cautions: cautions, summary: "#{name} summary.", names: names, path: path)
  end

  def catalog
    @catalog ||= [
      stone("amethyst", zodiac: %w[pisces aquarius capricorn virgo], planets: %w[jupiter neptune], elements: %w[air water],
                        names: { "hi" => "Jamunia (जमुनिया), Katela (कटेला)", "bn" => "Katela (কাটেলা)" },
                        cautions: [{ "sign" => "aries", "why" => "Aries is ruled by Mars." }]),
      stone("ruby", zodiac: %w[leo aries], planets: %w[sun mars], elements: %w[fire]),
      stone("emerald", zodiac: %w[gemini virgo taurus], planets: %w[mercury venus], elements: %w[earth]),
      stone("sapphire", zodiac: %w[capricorn taurus], planets: %w[saturn], elements: %w[earth]),
      stone("citrine", zodiac: %w[leo gemini], planets: %w[sun], elements: %w[fire]),
      stone("hematite", zodiac: [], path: nil)
    ]
  end

  def calc(dob: "1990-04-20", rashi: nil, lang: nil, cat: catalog) = BirthstoneCalculator.new(dob: dob, rashi: rashi, lang: lang, catalog: cat)

  # ---- Month table ---------------------------------------------------------

  test "modern list matches the AGTA and Jewelers of America list" do
    expected = {
      "january" => %w[garnet], "february" => %w[amethyst], "march" => %w[aquamarine bloodstone], "april" => %w[diamond],
      "may" => %w[emerald], "june" => %w[pearl moonstone alexandrite], "july" => %w[ruby],
      "august" => %w[peridot spinel sardonyx], "september" => %w[sapphire], "october" => %w[opal tourmaline],
      "november" => %w[topaz citrine], "december" => %w[turquoise zircon tanzanite]
    }
    expected.each { |m, keys| assert_equal keys.sort, BirthstoneCalculator::MONTH_STONES[m][:modern].sort, m }
  end

  test "traditional list is one stone per month" do
    expected = %w[garnet amethyst bloodstone diamond emerald pearl ruby sardonyx sapphire opal topaz turquoise]
    assert_equal expected, BirthstoneCalculator::MONTHS.map { |m| BirthstoneCalculator::MONTH_STONES[m][:traditional].first }
    assert(BirthstoneCalculator::MONTH_STONES.values.all? { |v| v[:traditional].size == 1 })
  end

  test "every table stone has a name, both local names and a blurb" do
    keys = BirthstoneCalculator::MONTH_STONES.values.flat_map { |v| v[:modern] + v[:traditional] }.uniq +
           BirthstoneCalculator::ALSO_SEEN.values.flatten
    keys.each do |k|
      g = BirthstoneCalculator::GEMS[k]
      assert g, "missing GEMS entry for #{k}"
      %i[name hi bn blurb].each { |f| assert g[f].to_s.length > 1, "#{k} missing #{f}" }
    end
  end

  test "month_stones links only live hubs" do
    m = calc.month_stones("february")
    assert_equal "/gemstones/amethyst", m.modern.first.path
    june = calc.month_stones("june")
    assert_equal %w[pearl moonstone alexandrite], june.modern.map(&:key)
    assert_nil june.modern.first.path        # pearl has no hub in this catalog
    assert_equal "Pearl", june.modern.first.name
    assert_includes june.modern.first.summary, "organic"
  end

  test "atlas summary wins over the blurb when a stone is live" do
    assert_equal "Amethyst summary.", calc.month_stones("february").modern.first.summary
  end

  test "month_stones is nil for an unknown month and lists spanned signs" do
    assert_nil calc.month_stones("smarch")
    assert_equal %w[aquarius pisces], calc.month_stones("february").signs
    assert_equal %w[aquarius capricorn], calc.month_stones("january").signs.sort
    assert_equal 2, calc.month_stones("december").signs.size
  end

  test "blue topaz is shown separately for December" do
    d = calc.month_stones("december")
    assert_equal %w[blue-topaz], d.also.map(&:key)
    refute_includes d.modern.map(&:key), "blue-topaz"
  end

  test "every month spans one to three signs and all twelve signs appear" do
    spans = BirthstoneCalculator::MONTHS.map { |m| BirthstoneCalculator.signs_for_month(m) }
    assert spans.all? { |s| (1..3).cover?(s.size) }
    assert_equal Atlas::ZODIAC.sort, spans.flatten.uniq.sort
  end

  # ---- Dates ---------------------------------------------------------------

  test "valid dates parse, leap day included" do
    assert_equal Date.new(2000, 2, 29), calc(dob: "2000-02-29").date
    assert_equal Date.new(1900, 1, 1), calc(dob: "1900-01-01").date
    assert_equal Date.new(2100, 12, 31), calc(dob: "2100-12-31").date
    assert_equal Date.new(1990, 4, 5), calc(dob: "1990-4-5").date
  end

  test "bad dates give a friendly error and no result" do
    ["garbage", "1990-13-01", "2001-02-29", "1990/04/20", "20-04-1990", "1899-12-31", "2101-01-01", "9999-01-01", "'; DROP", "1990-04-20\n1"].each do |bad|
      c = calc(dob: bad)
      assert_nil c.date, bad
      assert c.error.present?, "expected an error for #{bad.inspect}"
      assert_nil c.result, bad
    end
  end

  test "blank, nil and non-string dates are quietly empty" do
    [nil, "", "  ", ["1990-04-20"], { a: 1 }, 5].each do |blank|
      c = calc(dob: blank)
      assert_nil c.error
      assert_nil c.result
    end
  end

  # ---- Western -------------------------------------------------------------

  test "1990-04-20 is tropical Taurus on the cusp and sidereal Aries" do
    r = calc(dob: "1990-04-20").result
    assert_equal "taurus", r.western.sign
    assert r.western.cusp
    assert_equal "aries", r.western.cusp_with
    assert_equal "aries", r.vedic.rashi
    assert_equal :estimated, r.vedic.source
  end

  test "zodiac stones are the catalog stones listing the sign, best first" do
    stones = calc(dob: "1990-04-25").result.western.stones   # Taurus
    assert_equal %w[emerald sapphire], stones.map { |z| z.ref.key }
    assert_includes stones.first.reasons, :ruler            # Venus rules Taurus and the emerald lists Venus
    assert_includes stones.first.reasons, :element          # earth sign, earth stone
  end

  test "the user's own birthstone is nudged up and tagged" do
    # Born in May (emerald) in Gemini: emerald and citrine both list gemini
    stones = calc(dob: "1990-06-01").result.western.stones
    assert_equal "gemini", calc(dob: "1990-06-01").result.western.sign
    assert_equal %w[emerald citrine], stones.map { |z| z.ref.key }   # emerald is Gemini-first and the ruler matches
    may = calc(dob: "1990-05-25").result.western.stones              # Gemini in May
    assert_includes may.find { |z| z.ref.key == "emerald" }.reasons, :birthstone
  end

  test "zodiac cautions come from the atlas data" do
    c = calc(dob: "1990-04-05").result.western       # Aries
    assert_equal "aries", c.sign
    assert_equal %w[amethyst], c.cautions.map { |x| x.ref.key }
    assert_includes c.cautions.first.why, "Mars"
  end

  # ---- Vedic ---------------------------------------------------------------

  test "a selected rashi overrides the date estimate" do
    v = calc(dob: "1990-04-20", rashi: "capricorn").result.vedic
    assert_equal "capricorn", v.rashi
    assert_equal :selected, v.source
    assert_equal "shani", v.ratna.graha
    assert_equal "Blue Sapphire", v.ratna.name
    assert_equal ["Neelam", "नीलम"], v.ratna.hi
    assert_equal ["Neela", "নীলা"], v.ratna.bn
    assert_equal "/gemstones/sapphire", v.ratna.path
  end

  test "every rashi has a lord, a ratna in both scripts and substitutes" do
    Atlas::ZODIAC.each do |sign|
      v = calc(dob: "1990-04-20", rashi: sign).result.vedic
      assert_equal sign, v.rashi
      assert v.ratna.name.present?, sign
      assert v.ratna.hi.last.present? && v.ratna.bn.last.present?, sign
      assert v.lord_names[:hi].last.present?, sign
      assert_equal Atlas::Vedic.rashi_lord(sign), v.ratna.graha
      assert_includes v.cautions, :astrologer
      assert_includes v.cautions, :trial
    end
  end

  test "avoid list is the Navaratna of the lord's natural enemies" do
    v = calc(rashi: "sagittarius").result.vedic     # Jupiter: enemies Mercury and Venus
    assert_equal %w[budh shukra], v.avoid.map(&:graha)
    assert_equal ["Emerald", "Diamond"], v.avoid.map { |a| a.ratna.name }
    cancer = calc(rashi: "cancer").result.vedic       # Moon has no natural enemy
    assert_empty cancer.avoid
  end

  test "Saturn rashis get the strong caution, Venus rashis do not" do
    assert_includes calc(rashi: "aquarius").result.vedic.cautions, :malefic
    refute_includes calc(rashi: "taurus").result.vedic.cautions, :malefic
  end

  test "substitutes link when live and stay unlinked when not" do
    subs = calc(rashi: "capricorn").result.vedic.ratna.substitutes     # amethyst, lapis-lazuli
    assert_equal %w[amethyst lapis-lazuli], subs.map(&:key)
    assert_equal "/gemstones/amethyst", subs.first.path
    assert_nil subs.last.path
    assert_equal "Lapis Lazuli", subs.last.name
    assert_equal "जमुनिया", subs.first.script("hi")
  end

  test "a rashi given alone produces a Vedic-only result" do
    c = calc(dob: nil, rashi: "leo")
    r = c.result
    assert r.rashi_only?
    assert_nil r.birth_month
    assert_equal "surya", r.vedic.ratna.graha
  end

  test "rashi names in Hindi, Bengali and English are accepted; junk is ignored" do
    assert_equal "aries", BirthstoneCalculator.normalize_rashi("Mesh")
    assert_equal "aries", BirthstoneCalculator.normalize_rashi("मेष")
    assert_equal "sagittarius", BirthstoneCalculator.normalize_rashi("ধনু")
    assert_equal "taurus", BirthstoneCalculator.normalize_rashi("Vrishabh (वृषभ)")
    assert_equal "pisces", BirthstoneCalculator.normalize_rashi("PISCES")
    ["", nil, "nonsense", "x" * 500, ["aries"], { a: 1 }, "ophiuchus"].each { |junk| assert_nil BirthstoneCalculator.normalize_rashi(junk), junk.inspect }
  end

  test "navaratna table is complete and uses the live hub when the catalog has one" do
    ruby = calc.ratna_for("surya")
    assert_equal "/gemstones/ruby", ruby.path
    pearl = calc.ratna_for("chandra")
    assert_nil pearl.path
    big = calc(cat: catalog + [stone("pearl")])
    assert_equal "/gemstones/pearl", big.ratna_for("chandra").path
    Atlas::Vedic::NAVARATNA.each_key { |g| assert calc.ratna_for(g).name.present?, g }
  end

  test "sidereal sign changes at Makar Sankranti (Sun enters sidereal Capricorn on 14 Jan 2023, 15:27 UTC)" do
    assert_equal "sagittarius", Atlas::Astro.sidereal_sign(Date.new(2023, 1, 14))[:sign]   # noon UTC, before the ingress
    assert_equal "capricorn", Atlas::Astro.sidereal_sign(Date.new(2023, 1, 15))[:sign]
    assert_equal "capricorn", calc(dob: "2023-01-16").result.vedic.rashi
    assert_equal "shani", calc(dob: "2023-01-16").result.vedic.ratna.graha
  end

  test "sidereal cusp is flagged with the neighbouring sign" do
    v = calc(dob: "2000-04-13").result.vedic      # Mesha Sankranti, 13 April 2000
    assert v.cusp
    assert_includes %w[aries pisces], v.cusp_with
  end

  # ---- Weekday -------------------------------------------------------------

  test "weekday stone follows the ruling planet" do
    expected = { "2024-01-07" => "surya", "2024-01-08" => "chandra", "2024-01-09" => "mangal", "2024-01-10" => "budh",
                 "2024-01-11" => "guru", "2024-01-12" => "shukra", "2024-01-13" => "shani" }
    expected.each do |dob, graha|
      w = calc(dob: dob).result.weekday
      assert_equal graha, w.graha, dob
      assert_equal graha, w.ratna.graha
    end
    w = calc(dob: "2024-01-13").result.weekday
    assert_equal "Saturday", w.names[:en]
    assert_equal "शनिवार", w.names[:hi]
    assert_equal "Blue Sapphire", w.ratna.name
  end

  test "2000-02-29 was a Tuesday" do
    assert_equal "Tuesday", calc(dob: "2000-02-29").result.weekday.names[:en]
    assert_equal "Red Coral", calc(dob: "2000-02-29").result.weekday.ratna.name
  end

  # ---- Languages, edges ----------------------------------------------------

  test "language is normalised and falls back to English" do
    assert_equal "hi", calc(lang: "HI").lang
    assert_equal "en", calc(lang: "fr").lang
    assert_equal "en", calc(lang: nil).lang
    assert_equal "en", calc(lang: ["hi"]).lang
  end

  test "labels translate and fall back" do
    assert_equal "जन्म तिथि", BirthstoneCalculator::Labels.t(:dob, "hi")
    assert_equal "জন্মতারিখ", BirthstoneCalculator::Labels.t(:dob, "bn")
    assert_equal "Date of birth", BirthstoneCalculator::Labels.t(:dob, "xx")
    assert_equal "Born in फ़रवरी".sub("Born in ", "") + " में जन्म", BirthstoneCalculator::Labels.t(:born_in, "hi", month: "फ़रवरी")
    assert_equal "nope", BirthstoneCalculator::Labels.t(:nope, "en")
    BirthstoneCalculator::Labels::STRINGS.each_key do |k|
      %w[en hi bn].each { |l| assert BirthstoneCalculator::Labels.t(k, l).present?, "#{k}/#{l}" }
    end
  end

  test "month names exist in all three languages" do
    assert_equal "फ़रवरी", BirthstoneCalculator.month_name("february", "hi")
    assert_equal "ফেব্রুয়ারি", BirthstoneCalculator.month_name("february", "bn")
    assert_equal "February", BirthstoneCalculator.month_name("february")
    assert_equal 12, BirthstoneCalculator::MONTH_NAMES["hi"].size
    assert_equal 12, BirthstoneCalculator::MONTH_NAMES["bn"].size
  end

  test "works with an empty catalog" do
    r = calc(cat: []).result
    assert_empty r.western.stones
    assert_equal "Ruby", calc(cat: []).ratna_for("surya").name
    assert r.birth_month.modern.present?
  end

  test "extreme dates produce complete results" do
    %w[1900-01-01 2100-12-31 2000-02-29 1999-12-31 2000-01-01].each do |dob|
      r = calc(dob: dob).result
      assert r.western.sign.present? && r.vedic.rashi.present? && r.weekday.graha.present? && r.birth_month.modern.present?, dob
    end
  end

  test "every date in a leap year yields a result without raising" do
    (Date.new(2000, 1, 1)..Date.new(2000, 12, 31)).each do |d|
      r = calc(dob: d.iso8601).result
      assert r.western.sign.present?
    end
  end

  test "stones without a hub point to a related live hub" do
    cat = catalog + [stone("black-tourmaline"), stone("cats-eye")]
    oct = calc(cat: cat).month_stones("october")
    tourmaline = oct.modern.find { |s| s.key == "tourmaline" }
    assert_nil tourmaline.path
    assert_equal %w[black-tourmaline], tourmaline.related.map(&:key)
    assert_equal "/gemstones/black-tourmaline", tourmaline.related.first.path
    assert_empty oct.modern.find { |s| s.key == "opal" }.related
  end

  def related_to(keys) = keys.flat_map { |k| BirthstoneCalculator::RELATED.fetch(k, []) }

  # ---- Against the real Atlas ----------------------------------------------

  test "real atlas: birth months agree with the canonical table for stones that carry them" do
    BirthstoneCalculator::MONTHS.each do |month|
      table = BirthstoneCalculator::MONTH_STONES[month]
      Atlas.stones.each do |s|
        next unless s.modern_birthstone_for.include?(month)

        assert_includes table[:modern] + related_to(table[:modern]), s.slug, "Atlas says #{s.slug} is a modern #{month} birthstone but the calculator table disagrees"
      end
      Atlas.stones.each do |s|
        next unless s.traditional_birthstone_for.include?(month)

        assert_includes table[:traditional] + related_to(table[:traditional]), s.slug, "Atlas says #{s.slug} is a traditional #{month} birthstone but the calculator table disagrees"
      end
    end
  end

  test "real atlas: whole pipeline runs against whatever stones exist" do
    r = BirthstoneCalculator.new(dob: "1990-04-20", catalog: Atlas.stones, lang: "hi").result
    assert r.western.stones.all? { |z| z.ref.key.present? }
    assert r.vedic.ratna.name.present?
  end
end
