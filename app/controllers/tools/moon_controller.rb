# frozen_string_literal: true

# Moon Cleansing Calendar: next full moon in your time zone, the next 13
# lunations, a crawlable page per month (1950-2100) and an ICS subscription.
Mime::Type.register "text/calendar", :ics unless Mime::Type.lookup_by_extension(:ics)

module Tools
  class MoonController < ApplicationController
    Format = MoonCalendar::Format

    before_action :set_zone

    helper_method :zone, :fmt, :zone_options, :tz_param, :entries_by_slug, :site_base_url

    LUNATIONS = 13
    FEED_MONTHS = 24

    def show
      @now = Time.current.utc
      @next_full = MoonCalendar.next_phase(:full_moon, @now)
      @recent_full = MoonCalendar.previous_phase(:full_moon, @now)
      @recent_full = nil if @now - @recent_full.time > 36 * 3600
      @state = MoonCalendar.state(@now)
      @lunations = build_lunations(@now)
      @entries = load_entries
      @guide = guide_for(@next_full, @entries)
      @next_name, @next_aka = MoonCalendar.full_moon_name(@next_full)
      @next_blue = MoonCalendar.blue_moon?(@next_full, zone: zone)
      @this_month = Format.month_param(@now.year, @now.month)

      @meta = {
        title: "Full Moon Calendar & Crystal Cleansing Dates: Next Full Moon, Time & Moon Water Guide",
        description: "When is the next full moon? Exact times in your time zone, the Moon's zodiac sign, which crystals to charge, which stones must never go in moon water, and a calendar you can subscribe to."
      }
    end

    def month
      year, mon = params[:month].to_s.split("-").map(&:to_i)
      return render_not_found unless year && mon && MoonCalendar.valid_month?(year, mon)

      @now = Time.current.utc
      @year = year
      @mon = mon
      @month_key = Format.month_param(year, mon)
      @phases = MoonCalendar.month(year, mon, zone: zone)
      @full = @phases.find(&:full?)
      @new = @phases.find(&:new?)
      @entries = load_entries
      prev_year, prev_mon = mon == 1 ? [year - 1, 12] : [year, mon - 1]
      next_year, next_mon = mon == 12 ? [year + 1, 1] : [year, mon + 1]
      @prev = MoonCalendar.valid_month?(prev_year, prev_mon) ? Format.month_param(prev_year, prev_mon) : nil
      @next = MoonCalendar.valid_month?(next_year, next_mon) ? Format.month_param(next_year, next_mon) : nil
      @month_label = Format.month_name(year, mon)
            # Months that hold two full moons (a Blue Moon) show guidance for each; others for the one full moon.
      @full_moons = @phases.select(&:full?)
      @guides = @full_moons.map { |f| [f, guide_for(f, @entries)] }
      @new_guide = @new && guide_for(@new, @entries)
      @harvest = @full_moons.find { |f| MoonCalendar.harvest_moon?(f) }

      full_phrase = @full ? "Full Moon #{@month_label}" : "Moon Phases #{@month_label}"
      @meta = {
        title: "#{full_phrase}: Date, Time & Crystals to Charge",
        description: month_description
      }
    end

    def feed
      kinds = params[:phases] == "all" ? MoonCalendar::PHASE_KINDS : %i[full_moon new_moon]
      now = Time.current.utc
      key = ["moon-feed-v1", kinds.size, now.to_date.iso8601, site_base_url, atlas_signature]
      body = Rails.cache.fetch(key, expires_in: 6.hours) do
        # From the start of this month to exactly FEED_MONTHS whole months later.
        from = now.beginning_of_month
        events = MoonCalendar.phases(from, from + FEED_MONTHS.months, kinds: kinds)
        MoonCalendar::Ics.build(events, base_url: site_base_url, now: now, stones: load_entries)
      end
      expires_in 6.hours, public: true
      response.headers["Content-Disposition"] = 'inline; filename="writeralpha-moon-calendar.ics"'
      render plain: body, content_type: "text/calendar; charset=utf-8"
    end

    private

    def set_zone
      requested = params[:tz].presence
      @zone = Format.zone(requested.to_s) if requested
      @zone ||= Format.utc_zone
    end

    def zone = @zone
    def tz_param = Format.zone_id(zone) == "UTC" ? nil : Format.zone_id(zone)
    def fmt = Format

    def zone_options
      list = Format::COMMON_ZONES.dup
      list << [Format.zone_id(zone).tr("_", " "), Format.zone_id(zone)] unless list.any? { |_, id| id == Format.zone_id(zone) }
      list
    end

    def site_base_url
      host = ENV["CANONICAL_HOST"].presence
      host ? "https://#{host}" : request.base_url
    end

    # The atlas is being written while this ships; a half-written YAML file
    # must not take the calendar down, so fall back to no stones (the guidance
    # still renders with its general advice).
    def load_entries
      AtlasEntry.all
    rescue Psych::Exception, SystemCallError => e
      Rails.logger.error("[moon] atlas unavailable: #{e.class}: #{e.message}")
      []
    end

    def atlas_signature
      Atlas.slugs.join(",").hash
    rescue Psych::Exception, SystemCallError
      "unavailable"
    end

    def entries_by_slug = @entries_by_slug ||= (@entries || []).index_by(&:slug)

    def guide_for(event, entries)
      name, aka = event.full? ? MoonCalendar.full_moon_name(event) : [nil, nil]
      note = name ? [MoonCalendar::Guidance::NAME_NOTES[name], aka && "It is #{aka}."].compact.join(" ") : nil
      MoonCalendar::Guidance.for_event(event, stones: entries, name: name, name_note: note,
                                                  blue: event.full? && MoonCalendar.blue_moon?(event, zone: zone))
    end

    # The next 13 full moons, each with the new moon that follows it.
    def build_lunations(now)
      MoonCalendar.next_full_moons(now, LUNATIONS).map do |full|
        { full: full, name: MoonCalendar.full_moon_name(full), blue: MoonCalendar.blue_moon?(full, zone: zone),
          new_moon: MoonCalendar.next_phase(:new_moon, full.time) }
      end
    end

    def month_description
      parts = []
      @guides.each do |f, g|
        name = g.title_name
        parts << "#{name} on #{Format.day_month(f.minute, zone)} at #{Format.clock(f.minute, zone)} #{Format.abbr(f.minute, zone)} in #{f.sign_label}"
      end
      lead = parts.any? ? "The #{@month_label} full moon: #{parts.join('; ')}." : "Moon phases for #{@month_label}."
      "#{lead} All four phases, the Moon's sign, which crystals to charge and which stones must stay out of moon water.".squish
    end
  end
end
