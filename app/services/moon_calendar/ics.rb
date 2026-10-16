# frozen_string_literal: true

module MoonCalendar
  # RFC 5545 iCalendar writer for moon phases. Lines end in CRLF and are folded
  # at 75 octets (never inside a UTF-8 character); text values are escaped.
  module Ics
    LIMIT = 75
    CRLF = "\r\n"

    module_function

    # events: [MoonCalendar::Event]; stones: Atlas stones used for the description.
    # base_url: "https://writeralpha.com" (no trailing slash).
    def build(events, base_url:, now:, stones: [], name: "Full & New Moon — Crystal Cleansing Calendar")
      stamp = utc(now.to_time.utc.beginning_of_day)
      lines = [
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//WriterAlpha//Moon Cleansing Calendar//EN", "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH", "X-WR-CALNAME:#{escape(name)}",
        "X-WR-CALDESC:#{escape('Full and new moons in UTC with the Moon\'s zodiac sign and the crystals tradition says to charge. From writeralpha.com.')}",
        "REFRESH-INTERVAL;VALUE=DURATION:P1D", "X-PUBLISHED-TTL:P1D"
      ]
      events.each { |event| lines.concat(vevent(event, base_url: base_url, stamp: stamp, stones: stones)) }
      lines << "END:VCALENDAR"
      lines.flat_map { |l| fold(l) }.join(CRLF) + CRLF
    end

    def vevent(event, base_url:, stamp:, stones:)
      start = event.minute
      [
        "BEGIN:VEVENT",
        "UID:#{event.uid_stem}@writeralpha.com",
        "DTSTAMP:#{stamp}",
        "DTSTART:#{utc(start)}",
        "DTEND:#{utc(start + 30 * 60)}",
        "SUMMARY:#{escape(summary(event))}",
        "DESCRIPTION:#{escape(description(event, stones))}",
        "URL:#{base_url}/tools/moon-calendar/#{event.month_key}",
        "CATEGORIES:Moon,Crystals",
        "TRANSP:TRANSPARENT",
        "END:VEVENT"
      ]
    end

    def summary(event)
      case event.kind
      when :full_moon then "#{event.emoji} Full Moon in #{event.sign_label} — charge your crystals"
      when :new_moon then "🌑 New Moon in #{event.sign_label} — cleanse and set intentions"
      else "#{event.emoji} #{event.label} Moon in #{event.sign_label}"
      end
    end

    def description(event, stones)
      name, = event.full? ? MoonCalendar.full_moon_name(event) : nil
      guide = Guidance.for_event(event, stones: stones)
      picks = guide.charge.first(3).map { |p| p.stone.name }
      lead = "#{event.label} in #{event.sign_label} (#{event.element}, tropical zodiac)#{name ? " — #{name}" : ''}."
      case event.kind
      when :full_moon
        [lead,
         "Charge: #{(picks + %w[Moonstone Selenite]).uniq.join(', ')}. Moonlight is safe for every stone, even ones that fade in sun.",
         "Moon water only for stones marked safe in water; keep soft, porous or water-soluble stones dry."].join("\n")
      when :new_moon
        [lead, "A traditional time to cleanse stones and set intentions for the month.#{picks.any? ? " Suggested: #{picks.join(', ')}." : ''}",
         "Moonlight is safe for every stone."].join("\n")
      else
        [lead, "A midpoint check on the lunar month. Moonlight is safe for every stone."].join("\n")
      end
    end

    def utc(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")

    # RFC 5545 section 3.3.11 TEXT escaping.
    def escape(text)
      text.to_s.gsub("\\") { "\\\\" }.gsub(";") { "\\;" }.gsub(",") { "\\," }.gsub(/\r\n|\r|\n/) { "\\n" }
    end

    # Fold a content line to at most 75 octets per physical line; continuation lines start with one space.
    def fold(line)
      return [line] if line.bytesize <= LIMIT

      out = []
      current = +""
      limit = LIMIT
      line.each_char do |ch|
        if current.bytesize + ch.bytesize > limit
          out << current
          current = +" "
          limit = LIMIT
        end
        current << ch
      end
      out << current unless current.empty?
      out
    end
  end
end
