# frozen_string_literal: true

require "date"

# Birthstone & Navaratna calculator. Pure Ruby, no view code.
#
#   calc = BirthstoneCalculator.new(dob: "1990-04-20", rashi: nil, lang: "hi", catalog: AtlasEntry.all)
#   calc.error      # => nil or a friendly message
#   calc.result     # => Result, or nil when there is nothing to show yet
#   calc.result.birth_month.modern   # => [StoneRef, ...]
#
# It answers four separate questions and keeps them apart, because they come
# from four different traditions:
#
#   1. Birth-month stones   modern (AGTA / Jewelers of America) and traditional (pre-1912) lists
#   2. Western zodiac       tropical Sun sign, with Atlas stones whose tradition lists that sign
#   3. Vedic ratna          rashi lord -> Navaratna stone, upratna, and what the tradition advises against
#   4. Weekday stone        the planet ruling the weekday of birth
#
# `catalog` is any list of stone-like objects (Atlas::Stone or AtlasEntry). A
# catalog item that responds to `path` is treated as a live hub and linked.
class BirthstoneCalculator
  MONTHS = Atlas::MONTHS
  LANGS = %w[en hi bn].freeze
  LANG_NAMES = { "en" => "English", "hi" => "हिन्दी", "bn" => "বাংলা" }.freeze
  YEARS = (1900..2100)
  DATE_FORMAT = /\A(\d{4})-(\d{1,2})-(\d{1,2})\z/

  MONTH_NAMES = {
    "hi" => %w[जनवरी फ़रवरी मार्च अप्रैल मई जून जुलाई अगस्त सितंबर अक्टूबर नवंबर दिसंबर],
    "bn" => %w[জানুয়ারি ফেব্রুয়ারি মার্চ এপ্রিল মে জুন জুলাই আগস্ট সেপ্টেম্বর অক্টোবর নভেম্বর ডিসেম্বর]
  }.freeze

  # wday (0 = Sunday) -> weekday names and ruling graha.
  WEEKDAYS = [
    { en: "Sunday",    hi: "रविवार",    bn: "রবিবার",       graha: "surya" },
    { en: "Monday",    hi: "सोमवार",    bn: "সোমবার",      graha: "chandra" },
    { en: "Tuesday",   hi: "मंगलवार",   bn: "মঙ্গলবার",    graha: "mangal" },
    { en: "Wednesday", hi: "बुधवार",    bn: "বুধবার",      graha: "budh" },
    { en: "Thursday",  hi: "गुरुवार",   bn: "বৃহস্পতিবার", graha: "guru" },
    { en: "Friday",    hi: "शुक्रवार",  bn: "শুক্রবার",    graha: "shukra" },
    { en: "Saturday",  hi: "शनिवार",    bn: "শনিবার",      graha: "shani" }
  ].freeze

  # Hub slugs to try, in order, for each Navaratna stone. A hub is only linked
  # when the catalog actually has it, so these can name stones the site has
  # not published yet.
  RATNA_HUBS = {
    "surya" => %w[ruby], "chandra" => %w[pearl], "mangal" => %w[red-coral coral],
    "budh" => %w[emerald], "guru" => %w[yellow-sapphire sapphire], "shukra" => %w[diamond],
    "shani" => %w[blue-sapphire sapphire], "rahu" => %w[hessonite hessonite-garnet garnet],
    "ketu" => %w[cats-eye]
  }.freeze

  # Grahas the texts describe as the hardest taskmasters; their stones get the
  # strongest "take advice first" wording.
  CAUTIOUS_GRAHAS = %w[shani rahu ketu mangal].freeze

  # ---- The canonical birthstone table ---------------------------------------
  #
  # Checked October 2026 against GIA (gia.edu/birthstones), the AGTA birthstone
  # GemCards and National Jeweler's history of the list. Trade bodies differ in
  # small ways (the American Gem Society omits moonstone for June; the Jewelers
  # of America list omits bloodstone for March), so this follows the AGTA / JA
  # list that GIA also publishes. Blue topaz is not on that list for December;
  # retailers sell it as one, so it is shown separately under ALSO_SEEN.
  #
  # key = the hub slug the stone would have on writeralpha.com. It is linked
  # only when the catalog has that slug, so stones gain pages without code changes.
  GEMS = {
    "garnet" => { name: "Garnet", hi: "गार्नेट", bn: "গার্নেট",
                  blurb: "Garnet is a family of silicate minerals, best known in deep red but found in almost every colour except blue. At Mohs 6.5 to 7.5 it handles everyday wear well." },
    "amethyst" => { name: "Amethyst", hi: "जमुनिया", bn: "কাটেলা",
                    blurb: "Amethyst is the purple variety of quartz, coloured by iron and natural irradiation. It is hard enough for daily wear but fades in strong sunlight." },
    "aquamarine" => { name: "Aquamarine", hi: "एक्वामरीन", bn: "অ্যাকোয়ামেরিন",
                      blurb: "Aquamarine is the blue to blue-green variety of beryl, the same mineral as emerald, but usually far cleaner. At Mohs 7.5 to 8 it suits rings." },
    "bloodstone" => { name: "Bloodstone", hi: "ब्लडस्टोन", bn: "ব্লাডস্টোন",
                      blurb: "Bloodstone, also called heliotrope, is dark green chalcedony speckled with red iron-oxide spots. Tradition links it with courage and the month of March." },
    "diamond" => { name: "Diamond", hi: "हीरा", bn: "হীরা",
                   blurb: "Diamond is pure carbon and the hardest natural gem at Mohs 10, though a hard blow can still chip it along its cleavage." },
    "emerald" => { name: "Emerald", hi: "पन्ना", bn: "পান্না",
                   blurb: "Emerald is the green variety of beryl, coloured by chromium or vanadium. Nearly all emeralds contain fissures and are routinely oil-filled, so gentle care matters." },
    "pearl" => { name: "Pearl", hi: "मोती", bn: "মুক্তা",
                 blurb: "Pearl is an organic gem grown inside a living mollusc. It is soft (Mohs 2.5 to 4.5) and is marked by acids, perfume and sweat, so put it on last and wipe it after wearing." },
    "moonstone" => { name: "Moonstone", hi: "चंद्रकांत मणि", bn: "চন্দ্রকান্তমণি",
                     blurb: "Moonstone is a feldspar with a soft, floating glow called adularescence. It is only Mohs 6 to 6.5 and cleaves, so it needs protective settings." },
    "alexandrite" => { name: "Alexandrite", hi: "एलेक्ज़ेंड्राइट", bn: "অ্যালেক্সান্ড্রাইট",
                       blurb: "Alexandrite is a colour-change chrysoberyl, greenish in daylight and reddish in incandescent light. Natural stones are rare, and most sold today are lab-created." },
    "ruby" => { name: "Ruby", hi: "माणिक", bn: "চুনি",
                blurb: "Ruby is the red variety of corundum, coloured by chromium. At Mohs 9 it is one of the toughest gems for daily wear." },
    "peridot" => { name: "Peridot", hi: "पेरिडॉट", bn: "পেরিডট",
                   blurb: "Peridot is the gem form of olivine, always some shade of green. It forms deep in the Earth and has even been found in meteorites. At Mohs 6.5 to 7 it scratches over time." },
    "spinel" => { name: "Spinel", hi: "स्पिनेल", bn: "স্পিনেল",
                  blurb: "Spinel is a hard (Mohs 8), naturally brilliant gem in red, pink, blue and violet. Famous 'rubies' in royal collections turned out to be spinel. It joined the official August list in 2016." },
    "sardonyx" => { name: "Sardonyx", hi: "सार्डोनिक्स", bn: "সার্ডোনিক্স",
                    blurb: "Sardonyx is banded chalcedony, with reddish-brown sard layers alternating with white onyx. It has been carved into cameos and seals since antiquity." },
    "sapphire" => { name: "Sapphire", hi: "नीलम", bn: "নীলা",
                    blurb: "Sapphire is corundum in any colour except red. Blue is the classic, but yellow, pink and the pink-orange padparadscha are all sapphire. At Mohs 9 it is exceptionally durable." },
    "opal" => { name: "Opal", hi: "ओपल", bn: "ওপাল",
                blurb: "Opal is a hydrated silica whose tiny spheres diffract light into play-of-colour. It contains water and can crack if dried out or knocked, so it needs gentle handling." },
    "tourmaline" => { name: "Tourmaline", hi: "टूरमलीन", bn: "টুরমালিন",
                      blurb: "Tourmaline is a complex boron silicate found in nearly every colour, often two or three in one crystal, as in 'watermelon' tourmaline. It is Mohs 7 to 7.5." },
    "topaz" => { name: "Topaz", hi: "टोपाज़", bn: "টোপাজ",
                 blurb: "Topaz is hard (Mohs 8) but has a perfect cleavage, so a sharp knock can split it. Imperial topaz is golden-orange to pink. Do not confuse it with the Indian ratna called Pukhraj, which is yellow sapphire." },
    "citrine" => { name: "Citrine", hi: "सिट्रीन", bn: "সিট্রিন",
                   blurb: "Citrine is the yellow to orange variety of quartz. Most citrine on the market is heat-treated amethyst, and it is hard and affordable." },
    "turquoise" => { name: "Turquoise", hi: "फ़िरोज़ा", bn: "ফিরোজা",
                     blurb: "Turquoise is a soft, porous copper aluminium phosphate (Mohs 5 to 6). It is often stabilised, and skin oils, cosmetics and acids can discolour it." },
    "zircon" => { name: "Zircon", hi: "ज़िरकॉन", bn: "জিরকন",
                  blurb: "Zircon is a natural mineral, not cubic zirconia. It has high brilliance and comes in many colours, and blue zircon is usually heat-treated brown stone. It is brittle, so avoid hard knocks." },
    "tanzanite" => { name: "Tanzanite", hi: "टैंज़ानाइट", bn: "ট্যানজানাইট",
                     blurb: "Tanzanite is the blue-violet variety of zoisite, mined commercially only in the Merelani Hills of Tanzania. Nearly all of it is heat-treated, and at Mohs 6 to 7 it suits earrings and pendants best." },
    "blue-topaz" => { name: "Blue topaz", hi: "ब्लू टोपाज़", bn: "ব্লু টোপাজ",
                      blurb: "Almost all blue topaz is colourless topaz that has been irradiated and heated. It is a stable, affordable stone that many retailers sell as the December birthstone." }
  }.freeze

  MONTH_STONES = {
    "january"   => { modern: %w[garnet], traditional: %w[garnet] },
    "february"  => { modern: %w[amethyst], traditional: %w[amethyst] },
    "march"     => { modern: %w[aquamarine bloodstone], traditional: %w[bloodstone] },
    "april"     => { modern: %w[diamond], traditional: %w[diamond] },
    "may"       => { modern: %w[emerald], traditional: %w[emerald] },
    "june"      => { modern: %w[pearl moonstone alexandrite], traditional: %w[pearl] },
    "july"      => { modern: %w[ruby], traditional: %w[ruby] },
    "august"    => { modern: %w[peridot spinel sardonyx], traditional: %w[sardonyx] },
    "september" => { modern: %w[sapphire], traditional: %w[sapphire] },
    "october"   => { modern: %w[opal tourmaline], traditional: %w[opal] },
    "november"  => { modern: %w[topaz citrine], traditional: %w[topaz] },
    "december"  => { modern: %w[turquoise zircon tanzanite], traditional: %w[turquoise] }
  }.freeze

  # Stones sold as a month's birthstone by retailers but absent from the
  # AGTA / Jewelers of America list.
  ALSO_SEEN = { "december" => %w[blue-topaz] }.freeze

  # Live hubs worth pointing to from a birthstone that has no page of its own
  # (a variety or close relative). Shown as "related", never as the stone itself.
  RELATED = {
    "tourmaline" => %w[black-tourmaline],
    "alexandrite" => %w[cats-eye],
    "moonstone" => %w[peach-moonstone black-moonstone],
    "topaz" => %w[blue-topaz]
  }.freeze

  # ---- Result types ---------------------------------------------------------

  # A stone as shown to the user: canonical name, local names, and the live hub
  # entry when the site has one.
  class StoneRef
    attr_reader :key, :name, :hi, :bn, :entry, :blurb, :related

    def initialize(key:, name:, hi: nil, bn: nil, entry: nil, blurb: nil, related: [])
      @key = key
      @name = name
      @hi = hi
      @bn = bn
      @entry = entry
      @blurb = blurb
      @related = related
    end

    def path = entry.respond_to?(:path) ? entry.path : nil
    def live? = !path.nil?

    # Atlas summary when the stone has a file, else the hand-written blurb.
    def summary
      from_atlas = entry.respond_to?(:summary) ? entry.summary.to_s : ""
      from_atlas.empty? ? blurb.to_s : from_atlas
    end

    # Script name for hi / bn, or nil (English shows `name`).
    def script(lang) = { "hi" => hi, "bn" => bn }[lang.to_s]
  end

  # A Navaratna stone with the graha it belongs to.
  class Ratna
    attr_reader :graha, :graha_names, :name, :hi, :bn, :entry, :substitutes

    # hi / bn / graha_names are [roman, script] pairs.
    def initialize(graha:, graha_names:, name:, hi:, bn:, entry:, substitutes:)
      @graha = graha
      @graha_names = graha_names
      @name = name
      @hi = hi
      @bn = bn
      @entry = entry
      @substitutes = substitutes
    end

    def path = entry.respond_to?(:path) ? entry.path : nil
    def live? = !path.nil?
    def pair(lang) = { "hi" => hi, "bn" => bn }[lang.to_s]
    def graha_en = graha_names[:en]
    def graha_pair(lang) = graha_names[lang.to_s.to_sym]
    def cautious? = CAUTIOUS_GRAHAS.include?(graha)
  end

  ZodiacStone = Struct.new(:ref, :score, :reasons, keyword_init: true)
  ZodiacCaution = Struct.new(:ref, :why, keyword_init: true)
  AvoidItem = Struct.new(:graha, :graha_names, :ratna, keyword_init: true)

  BirthMonth = Struct.new(:month, :number, :modern, :traditional, :also, :signs, keyword_init: true)
  Western = Struct.new(:sign, :degree, :cusp, :cusp_with, :ruler, :element, :dates, :stones, :cautions, keyword_init: true)
  Vedic = Struct.new(:rashi, :source, :cusp, :cusp_with, :lord_names, :ratna, :avoid, :cautions, keyword_init: true) do
    def estimated? = source == :estimated
  end
  Weekday = Struct.new(:wday, :names, :graha, :ratna, keyword_init: true)
  Result = Struct.new(:date, :lang, :birth_month, :western, :vedic, :weekday, keyword_init: true) do
    def rashi_only? = date.nil?
  end

  attr_reader :error, :lang, :date, :rashi, :catalog

  # dob: "YYYY-MM-DD" (String) or Date; rashi: sign slug or a Hindi/English
  # rashi name; lang: en / hi / bn. Bad input never raises: an unusable date
  # sets #error, and an unknown rashi or language is ignored.
  def initialize(dob: nil, rashi: nil, lang: nil, catalog: nil)
    @lang = self.class.normalize_lang(lang)
    @rashi = self.class.normalize_rashi(rashi)
    @catalog = catalog || Atlas.stones
    @date, @error = self.class.parse_date(dob)
    @by_slug = nil
  end

  # A result needs a valid date of birth. A known rashi alone is enough for
  # the Vedic card, which is what many Indian searchers have in hand.
  def result
    return @result if defined?(@result)

    @result = if date
      Result.new(date: date, lang: lang, birth_month: month_stones(MONTHS[date.month - 1]), western: western_for(date),
                 vedic: vedic_for(date, rashi), weekday: weekday_for(date))
    elsif rashi && error.nil?
      Result.new(date: nil, lang: lang, vedic: vedic_for(nil, rashi))
    end
  end

  def result? = !result.nil?

  # ---- Class-level helpers (also used by the views) -------------------------

  class << self
    def normalize_lang(lang)
      l = lang.to_s.strip.downcase
      LANGS.include?(l) ? l : "en"
    end

    # Accepts "aries", "Mesh", "मेष", "Dhanu (धनु)". Returns the English sign slug or nil.
    def normalize_rashi(value)
      v = value.to_s.strip.downcase
      return nil if v.empty? || v.length > 40
      return v if Atlas::ZODIAC.include?(v)

      rashi_aliases[v]
    end

    def rashi_aliases
      @rashi_aliases ||= Atlas::Vedic::RASHI.each_with_object({}) do |(sign, row), h|
        [row[:hi], row[:bn]].each do |str|
          roman, script = split_pair(str)
          h[roman.downcase] = sign
          h[script.to_s] = sign if script
          h[str.downcase] = sign
        end
      end.freeze
    end

    # Returns [Date or nil, error message or nil]. Blank input is not an error.
    def parse_date(value)
      return [value, nil] if value.is_a?(Date)

      str = value.is_a?(String) ? value.strip : ""
      return [nil, nil] if str.empty?

      m = DATE_FORMAT.match(str)
      return [nil, "Please enter your date of birth as YYYY-MM-DD, for example 1990-04-20."] unless m

      y, mo, d = m.captures.map(&:to_i)
      return [nil, "We calculate sun positions for the years #{YEARS.first} to #{YEARS.last}. Please enter a date in that range."] unless YEARS.cover?(y)
      return [nil, "That date does not exist on the calendar. Please check the day and month."] unless Date.valid_date?(y, mo, d)

      [Date.new(y, mo, d), nil]
    end

    # "Manik (माणिक)" => ["Manik", "माणिक"]; "Amatista" => ["Amatista", nil]
    def split_pair(str)
      s = str.to_s.strip
      m = /\A(.+?)\s*\(([^)]+)\)\z/.match(s)
      m ? [m[1].strip, m[2].strip] : [s, nil]
    end

    # Every "Roman (script)" pair in a string like "Jamunia (जमुनिया), Katela (कटेला)".
    def split_pairs(str)
      found = str.to_s.scan(/([^,()]+?)\s*\(([^)]+)\)/).map { |r, s| [r.strip, s.strip] }
      found.empty? && !str.to_s.strip.empty? ? [[str.to_s.strip, nil]] : found
    end

    def month_number(month) = MONTHS.index(month.to_s.downcase)&.+(1)
    def month_name(month, lang = "en")
      n = month_number(month) or return month.to_s
      lang.to_s == "en" ? MONTHS[n - 1].capitalize : (MONTH_NAMES.dig(lang.to_s, n - 1) || MONTHS[n - 1].capitalize)
    end

    def weekday_name(wday, lang = "en") = WEEKDAYS[wday].then { |w| w[lang.to_s.to_sym] || w[:en] }

    # [roman, script] for a rashi / western sign.
    def sign_pair(sign, lang)
      row = Atlas::Vedic::RASHI[sign]
      return [sign.to_s.capitalize, nil] unless row && %w[hi bn].include?(lang.to_s)

      split_pair(row[lang.to_s.to_sym])
    end

    # Planet name in the reader's language. Hindi/Bengali exist for the seven
    # visible planets (via the graha table); outer planets stay in English.
    def planet_label(planet, lang)
      english = planet.to_s.capitalize
      return english unless %w[hi bn].include?(lang.to_s)

      graha = Atlas::Vedic::GRAHAS.values.find { |g| g[:western] == planet.to_s }
      graha ? (split_pair(graha[lang.to_sym]).last || english) : english
    end

    def rashi_options
      Atlas::ZODIAC.map do |sign|
        row = Atlas::Vedic::RASHI[sign]
        { sign: sign, en: sign.capitalize, hi: split_pair(row[:hi]), bn: split_pair(row[:bn]), lord: row[:lord] }
      end
    end

    # Tropical signs whose usual date range touches `month` (from Astro::SIGN_DATES).
    def signs_for_month(month)
      n = month_number(month) or return []
      Atlas::Astro::SIGN_DATES.filter_map do |sign, range|
        months = range.scan(/[A-Z][a-z]{2}/).map { |abbr| Date::ABBR_MONTHNAMES.index(abbr) }.compact
        sign if months.include?(n)
      end
    end

    # Convenience for the embeds: month stones without a full calculator.
    def for_month(month, catalog: nil) = new(catalog: catalog).month_stones(month)
  end

  # ---- Birth month ----------------------------------------------------------

  def month_stones(month)
    row = MONTH_STONES[month.to_s.downcase] or return nil
    key = month.to_s.downcase
    BirthMonth.new(
      month: key, number: MONTHS.index(key) + 1,
      modern: row[:modern].map { |k| stone_ref(k) },
      traditional: row[:traditional].map { |k| stone_ref(k) },
      also: Array(ALSO_SEEN[key]).map { |k| stone_ref(k) },
      signs: self.class.signs_for_month(key)
    )
  end

  # ---- Western zodiac -------------------------------------------------------

  def western_for(date)
    t = Atlas::Astro.tropical_sign(date)
    sign = t[:sign]
    month_keys = month_keys_for(date.month)
    Western.new(
      sign: sign, degree: t[:degree], cusp: t[:cusp], cusp_with: t[:cusp] ? neighbour(sign, t[:degree]) : nil,
      ruler: Atlas::Astro::SIGN_RULER[sign], element: Atlas::Astro::SIGN_ELEMENT[sign],
      dates: Atlas::Astro::SIGN_DATES[sign],
      stones: zodiac_stones(sign, month_keys), cautions: zodiac_cautions(sign)
    )
  end

  # Stones whose Atlas tradition lists `sign`, best fit first. The order a
  # curator wrote the list is the first signal (earlier = more commonly
  # assigned); a matching ruling planet or element and being your own
  # birthstone nudge a stone up.
  def zodiac_stones(sign, month_keys = [])
    ruler = Atlas::Astro::SIGN_RULER[sign]
    element = Atlas::Astro::SIGN_ELEMENT[sign]
    scored = catalog.filter_map do |s|
      idx = Array(s.zodiac).index(sign) or next
      reasons = [:listed]
      score = 100 - (idx * 6)
      if ruler && Array(s.planets).include?(ruler)
        score += 12
        reasons << :ruler
      end
      if Array(s.elements).include?(element)
        score += 6
        reasons << :element
      end
      if month_keys.include?(s.slug)
        score += 8
        reasons << :birthstone
      end
      ZodiacStone.new(ref: ref_for_catalog_stone(s), score: score, reasons: reasons)
    end
    scored.sort_by { |z| [-z.score, z.ref.name] }
  end

  def zodiac_cautions(sign)
    catalog.filter_map do |s|
      c = Array(s.zodiac_cautions).find { |z| z["sign"] == sign } or next
      ZodiacCaution.new(ref: ref_for_catalog_stone(s), why: c["why"].to_s)
    end.sort_by { |c| c.ref.name }
  end

  # ---- Vedic ----------------------------------------------------------------

  # `date` may be nil when only a rashi is known.
  def vedic_for(date, rashi)
    cusp = false
    cusp_with = nil
    if rashi
      sign = rashi
      source = :selected
    else
      est = Atlas::Astro.sidereal_sign(date)
      sign = est[:sign]
      source = :estimated
      cusp = est[:cusp]
      cusp_with = neighbour(sign, est[:degree]) if cusp
    end

    lord = Atlas::Vedic.rashi_lord(sign)
    ratna = ratna_for(lord)
    avoid = Atlas::Vedic::ENEMIES.fetch(lord, []).map do |enemy|
      r = ratna_for(enemy)
      AvoidItem.new(graha: enemy, graha_names: r.graha_names, ratna: r)
    end

    Vedic.new(rashi: sign, source: source, cusp: cusp, cusp_with: cusp_with,
              lord_names: ratna.graha_names, ratna: ratna, avoid: avoid,
              cautions: vedic_cautions(ratna))
  end

  # Symbols; the view turns them into copy (see Labels).
  def vedic_cautions(ratna)
    list = %i[astrologer trial]
    list << :malefic if ratna.cautious?
    list << :quality
  end

  def ratna_for(graha)
    ratna_cache[graha] ||= begin
      row = Atlas::Vedic::NAVARATNA.fetch(graha)
      g = Atlas::Vedic::GRAHAS.fetch(graha)
      slugs = (RATNA_HUBS.fetch(graha, []) + [row[:slug]]).compact.uniq
      entry = slugs.filter_map { |s| by_slug[s] }.first
      subs = row[:substitutes].map { |slug| substitute_ref(slug) }
      Ratna.new(
        graha: graha,
        graha_names: { en: g[:en], hi: self.class.split_pair(g[:hi]), bn: self.class.split_pair(g[:bn]) },
        name: row[:stone], hi: self.class.split_pair(row[:hi]), bn: self.class.split_pair(row[:bn]),
        entry: entry && entry.respond_to?(:path) ? entry : nil, substitutes: subs
      )
    end
  end

  # ---- Weekday --------------------------------------------------------------

  def weekday_for(date)
    w = WEEKDAYS[date.wday]
    Weekday.new(wday: date.wday, names: w.slice(:en, :hi, :bn), graha: w[:graha], ratna: ratna_for(w[:graha]))
  end

  # ---- Stone references -----------------------------------------------------

  # A canonical birthstone (or an unknown key, which still renders unlinked).
  def stone_ref(key)
    meta = GEMS[key]
    entry = by_slug[key]
    atlas_name = entry.respond_to?(:name) ? entry.name : nil
    StoneRef.new(key: key, name: atlas_name || meta&.dig(:name) || key.tr("-", " ").capitalize,
                 hi: meta&.dig(:hi) || script_from_atlas(entry, "hi"), bn: meta&.dig(:bn) || script_from_atlas(entry, "bn"),
                 entry: live(entry), blurb: meta&.dig(:blurb), related: related_refs(key))
  end

  private

  def by_slug = (@by_slug ||= catalog.to_h { |s| [s.slug, s] })
  def ratna_cache = (@ratna_cache ||= {})
  def live(entry) = entry.respond_to?(:path) ? entry : nil

  def month_keys_for(month_number)
    row = MONTH_STONES[MONTHS[month_number - 1]] or return []
    (row[:modern] + row[:traditional]).uniq
  end

  def ref_for_catalog_stone(s)
    meta = GEMS[s.slug]
    StoneRef.new(key: s.slug, name: s.name, hi: script_from_atlas(s, "hi") || meta&.dig(:hi),
                 bn: script_from_atlas(s, "bn") || meta&.dig(:bn), entry: live(s), blurb: meta&.dig(:blurb))
  end

  # Live related hubs, only for stones that have no live hub themselves.
  def related_refs(key)
    return [] if live(by_slug[key])

    RELATED.fetch(key, []).filter_map do |slug|
      e = live(by_slug[slug]) or next
      StoneRef.new(key: slug, name: e.name, entry: e)
    end
  end

  def substitute_ref(slug)
    entry = by_slug[slug]
    name = entry.respond_to?(:name) ? entry.name : slug.tr("-", " ").split.map(&:capitalize).join(" ")
    StoneRef.new(key: slug, name: name, hi: script_from_atlas(entry, "hi"), bn: script_from_atlas(entry, "bn"), entry: live(entry))
  end

  # First script name in an Atlas `names.hi / names.bn` value.
  def script_from_atlas(entry, lang)
    return nil unless entry.respond_to?(:local_name)

    self.class.split_pairs(entry.local_name(lang)).filter_map(&:last).first
  end

  # The sign on the other side of a boundary, given the degree within a sign.
  def neighbour(sign, degree)
    i = Atlas::ZODIAC.index(sign)
    Atlas::ZODIAC[(i + (degree < 1.0 ? -1 : 1)) % 12]
  end
end
