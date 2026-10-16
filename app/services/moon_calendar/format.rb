# frozen_string_literal: true

module MoonCalendar
  # Plain-Ruby text formatting for phase times, shared by the pages and embeds.
  module Format
    module_function

    COMMON_ZONES = [
      ["UTC", "UTC"], ["India (Kolkata)", "Asia/Kolkata"], ["Bangladesh (Dhaka)", "Asia/Dhaka"],
      ["Pakistan (Karachi)", "Asia/Karachi"], ["Nepal (Kathmandu)", "Asia/Kathmandu"], ["Sri Lanka (Colombo)", "Asia/Colombo"],
      ["UAE (Dubai)", "Asia/Dubai"], ["UK (London)", "Europe/London"], ["Ireland (Dublin)", "Europe/Dublin"],
      ["Central Europe (Berlin)", "Europe/Berlin"], ["Spain (Madrid)", "Europe/Madrid"],
      ["US Eastern (New York)", "America/New_York"], ["US Central (Chicago)", "America/Chicago"],
      ["US Mountain (Denver)", "America/Denver"], ["US Arizona (Phoenix)", "America/Phoenix"],
      ["US Pacific (Los Angeles)", "America/Los_Angeles"], ["Alaska (Anchorage)", "America/Anchorage"],
      ["Hawaii (Honolulu)", "Pacific/Honolulu"], ["Canada (Toronto)", "America/Toronto"],
      ["Canada (Vancouver)", "America/Vancouver"], ["Mexico City", "America/Mexico_City"],
      ["Brazil (São Paulo)", "America/Sao_Paulo"], ["Nigeria (Lagos)", "Africa/Lagos"],
      ["South Africa (Johannesburg)", "Africa/Johannesburg"], ["Singapore", "Asia/Singapore"],
      ["Philippines (Manila)", "Asia/Manila"], ["Japan (Tokyo)", "Asia/Tokyo"],
      ["Australia East (Sydney)", "Australia/Sydney"], ["Australia West (Perth)", "Australia/Perth"],
      ["New Zealand (Auckland)", "Pacific/Auckland"]
    ].freeze

    # Zones shown side by side on month pages.
    COMPARE_ZONES = [["UTC", "UTC"], ["New York", "America/New_York"], ["Los Angeles", "America/Los_Angeles"],
                     ["London", "Europe/London"], ["Kolkata", "Asia/Kolkata"], ["Sydney", "Australia/Sydney"]].freeze

    # A validated ActiveSupport::TimeZone for user input, or nil.
    def zone(name)
      return nil unless name.is_a?(String) && name.match?(%r{\A[A-Za-z][A-Za-z0-9_+\-/ ]{1,40}\z})

      z = ActiveSupport::TimeZone[name]
      z && TZInfo::Timezone.all_identifiers.include?(z.tzinfo.name) ? z : nil
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
      nil
    end

    def utc_zone = ActiveSupport::TimeZone["UTC"]
    def zone_id(zone) = %w[Etc/UTC Etc/UCT UTC UCT Etc/Universal Etc/Zulu].include?(zone.tzinfo.name) ? "UTC" : zone.tzinfo.name
    def indefinite(word) = "#{word.match?(/\A[aeiou]/i) ? 'an' : 'a'} #{word}"

    def local(time, zone) = time.in_time_zone(zone)
    def date(time, zone) = local(time, zone).strftime("%A %-d %B %Y")
    def short_date(time, zone) = local(time, zone).strftime("%a %-d %b")
    def day_month(time, zone) = local(time, zone).strftime("%-d %B")
    def clock(time, zone) = local(time, zone).strftime("%-I:%M %p").downcase

    # "UTC", "IST", or a numeric offset when the zone has no abbreviation.
    def abbr(time, zone)
      z = local(time, zone).zone
      z.match?(/\A[+-]\d+\z/) ? "UTC#{local(time, zone).formatted_offset(false)}" : z
    end

    def offset(time, zone)
      secs = local(time, zone).utc_offset
      return "UTC" if secs.zero?

      h, m = (secs.abs / 60).divmod(60)
      "UTC#{secs.negative? ? '-' : '+'}#{h}#{m.zero? ? '' : format(':%02d', m)}"
    end

    def zone_label(time, zone)
      zone_id(zone) == "UTC" ? "UTC" : "#{zone_id(zone).tr('_', ' ')} (#{abbr(time, zone)}, #{offset(time, zone)})"
    end

    def countdown(time, now)
      secs = (time - now).to_f
      return "now" if secs <= 0 && secs > -3600
      return "#{(-secs / 86_400).floor + 1} days ago" if secs < 0

      days = (secs / 86_400).floor
      hours = ((secs % 86_400) / 3600).floor
      if days >= 14 then "in #{days} days"
      elsif days >= 2 then "in #{days} days#{hours.positive? ? " #{hours} #{'hour'.pluralize(hours)}" : ''}"
      elsif days == 1 then "in 1 day#{hours.positive? ? " #{hours} #{'hour'.pluralize(hours)}" : ''}"
      elsif hours >= 1 then "in #{hours} #{'hour'.pluralize(hours)}"
      else "in under an hour"
      end
    end

    def month_name(year, month) = Date.new(year, month, 1).strftime("%B %Y")
    def month_param(year, month) = format("%04d-%02d", year, month)
  end
end
