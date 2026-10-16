# frozen_string_literal: true

require "date"

# Moon phase instants and the lunar calendar built on them. Pure Ruby, no gems.
#
# Phase times follow Jean Meeus, Astronomical Algorithms (2nd ed.), chapter 49:
# a mean phase plus periodic terms for each phase type and the planetary
# arguments A1-A14, converted from dynamical time to UTC with the Espenak and
# Meeus polynomial for Delta T. Checked against US Naval Observatory tables for
# 1950-2100; see test/services/moon_calendar_test.rb. Typical error is under a
# minute, which is the resolution the USNO publishes.
#
#   MoonCalendar.next_phase(:full_moon, Time.now.utc)  # => MoonCalendar::Event
#   MoonCalendar.phases(from, to)                       # => [Event, ...]
#   MoonCalendar.state(Time.now.utc)                    # => illumination, phase name
#
# The zodiac is the tropical (Western) zodiac. At a full moon the Moon is
# opposite the Sun, so its sign is the sign opposite the Sun's; at a new moon
# it sits with the Sun. Quarter moons are 90 degrees from the Sun.
module MoonCalendar
  PHASE_KINDS = %i[new_moon first_quarter full_moon last_quarter].freeze
  PHASE_LABELS = {
    new_moon: "New Moon", first_quarter: "First Quarter", full_moon: "Full Moon", last_quarter: "Last Quarter"
  }.freeze
  PHASE_EMOJI = { new_moon: "🌑", first_quarter: "🌓", full_moon: "🌕", last_quarter: "🌗" }.freeze
  # Angle between the Moon and the Sun (ecliptic longitude) at each phase.
  PHASE_ELONGATION = { new_moon: 0, first_quarter: 90, full_moon: 180, last_quarter: 270 }.freeze

  SYNODIC_MONTH = 29.530588861
  FIRST_MONTH = [1950, 1].freeze
  LAST_MONTH = [2100, 12].freeze

  ZODIAC = Atlas::ZODIAC
  GLYPHS = { "aries" => "♈", "taurus" => "♉", "gemini" => "♊", "cancer" => "♋", "leo" => "♌", "virgo" => "♍",
             "libra" => "♎", "scorpio" => "♏", "sagittarius" => "♐", "capricorn" => "♑", "aquarius" => "♒",
             "pisces" => "♓" }.freeze

  # Traditional (Algonquin / colonial almanac) full moon names by calendar month.
  FULL_MOON_NAMES = {
    1 => "Wolf Moon", 2 => "Snow Moon", 3 => "Worm Moon", 4 => "Pink Moon", 5 => "Flower Moon",
    6 => "Strawberry Moon", 7 => "Buck Moon", 8 => "Sturgeon Moon", 9 => "Corn Moon",
    10 => "Hunter's Moon", 11 => "Beaver Moon", 12 => "Cold Moon"
  }.freeze

  # One lunar phase instant. `time` is UTC.
  Event = Data.define(:kind, :time, :sun_longitude) do
    def label = PHASE_LABELS.fetch(kind)
    def emoji = PHASE_EMOJI.fetch(kind)
    def full? = kind == :full_moon
    def new? = kind == :new_moon

    # Ecliptic longitude of the Moon, from the Sun's plus the phase angle.
    def moon_longitude = (sun_longitude + PHASE_ELONGATION.fetch(kind)) % 360
    def sign = Atlas::Astro.sign_for_longitude(moon_longitude)
    def sign_label = sign.capitalize
    def glyph = "#{GLYPHS.fetch(sign)}\uFE0E" # text presentation, not the emoji one
    def element = Atlas::Astro::SIGN_ELEMENT.fetch(sign)
    def sun_sign = Atlas::Astro.sign_for_longitude(sun_longitude)
    def degree = (moon_longitude % 30).floor
    # Published phase times are to the minute, so we round to the nearest minute.
    def minute = Time.at((time.to_f / 60).round * 60).utc
    def stamp = minute.strftime("%Y%m%dT%H%MZ")
    def month_key = minute.strftime("%Y-%m")
    def uid_stem = "#{{ new_moon: 'new', first_quarter: 'first-quarter', full_moon: 'full', last_quarter: 'last-quarter' }.fetch(kind)}-#{stamp}"
    def to_time = time
  end

  class << self
    # ---- Phase instants -----------------------------------------------------

    # The UTC instant of lunation `k` (integer = new moon, +0.25 first quarter,
    # +0.5 full moon, +0.75 last quarter). k = 0 is the new moon of 2000-01-06.
    def phase_time(k)
      jde = phase_jde(k)
      utc_from_jd(jde - delta_t(year_of_jd(jde)) / 86_400.0)
    end

    # Every phase between two instants (inclusive of `from`, exclusive of `to`), oldest first.
    def phases(from, to, kinds: PHASE_KINDS)
      from = from.to_time.utc
      to = to.to_time.utc
      q = ((jd(from) - 2_451_550.09766) / SYNODIC_MONTH * 4).floor - 1
      out = []
      loop do
        kind = PHASE_KINDS[q % 4]
        t = phase_time(q / 4.0)
        break if t >= to

        out << event(kind, t) if t >= from && kinds.include?(kind)
        q += 1
      end
      out
    end

    def next_phase(kind, after)
      after = after.to_time.utc
      q = ((jd(after) - 2_451_550.09766) / SYNODIC_MONTH * 4).floor - 2
      loop do
        q += 1
        next unless PHASE_KINDS[q % 4] == kind

        t = phase_time(q / 4.0)
        return event(kind, t) if t > after
      end
    end

    def previous_phase(kind, before)
      before = before.to_time.utc
      q = ((jd(before) - 2_451_550.09766) / SYNODIC_MONTH * 4).ceil + 2
      loop do
        q -= 1
        next unless PHASE_KINDS[q % 4] == kind

        t = phase_time(q / 4.0)
        return event(kind, t) if t < before
      end
    end

    # The next `count` full moons after `after`.
    def next_full_moons(after, count)
      moons = []
      cursor = after.to_time.utc
      count.times do
        moon = next_phase(:full_moon, cursor)
        moons << moon
        cursor = moon.time + 86_400
      end
      moons
    end

    # All phases in a calendar month of the given time zone (default UTC).
    def month(year, month, zone: "UTC")
      zone = ActiveSupport::TimeZone[zone] || ActiveSupport::TimeZone["UTC"] if defined?(ActiveSupport::TimeZone) && zone.is_a?(String)
      from = zone ? zone.local(year, month, 1) : Time.utc(year, month, 1)
      to = from + 1.month
      phases(from.utc, to.utc)
    end

    def valid_month?(year, month)
      ([year, month] <=> FIRST_MONTH) >= 0 && ([year, month] <=> LAST_MONTH) <= 0 && (1..12).cover?(month)
    end

    def event(kind, time)
      Event.new(kind: kind, time: time, sun_longitude: Atlas::Astro.sun_longitude(time))
    end

    # ---- Names and special moons -------------------------------------------

    # The September (northern autumn) equinox as a UTC Time, from the Sun's longitude crossing 180 degrees.
    def september_equinox(year)
      lo = Time.utc(year, 9, 20)
      hi = Time.utc(year, 9, 26)
      40.times do
        mid = Time.at((lo.to_f + hi.to_f) / 2).utc
        Atlas::Astro.sun_longitude(mid) < 180 ? lo = mid : hi = mid
      end
      lo
    end

    # The full moon nearest the September equinox.
    def harvest_moon(year)
      eq = september_equinox(year)
      full_moons = phases(eq - 20 * 86_400, eq + 20 * 86_400, kinds: [:full_moon])
      full_moons.min_by { |m| (m.time - eq).abs }
    end

    def harvest_moon?(event)
      event.full? && [9, 10].include?(event.time.month) && harvest_moon(event.time.year)&.time == event.time
    end

    # Second full moon within one calendar month (UTC dates, or the dates in `zone`).
    def blue_moon?(event, zone: nil)
      return false unless event.full?

      prev = previous_phase(:full_moon, event.time)
      a = zone ? event.time.in_time_zone(zone) : event.time.utc
      b = zone ? prev.time.in_time_zone(zone) : prev.time.utc
      a.year == b.year && a.month == b.month
    end

    # Name for a full moon: Harvest Moon, Hunter's Moon (the full moon after the
    # Harvest Moon, when that is in October), or the month's traditional name.
    # The month is read in `zone` when given, so a page in New Zealand that shows
    # the full moon on 1 February calls it the Snow Moon, not January's Wolf Moon.
    # Returns [name, also_called_or_nil].
    def full_moon_name(event, zone: nil)
      month = zone ? event.time.in_time_zone(zone).month : event.time.month
      if harvest_moon?(event)
        ["Harvest Moon", month == 9 ? "also called the Corn Moon" : nil]
      elsif month == 10
        ["Hunter's Moon", nil] # the October full moon that is not the Harvest Moon follows it
      else
        [FULL_MOON_NAMES.fetch(month), nil]
      end
    end

    # ---- Moon state at an instant ------------------------------------------

    # Phase angle (0-360, 0 = new, 180 = full) interpolated between the true
    # quarter instants, which is more accurate than a flat 29.53 day cycle.
    def elongation(at)
      at = at.to_time.utc
      q = ((jd(at) - 2_451_550.09766) / SYNODIC_MONTH * 4).floor - 1
      loop do
        t0 = phase_time(q / 4.0)
        t1 = phase_time((q + 1) / 4.0)
        return ((q % 4) * 90 + 90 * (at - t0) / (t1 - t0)) % 360 if at >= t0 && at < t1

        q += (at < t0 ? -1 : 1)
      end
    end

    def phase_name(angle)
      a = angle % 360
      return "New Moon" if a < 10 || a >= 350
      return "First Quarter" if (80..100).cover?(a)
      return "Full Moon" if (170..190).cover?(a)
      return "Last Quarter" if (260..280).cover?(a)

      if a < 80 then "Waxing Crescent"
      elsif a < 170 then "Waxing Gibbous"
      elsif a < 260 then "Waning Gibbous"
      else "Waning Crescent"
      end
    end

    def state(at)
      angle = elongation(at)
      { angle: angle, illumination: (1 - Math.cos(angle * Math::PI / 180)) / 2, waxing: angle < 180,
        name: phase_name(angle) }
    end

    # ---- Conversions --------------------------------------------------------

    def jd(time) = time.to_time.utc.to_f / 86_400.0 + 2_440_587.5
    def utc_from_jd(jd) = Time.at((jd - 2_440_587.5) * 86_400.0).utc
    def year_of_jd(jd) = 2000.0 + (jd - 2_451_545.0) / 365.25

    # Delta T (TT - UT) in seconds, Espenak and Meeus polynomial approximations (1900-2150).
    def delta_t(y)
      case y
      when ...1920 then (t = y - 1900; -2.79 + 1.494119 * t - 0.0598939 * t**2 + 0.0061966 * t**3 - 0.000197 * t**4)
      when ...1941 then (t = y - 1920; 21.20 + 0.84493 * t - 0.076100 * t**2 + 0.0020936 * t**3)
      when ...1961 then (t = y - 1950; 29.07 + 0.407 * t - t**2 / 233.0 + t**3 / 2547.0)
      when ...1986 then (t = y - 1975; 45.45 + 1.067 * t - t**2 / 260.0 - t**3 / 718.0)
      when ...2005 then (t = y - 2000; 63.86 + 0.3345 * t - 0.060374 * t**2 + 0.0017275 * t**3 + 0.000651814 * t**4 + 0.00002373599 * t**5)
      when ...2050 then (t = y - 2000; 62.92 + 0.32217 * t + 0.005589 * t**2)
      when ...2150 then -20 + 32 * ((y - 1820) / 100.0)**2 - 0.5628 * (2150 - y)
      else -20 + 32 * ((y - 1820) / 100.0)**2
      end
    end

    private

    # Meeus chapter 49: Julian Ephemeris Day (dynamical time) of lunation k.
    def phase_jde(k)
      t = k / 1236.85
      jde = 2_451_550.09766 + SYNODIC_MONTH * k + 0.00015437 * t**2 - 0.000000150 * t**3 + 0.00000000073 * t**4
      e = 1 - 0.002516 * t - 0.0000074 * t**2
      m = rad(2.5534 + 29.10535670 * k - 0.0000014 * t**2 - 0.00000011 * t**3)
      mp = rad(201.5643 + 385.81693528 * k + 0.0107582 * t**2 + 0.00001238 * t**3 - 0.000000058 * t**4)
      f = rad(160.7108 + 390.67050284 * k - 0.0016118 * t**2 - 0.00000227 * t**3 + 0.000000011 * t**4)
      om = rad(124.7746 - 1.56375588 * k + 0.0020672 * t**2 + 0.00000215 * t**3)

      phase = (k % 1).round(2)
      correction =
        case phase
        when 0.0 then new_moon_terms(e, m, mp, f, om)
        when 0.5 then full_moon_terms(e, m, mp, f, om)
        else
          quarter_terms(e, m, mp, f, om) + (phase == 0.25 ? 1 : -1) * quarter_w(e, m, mp, f)
        end

      jde + correction + planetary_terms(k, t)
    end

    def new_moon_terms(e, m, mp, f, om)
      -0.40720 * Math.sin(mp) + 0.17241 * e * Math.sin(m) + 0.01608 * Math.sin(2 * mp) + 0.01039 * Math.sin(2 * f) +
        0.00739 * e * Math.sin(mp - m) - 0.00514 * e * Math.sin(mp + m) + 0.00208 * e * e * Math.sin(2 * m) -
        0.00111 * Math.sin(mp - 2 * f) - 0.00057 * Math.sin(mp + 2 * f) + 0.00056 * e * Math.sin(2 * mp + m) -
        0.00042 * Math.sin(3 * mp) + 0.00042 * e * Math.sin(m + 2 * f) + 0.00038 * e * Math.sin(m - 2 * f) -
        0.00024 * e * Math.sin(2 * mp - m) - 0.00017 * Math.sin(om) - 0.00007 * Math.sin(mp + 2 * m) +
        0.00004 * Math.sin(2 * mp - 2 * f) + 0.00004 * Math.sin(3 * m) + 0.00003 * Math.sin(mp + m - 2 * f) +
        0.00003 * Math.sin(2 * mp + 2 * f) - 0.00003 * Math.sin(mp + m + 2 * f) + 0.00003 * Math.sin(mp - m + 2 * f) -
        0.00002 * Math.sin(mp - m - 2 * f) - 0.00002 * Math.sin(3 * mp + m) + 0.00002 * Math.sin(4 * mp)
    end

    def full_moon_terms(e, m, mp, f, om)
      -0.40614 * Math.sin(mp) + 0.17302 * e * Math.sin(m) + 0.01614 * Math.sin(2 * mp) + 0.01043 * Math.sin(2 * f) +
        0.00734 * e * Math.sin(mp - m) - 0.00515 * e * Math.sin(mp + m) + 0.00209 * e * e * Math.sin(2 * m) -
        0.00111 * Math.sin(mp - 2 * f) - 0.00057 * Math.sin(mp + 2 * f) + 0.00056 * e * Math.sin(2 * mp + m) -
        0.00042 * Math.sin(3 * mp) + 0.00042 * e * Math.sin(m + 2 * f) + 0.00038 * e * Math.sin(m - 2 * f) -
        0.00024 * e * Math.sin(2 * mp - m) - 0.00017 * Math.sin(om) - 0.00007 * Math.sin(mp + 2 * m) +
        0.00004 * Math.sin(2 * mp - 2 * f) + 0.00004 * Math.sin(3 * m) + 0.00003 * Math.sin(mp + m - 2 * f) +
        0.00003 * Math.sin(2 * mp + 2 * f) - 0.00003 * Math.sin(mp + m + 2 * f) + 0.00003 * Math.sin(mp - m + 2 * f) -
        0.00002 * Math.sin(mp - m - 2 * f) - 0.00002 * Math.sin(3 * mp + m) + 0.00002 * Math.sin(4 * mp)
    end

    def quarter_terms(e, m, mp, f, om)
      -0.62801 * Math.sin(mp) + 0.17172 * e * Math.sin(m) - 0.01183 * e * Math.sin(mp + m) + 0.00862 * Math.sin(2 * mp) +
        0.00804 * Math.sin(2 * f) + 0.00454 * e * Math.sin(mp - m) + 0.00204 * e * e * Math.sin(2 * m) -
        0.00180 * Math.sin(mp - 2 * f) - 0.00070 * Math.sin(mp + 2 * f) - 0.00040 * Math.sin(3 * mp) -
        0.00034 * e * Math.sin(2 * mp - m) + 0.00032 * e * Math.sin(m + 2 * f) + 0.00032 * e * Math.sin(m - 2 * f) -
        0.00028 * e * e * Math.sin(mp + 2 * m) + 0.00027 * e * Math.sin(2 * mp + m) - 0.00017 * Math.sin(om) -
        0.00005 * Math.sin(mp - m - 2 * f) + 0.00004 * Math.sin(2 * mp + 2 * f) - 0.00004 * Math.sin(mp + m + 2 * f) +
        0.00004 * Math.sin(mp - 2 * m) + 0.00003 * Math.sin(mp + m - 2 * f) + 0.00003 * Math.sin(3 * m) +
        0.00002 * Math.sin(2 * mp - 2 * f) + 0.00002 * Math.sin(mp - m + 2 * f) - 0.00002 * Math.sin(3 * mp + m)
    end

    def quarter_w(e, m, mp, f)
      0.00306 - 0.00038 * e * Math.cos(m) + 0.00026 * Math.cos(mp) - 0.00002 * Math.cos(mp - m) +
        0.00002 * Math.cos(mp + m) + 0.00002 * Math.cos(2 * f)
    end

    # Additional corrections from the planetary arguments A1-A14 (all phases).
    PLANETARY = [
      [299.77, 0.107408, 0.000325], [251.88, 0.016321, 0.000165], [251.83, 26.651886, 0.000164],
      [349.42, 36.412478, 0.000126], [84.66, 18.206239, 0.000110], [141.74, 53.303771, 0.000062],
      [207.14, 2.453732, 0.000060], [154.84, 7.306860, 0.000056], [34.52, 27.261239, 0.000047],
      [207.19, 0.121824, 0.000042], [291.34, 1.844379, 0.000040], [161.72, 24.198154, 0.000037],
      [239.56, 25.513099, 0.000035], [331.55, 3.592518, 0.000023]
    ].freeze

    def planetary_terms(k, t)
      PLANETARY.each_with_index.sum do |(a0, a1, amp), i|
        arg = a0 + a1 * k
        arg -= 0.009173 * t**2 if i.zero?
        amp * Math.sin(rad(arg))
      end
    end

    def rad(deg) = deg % 360 * Math::PI / 180.0
  end
end
