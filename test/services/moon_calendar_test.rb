require "test_helper"

class MoonCalendarTest < ActiveSupport::TestCase
  USNO = File.readlines(File.expand_path("moon_calendar_usno.csv", __dir__), chomp: true)
             .reject { |l| l.start_with?("#") || l.strip.empty? }
             .map { |l| t, k = l.split(","); [Time.utc(*t.scan(/\d+/).map(&:to_i)), k.to_sym] }

  def utc(*parts) = Time.utc(*parts)

  # ---- Phase instants vs published times ---------------------------------

  test "reference instants match USNO / timeanddate within 5 minutes" do
    refs = [
      [:full_moon, utc(2026, 10, 26, 4, 12)], [:full_moon, utc(2026, 11, 24, 14, 53)],
      [:full_moon, utc(2026, 12, 24, 1, 28)], [:full_moon, utc(2027, 1, 22, 12, 17)],
      [:full_moon, utc(2027, 2, 20, 23, 23)], [:full_moon, utc(2027, 9, 15, 23, 3)],
      [:new_moon, utc(2026, 10, 10, 15, 50)], [:new_moon, utc(2026, 11, 9, 7, 2)],
      [:first_quarter, utc(2026, 10, 18, 16, 12)], [:last_quarter, utc(2026, 11, 1, 20, 28)],
      [:full_moon, utc(1950, 1, 4, 7, 48)], [:last_quarter, utc(2100, 1, 3, 13, 5)]
    ]
    refs.each do |kind, expected|
      got = MoonCalendar.next_phase(kind, expected - 3 * 86_400).time
      assert_in_delta expected.to_f, got.to_f, 5 * 60, "#{kind} near #{expected}: got #{got}"
    end
  end

  test "every USNO phase 1950-2100 is within 3 minutes" do
    assert_operator USNO.size, :>, 800
    worst = USNO.map do |expected, kind|
      got = MoonCalendar.next_phase(kind, expected - 3 * 3600).time
      (got - expected).abs
    end.max
    assert_operator worst, :<, 180, "worst error #{worst.round}s"
  end

  test "phases come out ordered, alternating, about 7.4 days apart" do
    list = MoonCalendar.phases(utc(2026, 1, 1), utc(2027, 1, 1))
    assert_includes 49..50, list.size
    list.each_cons(2) do |a, b|
      assert_operator b.time, :>, a.time
      assert_equal MoonCalendar::PHASE_KINDS[(MoonCalendar::PHASE_KINDS.index(a.kind) + 1) % 4], b.kind
      assert_in_delta 7.4, (b.time - a.time) / 86_400, 1.1
    end
  end

  test "next and previous phase bracket an instant" do
    t = utc(2026, 10, 16, 12)
    assert_in_delta utc(2026, 10, 26, 4, 12).to_f, MoonCalendar.next_phase(:full_moon, t).time.to_f, 120
    assert_in_delta utc(2026, 9, 26, 16, 49).to_f, MoonCalendar.previous_phase(:full_moon, t).time.to_f, 120
    assert_equal 13, MoonCalendar.next_full_moons(t, 13).size
  end

  # ---- Zodiac, names, special moons --------------------------------------

  test "moon sign at full and new moons" do
    nov = MoonCalendar.next_phase(:full_moon, utc(2026, 11, 20))
    assert_equal "gemini", nov.sign
    assert_equal "air", nov.element
    assert_equal "sagittarius", nov.sun_sign
    assert_equal "cancer", MoonCalendar.next_phase(:full_moon, utc(2026, 12, 20)).sign
    assert_equal "libra", MoonCalendar.next_phase(:new_moon, utc(2026, 10, 5)).sign
    assert_equal "scorpio", MoonCalendar.next_phase(:new_moon, utc(2026, 11, 5)).sign
    assert_equal "♊\uFE0E", nov.glyph
  end

  test "full moon is opposite the sun and new moon is with the sun" do
    full = MoonCalendar.next_phase(:full_moon, utc(2026, 11, 20))
    assert_in_delta 180, (full.moon_longitude - full.sun_longitude) % 360, 0.001
    new = MoonCalendar.next_phase(:new_moon, utc(2026, 11, 5))
    assert_in_delta new.sun_longitude, new.moon_longitude, 0.001
  end

  test "traditional names, harvest moon and hunter's moon" do
    name = ->(t) { MoonCalendar.full_moon_name(MoonCalendar.next_phase(:full_moon, t)) }
    assert_equal ["Wolf Moon", nil], name.call(utc(2027, 1, 20))
    assert_equal ["Cold Moon", nil], name.call(utc(2026, 12, 20))
    assert_equal ["Beaver Moon", nil], name.call(utc(2026, 11, 20))
    assert_equal ["Hunter's Moon", nil], name.call(utc(2026, 10, 20))
    assert_equal ["Harvest Moon", "also called the Corn Moon"], name.call(utc(2026, 9, 20))
    assert_equal ["Strawberry Moon", nil], name.call(utc(2026, 6, 20))
    # 2025: the full moon nearest the equinox (Sep 22) is Oct 7 (UTC), so September's is the Corn Moon
    assert_equal ["Corn Moon", nil], name.call(utc(2025, 9, 1))
    assert_equal ["Harvest Moon", nil], name.call(utc(2025, 10, 1))
    assert_in_delta utc(2025, 10, 7, 3, 47).to_f, MoonCalendar.harvest_moon(2025).time.to_f, 120
  end

  test "september equinox" do
    assert_in_delta utc(2026, 9, 23, 0, 5).to_f, MoonCalendar.september_equinox(2026).to_f, 20 * 60
  end

  test "blue moon is the second full moon in a calendar month" do
    assert MoonCalendar.blue_moon?(MoonCalendar.next_phase(:full_moon, utc(2026, 5, 20)))      # May 1 and May 31
    refute MoonCalendar.blue_moon?(MoonCalendar.next_phase(:full_moon, utc(2026, 4, 20)))
    refute MoonCalendar.blue_moon?(MoonCalendar.next_phase(:full_moon, utc(2026, 5, 1, 12)).then { |_| MoonCalendar.next_phase(:full_moon, utc(2026, 4, 25)) })
    assert MoonCalendar.blue_moon?(MoonCalendar.next_phase(:full_moon, utc(2023, 8, 20)))      # Aug 1 and Aug 31, 2023
    # Blue Moon is counted by the dates in the chosen zone: 2028-12-31 16:48 UTC is Jan 1 in Auckland
    dec = MoonCalendar.next_phase(:full_moon, utc(2028, 12, 25))
    assert MoonCalendar.blue_moon?(dec)
    refute MoonCalendar.blue_moon?(dec, zone: "Pacific/Auckland")
    assert MoonCalendar.blue_moon?(dec, zone: "Pacific/Honolulu")
  end

  test "month listing respects the time zone and valid range" do
    assert_equal 4, MoonCalendar.month(2026, 11).size
    ist = MoonCalendar.month(2026, 11, zone: "Asia/Kolkata")
    assert ist.all? { |p| p.time.in_time_zone("Asia/Kolkata").month == 11 }
    assert MoonCalendar.valid_month?(1950, 1)
    assert MoonCalendar.valid_month?(2100, 12)
    refute MoonCalendar.valid_month?(1949, 12)
    refute MoonCalendar.valid_month?(2101, 1)
    refute MoonCalendar.valid_month?(2026, 13)
    refute MoonCalendar.valid_month?(2026, 0)
  end

  test "february can have no full moon (2018)" do
    assert_empty MoonCalendar.month(2018, 2).select(&:full?)
  end

  # ---- Phase of the moon now ---------------------------------------------

  test "state" do
    full = MoonCalendar.next_phase(:full_moon, utc(2026, 10, 20))
    assert_in_delta 1.0, MoonCalendar.state(full.time)[:illumination], 0.001
    assert_equal "Full Moon", MoonCalendar.state(full.time)[:name]
    new = MoonCalendar.next_phase(:new_moon, utc(2026, 10, 5))
    assert_operator MoonCalendar.state(new.time)[:illumination], :<, 0.001
    assert_equal "New Moon", MoonCalendar.state(new.time)[:name]
    s = MoonCalendar.state(utc(2026, 10, 16, 12))
    assert s[:waxing]
    assert_equal "Waxing Crescent", s[:name]
    assert_in_delta 0.3, s[:illumination], 0.05
    assert_equal "Waning Gibbous", MoonCalendar.state(full.time + 3 * 86_400)[:name]
  end

  # ---- Formatting -----------------------------------------------------------

  test "time zone validation" do
    assert_equal "Asia/Kolkata", MoonCalendar::Format.zone("Asia/Kolkata").tzinfo.name
    assert_equal "UTC", MoonCalendar::Format.zone_id(MoonCalendar::Format.zone("UTC"))
    ["", "5", "Mars/Olympus", "../../etc/passwd", "a" * 100, "<script>", nil, 12].each do |bad|
      assert_nil MoonCalendar::Format.zone(bad), bad.inspect
    end
  end

  test "countdown" do
    now = utc(2026, 10, 16, 12)
    assert_equal "in 9 days 16 hours", MoonCalendar::Format.countdown(utc(2026, 10, 26, 4, 12), now)
    assert_equal "in 3 hours", MoonCalendar::Format.countdown(now + 3 * 3600 + 60, now)
    assert_equal "in under an hour", MoonCalendar::Format.countdown(now + 600, now)
  end

  # ---- Guidance ---------------------------------------------------------------

  Stone = Struct.new(:slug, :name, :zodiac, :elements, :planets, :intentions, :water, :sun, :elixir, :toxicity, :water_reason, keyword_init: true) do
    def safety(key) = { "water" => water, "sun" => sun }[key]
    def safety_reason(_key) = water_reason.to_s
    def toxicity_reason = ""
  end

  def stones
    [Stone.new(slug: "amethyst", name: "Amethyst", zodiac: %w[gemini], elements: %w[air], planets: [], intentions: %w[clarity], water: "safe", sun: "limit", elixir: "direct", toxicity: "none"),
     Stone.new(slug: "selenite", name: "Selenite", zodiac: %w[taurus], elements: %w[air], planets: %w[moon], intentions: [], water: "avoid", sun: "limit", elixir: "never", toxicity: "none", water_reason: "Dissolves."),
     Stone.new(slug: "agate", name: "Agate", zodiac: %w[gemini], elements: %w[earth], planets: %w[mercury], intentions: %w[communication], water: "safe", sun: "safe", elixir: "indirect", toxicity: "none"),
     Stone.new(slug: "malachite", name: "Malachite", zodiac: %w[capricorn], elements: %w[earth], planets: [], intentions: [], water: "safe", sun: "safe", elixir: "never", toxicity: "caution", water_reason: "Toxic.")]
  end

  test "guidance picks stones by sign and element, and guards moon water" do
    event = MoonCalendar.next_phase(:full_moon, utc(2026, 11, 20)) # Gemini, air
    g = MoonCalendar::Guidance.for_event(event, stones: stones)
    assert_equal %w[agate amethyst], g.charge.map { |p| p.stone.slug }.sort
    assert_equal %w[amethyst], g.water_ok.map(&:slug)
    assert_equal %w[agate], g.water_indirect.map(&:slug)
    assert_equal %w[malachite selenite], g.water_no.map { |p| p.stone.slug }.sort
    assert_includes g.fade_stones.map(&:slug), "amethyst"
    assert_equal %w[Moonstone Selenite], g.always.map { |p| p.stone.respond_to?(:name) ? p.stone.name : p.stone }
    assert_match(/Gemini/, g.intro)
    assert_match(/every stone/, g.moonlight_note)
  end

  test "guidance works with no stones at all" do
    g = MoonCalendar::Guidance.for_event(MoonCalendar.next_phase(:new_moon, utc(2026, 10, 5)), stones: [])
    assert_empty g.charge
    assert_empty g.water_ok
    assert_equal 2, g.always.size
  end

  test "every sign has guidance text" do
    Atlas::ZODIAC.each do |sign|
      theme = MoonCalendar::Guidance::SIGN_THEMES.fetch(sign)
      assert theme[:full].present? && theme[:new].present? && theme[:intentions].all? { |i| Atlas::INTENTIONS.include?(i) }
    end
    MoonCalendar::FULL_MOON_NAMES.each_value { |n| assert MoonCalendar::Guidance::NAME_NOTES.key?(n) }
  end

  # ---- iCalendar ------------------------------------------------------------

  # A strict RFC 5545 structural check for the subset we emit.
  module IcsStrict
    def self.check(text)
      errors = []
      errors << "does not end with CRLF" unless text.end_with?("\r\n")
      errors << "bare LF found" if text.gsub("\r\n", "").include?("\n")
      errors << "bare CR found" if text.gsub("\r\n", "").include?("\r")
      raw = text.split("\r\n")
      raw.each_with_index do |l, i|
        errors << "line #{i + 1} is #{l.bytesize} octets" if l.bytesize > 75
        errors << "line #{i + 1} is not valid UTF-8" unless l.dup.force_encoding("UTF-8").valid_encoding?
      end
      lines = []
      raw.each { |l| l.start_with?(" ", "\t") ? (lines[-1] += l[1..]) : lines << l }
      errors << "first line" unless lines.first == "BEGIN:VCALENDAR"
      errors << "last line" unless lines.last == "END:VCALENDAR"
      stack = []
      uids = []
      event = nil
      lines.each do |l|
        name, value = l.split(":", 2)
        key = name.split(";").first
        case key
        when "BEGIN" then stack << value; event = {} if value == "VEVENT"
        when "END"
          errors << "unbalanced END:#{value}" unless stack.pop == value
          if value == "VEVENT"
            %w[UID DTSTAMP DTSTART SUMMARY DESCRIPTION URL].each { |k| errors << "event missing #{k}" unless event.key?(k) }
            errors << "bad DTSTART #{event['DTSTART']}" unless event["DTSTART"].to_s.match?(/\A\d{8}T\d{6}Z\z/)
            errors << "bad DTSTAMP" unless event["DTSTAMP"].to_s.match?(/\A\d{8}T\d{6}Z\z/)
            errors << "bad UID #{event['UID']}" unless event["UID"].to_s.match?(/\A(full|new|first-quarter|last-quarter)-\d{8}T\d{4}Z@writeralpha\.com\z/)
            uids << event["UID"]
            event = nil
          end
        else
          errors << "line without a property name: #{l[0, 40]}" unless key.match?(/\A[A-Z][A-Z0-9-]*\z/) && value
          event[key] = value if event
        end
      end
      errors << "unbalanced BEGIN/END (#{stack.inspect})" unless stack.empty?
      errors << "duplicate UIDs" unless uids.uniq.size == uids.size
      # unescaped commas/semicolons in TEXT properties
      lines.each do |l|
        next unless l.start_with?("SUMMARY:", "DESCRIPTION:")

        body = l.split(":", 2).last
        errors << "unescaped , or ; in #{l[0, 30]}" if body.gsub("\\\\", "").match?(/(?<!\\)[,;]/)
        errors << "raw backslash-n missing" if l.start_with?("DESCRIPTION:") && !body.include?("\\n")
      end
      errors
    end
  end

  def feed(kinds: %i[full_moon new_moon])
    from = utc(2026, 10, 1)
    events = MoonCalendar.phases(from, from + 24 * 31 * 86_400, kinds: kinds)
    MoonCalendar::Ics.build(events, base_url: "https://writeralpha.com", now: utc(2026, 10, 16, 9), stones: stones)
  end

  test "ics output passes a strict check" do
    ics = feed
    assert_equal [], IcsStrict.check(ics)
    assert_match(/^UID:full-20261124T1453Z@writeralpha\.com\r$/, ics)
    assert_includes ics, "DTSTART:20261124T145300Z\r\n"
    assert_includes ics, "SUMMARY:🌕 Full Moon in Gemini — charge your crystals\r\n"
    assert_includes ics, "URL:https://writeralpha.com/tools/moon-calendar/2026-11\r\n"
    assert_includes ics, "DTSTAMP:20261016T000000Z\r\n"
  end

  test "ics with all phases includes quarters" do
    ics = feed(kinds: MoonCalendar::PHASE_KINDS)
    assert_equal [], IcsStrict.check(ics)
    assert_match(/UID:first-quarter-/, ics)
    assert_match(/UID:last-quarter-/, ics)
  end

  test "ics folds long lines without splitting characters and escapes text" do
    line = "SUMMARY:" + "🌕" * 40
    folded = MoonCalendar::Ics.fold(line)
    assert_operator folded.size, :>, 1
    assert(folded.all? { |l| l.bytesize <= 75 })
    assert(folded.drop(1).all? { |l| l.start_with?(" ") })
    assert_equal line, folded.each_with_index.map { |l, i| i.zero? ? l : l[1..] }.join
    assert_equal "a\\, b\\; c\\\\d\\ne", MoonCalendar::Ics.escape("a, b; c\\d\ne")
  end

  test "strict check catches broken calendars" do
    assert_not_empty IcsStrict.check("BEGIN:VCALENDAR\nEND:VCALENDAR\n")
    assert_not_empty IcsStrict.check("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nEND:VCALENDAR\r\n")
  end

  test "legacy zone names resolve to the current IANA name and read as friendly labels" do
    f = MoonCalendar::Format
    t = utc(2026, 10, 26, 4, 12)
    assert_equal "Asia/Kolkata", f.zone_id(f.zone("Asia/Calcutta"))
    assert_equal "Europe/Kyiv", f.zone_id(f.zone("Europe/Kiev"))
    assert_equal "America/New_York", f.zone_id(f.zone("US/Eastern"))
    assert_equal "India (IST, UTC+5:30)", f.zone_label(t, f.zone("Asia/Calcutta"))
    assert_equal "US Eastern (EDT, UTC-4)", f.zone_label(t, f.zone("America/New_York"))
    assert_equal "UK (GMT)", f.zone_label(utc(2026, 1, 5), f.zone("Europe/London"))
    assert_equal "Buenos Aires (UTC-3)", f.zone_label(t, f.zone("America/Buenos_Aires"))
    assert_equal "UTC", f.zone_label(t, f.zone("Etc/UTC"))
    assert_nil f.zone("Not/AZone")
    assert_nil f.zone("../../etc/passwd")
  end

  test "full moon name follows the month in the zone shown" do
    full = MoonCalendar.next_phase(:full_moon, utc(2018, 1, 30)) # 31 Jan 13:27 UTC, 1 Feb in Auckland
    assert_equal ["Wolf Moon", nil], MoonCalendar.full_moon_name(full)
    assert_equal ["Wolf Moon", nil], MoonCalendar.full_moon_name(full, zone: MoonCalendar::Format.zone("Asia/Kolkata"))
    assert_equal ["Snow Moon", nil], MoonCalendar.full_moon_name(full, zone: MoonCalendar::Format.zone("Pacific/Auckland"))
  end
end
