# frozen_string_literal: true

require "date"

module Atlas
  # Low-precision solar astronomy, good to ~0.01° for dates 1900–2100 — far
  # tighter than the one-day uncertainty of a birth date with no time.
  # Source: Astronomical Almanac low-precision formulae (also used by NOAA).
  module Astro
    module_function

    SIGNS = ZODIAC
    SIGN_LABELS = SIGNS.to_h { |s| [s, s.capitalize] }.freeze
    SIGN_GLYPHS = %w[♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓].zip(SIGNS).to_h(&:reverse).freeze
    SIGN_ELEMENT = SIGNS.each_with_index.to_h { |s, i| [s, %w[fire earth air water][i % 4]] }.freeze
    # Western rulers (modern rulers for Scorpio, Aquarius, Pisces).
    SIGN_RULER = {
      "aries" => "mars", "taurus" => "venus", "gemini" => "mercury", "cancer" => "moon",
      "leo" => "sun", "virgo" => "mercury", "libra" => "venus", "scorpio" => "pluto",
      "sagittarius" => "jupiter", "capricorn" => "saturn", "aquarius" => "uranus", "pisces" => "neptune"
    }.freeze
    # Usual tropical date ranges, for display only (computation uses longitude).
    SIGN_DATES = {
      "aries" => "Mar 21 – Apr 19", "taurus" => "Apr 20 – May 20", "gemini" => "May 21 – Jun 20",
      "cancer" => "Jun 21 – Jul 22", "leo" => "Jul 23 – Aug 22", "virgo" => "Aug 23 – Sep 22",
      "libra" => "Sep 23 – Oct 22", "scorpio" => "Oct 23 – Nov 21", "sagittarius" => "Nov 22 – Dec 21",
      "capricorn" => "Dec 22 – Jan 19", "aquarius" => "Jan 20 – Feb 18", "pisces" => "Feb 19 – Mar 20"
    }.freeze

    def julian_day(time)
      t = time.respond_to?(:to_time) ? time.to_time.utc : time
      t.to_f / 86_400.0 + 2_440_587.5
    end

    # Apparent geocentric ecliptic longitude of the Sun in degrees [0, 360).
    def sun_longitude(time)
      n = julian_day(time) - 2_451_545.0
      l = (280.460 + 0.9856474 * n) % 360
      g = deg2rad((357.528 + 0.9856003 * n) % 360)
      (l + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) % 360
    end

    # Lahiri (Chitrapaksha) ayanamsa, linear approximation: 23.853° at J2000,
    # precessing 50.29"/year. Within ~0.01° of published tables for 1900–2100.
    def lahiri_ayanamsa(time)
      years = (julian_day(time) - 2_451_545.0) / 365.25
      23.853 + years * (50.29 / 3600.0)
    end

    def sign_for_longitude(lon) = SIGNS[(lon % 360 / 30).floor]

    # For a calendar date (no birth time), evaluate at 12:00 UTC and report
    # whether the Sun was within 1° of a sign boundary (cusp: could be either).
    def tropical_sign(date)
      lon = sun_longitude(noon(date))
      { sign: sign_for_longitude(lon), degree: (lon % 30).round(2), cusp: cusp?(lon) }
    end

    # Sidereal (Vedic) Sun sign. Jyotish gemstone advice normally uses the
    # Moon sign or ascendant (needs birth time and place); this is the
    # date-only approximation and is labelled as such wherever it is shown.
    def sidereal_sign(date)
      t = noon(date)
      lon = (sun_longitude(t) - lahiri_ayanamsa(t)) % 360
      { sign: sign_for_longitude(lon), degree: (lon % 30).round(2), cusp: cusp?(lon) }
    end

    def noon(date)
      d = date.is_a?(String) ? Date.parse(date) : date
      Time.utc(d.year, d.month, d.day, 12)
    end

    def cusp?(lon) = (lon % 30) < 1.0 || (lon % 30) > 29.0
    def deg2rad(d) = d * Math::PI / 180.0
  end
end
