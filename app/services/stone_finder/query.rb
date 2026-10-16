# frozen_string_literal: true

require "date"

class StoneFinder
  # A normalised, validated set of finder inputs. Everything is optional and
  # anything unrecognised is dropped (never raised), so any URL is safe.
  class Query
    MIN_YEAR = 1900

    attr_reader :dob, :sign, :intentions, :use, :budget, :flags, :errors, :sign_info

    # Build from request params (ActionController::Parameters or a Hash).
    def self.parse(raw, today: Date.current)
      h = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      h = h.transform_keys(&:to_s)
      dob, error = parse_date(h["dob"], today)
      new(dob: dob, sign: scalar(h["sign"]), intentions: list(h["i"]), use: scalar(h["use"]),
          budget: scalar(h["budget"]), flags: list(h["f"]), errors: [error].compact, today: today)
    end

    def self.scalar(v) = v.is_a?(String) ? v.strip.downcase[0, 40] : nil

    def self.list(v)
      v = v.values if v.is_a?(Hash)
      Array(v).filter_map { |x| scalar(x) }
    end

    def self.parse_date(value, today)
      return [nil, nil] if value.blank?
      return [nil, "We could not read that date. Use the date picker, or write it as YYYY-MM-DD."] unless value.is_a?(String)

      s = value.strip

      m = s.match(/\A(\d{4})-(\d{1,2})-(\d{1,2})\z/)
      return [nil, "We could not read that date. Use the date picker, or write it as YYYY-MM-DD."] unless m

      y, mo, d = m.captures.map(&:to_i)
      unless Date.valid_date?(y, mo, d)
        extra = mo == 2 && d == 29 ? " (#{y} was not a leap year)" : ""
        return [nil, "That date does not exist#{extra}. Please check the day and month."]
      end
      return [nil, "Please choose a birth date from #{MIN_YEAR} onwards."] if y < MIN_YEAR

      date = Date.new(y, mo, d)
      return [nil, "That date is in the future. Please enter the date you were born."] if date > today

      [date, nil]
    end

    def initialize(dob: nil, sign: nil, intentions: [], use: nil, budget: nil, flags: [], errors: [], today: Date.current)
      @dob = dob.is_a?(Date) ? dob : nil
      @errors = Array(errors)
      @intentions = Array(intentions).map(&:to_s).uniq.select { |i| Atlas::INTENTIONS.include?(i) }.first(Vocab::MAX_INTENTIONS)
      @use = Vocab::USES.key?(use.to_s) ? use.to_s : nil
      @budget = Vocab::BUDGETS.key?(budget.to_s) ? budget.to_s : nil
      @flags = Array(flags).map(&:to_s).uniq.select { |f| Vocab::FLAGS.key?(f) }
      @sign_info = @dob ? compute_sign_info(@dob) : nil
      @sign = @sign_info ? @sign_info[:sign] : (Atlas::ZODIAC.include?(sign.to_s) ? sign.to_s : nil)
      @sign_source = @dob ? :dob : (@sign ? :sign : nil)
      @sign_info ||= @sign && { sign: @sign, degree: nil, cusp: false, cusp_with: nil }
    end

    def month = dob&.month
    def month_name = dob ? Vocab.month_name(dob.month) : nil
    def element = sign && Atlas::Astro::SIGN_ELEMENT[sign]
    def sign_from_date? = @sign_source == :dob
    def flag?(name) = flags.include?(name.to_s)
    def personal? = !!(sign || intentions.any? || use)
    def active? = personal? || budget || flags.any?

    # A copy of this query without one input (used for "what if" hints).
    def without(key)
      case key.to_sym
      when :budget then copy(budget: nil)
      when :use then copy(use: nil)
      when :water, :kids, :sensitive then copy(flags: flags - [key.to_s])
      else self
      end
    end

    # Canonical URL params, e.g. { dob: "1994-07-28", i: ["love"], use: "wear" }.
    def to_params
      p = {}
      p[:dob] = dob.iso8601 if dob
      p[:sign] = sign if sign && !dob
      p[:i] = intentions if intentions.any?
      p[:use] = use if use
      p[:budget] = budget if budget
      p[:f] = flags if flags.any?
      p
    end

    def ==(other) = other.is_a?(Query) && to_params == other.to_params

    private

    def copy(overrides)
      Query.new(**{ dob: dob, sign: sign, intentions: intentions, use: use, budget: budget, flags: flags }.merge(overrides))
    end

    def compute_sign_info(date)
      info = Atlas::Astro.tropical_sign(date)
      idx = Atlas::ZODIAC.index(info[:sign])
      with = nil
      if info[:cusp]
        with = Atlas::ZODIAC[(idx + (info[:degree] < 15 ? -1 : 1)) % 12]
      end
      info.merge(cusp_with: with)
    end
  end
end
