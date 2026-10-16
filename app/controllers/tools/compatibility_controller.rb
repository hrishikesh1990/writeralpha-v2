# frozen_string_literal: true

module Tools
  # /tools/compatibility?a=amethyst&b=rose-quartz[&c=..&d=..][&ctx=bedroom]
  #   no stones     -> landing (examples, pairs tradition keeps apart)
  #   one stone     -> best partners, and who to avoid
  #   two stones    -> verdict card
  #   three or four -> pairwise matrix
  # Every param is validated; unknown or malformed slugs are ignored with a
  # friendly note, never an error.
  class CompatibilityController < ApplicationController
    STONE_KEYS = %i[a b c d].freeze
    SLUG_FORMAT = /\A[a-z0-9][a-z0-9-]{0,59}\z/
    EXAMPLE_PAIRS = [
      %w[amethyst rose-quartz], %w[black-tourmaline selenite], %w[rose-quartz clear-quartz],
      %w[ruby sapphire], %w[amethyst carnelian], %w[malachite selenite], %w[tiger-eye hematite],
      %w[lapis-lazuli amethyst], %w[moonstone labradorite]
    ].freeze

    def show
      @entries = AtlasEntry.all
      @by_slug = @entries.index_by(&:slug)
      @context = CrystalCompatibility.normalize_context(string_param(:ctx))
      @stones, @notes = pick_stones
      @mode = { 0 => :landing, 1 => :partners, 2 => :pair }.fetch(@stones.size, :matrix)

      case @mode
      when :landing then build_landing
      when :partners then build_partners
      when :pair then build_pair
      when :matrix then build_matrix
      end
      set_meta
    end

    private

    # Only plain strings are accepted: ?a[]=x or ?a[b]=c arrive as Array/Parameters and are dropped.
    def string_param(key)
      v = params[key]
      v.is_a?(String) ? v.strip.downcase.first(80) : nil
    end

    def pick_stones
      notes = []
      stones = []
      STONE_KEYS.each do |key|
        raw = string_param(key)
        next if raw.blank?

        unless raw.match?(SLUG_FORMAT)
          notes << "We did not recognise one of the stone names in the link, so it was skipped."
          next
        end
        entry = @by_slug[raw]
        if entry.nil?
          notes << "We do not have a profile for \"#{raw.tr('-', ' ')}\" yet, so it was skipped."
        elsif stones.any? { |s| s.slug == entry.slug }
          notes << "#{entry.name} was picked twice. Choose a different stone to compare it with." if stones.size == 1 || key == :b
        else
          stones << entry
        end
      end
      [stones, notes.uniq]
    end

    def build_landing
      pairs = EXAMPLE_PAIRS.filter_map { |x, y| (a = @by_slug[x]) && (b = @by_slug[y]) && CrystalCompatibility.check(a, b) }
      @examples = pairs.first(6)
      @conflicts = CrystalCompatibility.known_conflicts(@entries, limit: 6)
    end

    def build_partners
      @stone = @stones.first
      others = @entries.reject { |e| e.slug == @stone.slug }
      report = CrystalCompatibility.partner_report(@stone, limit: 12, among: others, context: @context)
      @best = report.best
      @avoid = report.avoid
    end

    def build_pair
      @result = CrystalCompatibility.check(@stones[0], @stones[1], context: @context)
      slugs = @stones.map(&:slug)
      @article = Article.published.where(slug: ["#{slugs[0]}-and-#{slugs[1]}-together", "#{slugs[1]}-and-#{slugs[0]}-together"]).first
    end

    def build_matrix
      @matrix = CrystalCompatibility.matrix(@stones, context: @context)
      methods = @stones.map { |s| s.safe_cleanse_methods }.reduce(:&) || []
      @group_cleanse = methods
    end

    def set_meta
      base = { title: "Crystal Compatibility Checker: Can You Wear These Stones Together?",
               description: "Pick two crystals and get a reasoned verdict: tradition, chakras, elements and energy, the Vedic rule on planetary enemies, and practical care like scratching and cleansing." }
      @meta =
        case @mode
        when :pair
          r = @result
          { title: "#{r.a.name} and #{r.b.name} together: #{r.label} (#{r.score}/100)",
            description: "#{r.headline} #{r.summary}".squish.truncate(300) }
        when :partners
          { title: "Best crystal partners for #{@stone.name}, and what to avoid",
            description: "Which crystals go with #{@stone.name}, ranked by tradition, chakra, element and energy, plus the pairings to avoid and the practical care for each." }
        when :matrix
          { title: "#{@stones.map(&:name).to_sentence(two_words_connector: ' and ', last_word_connector: ', and ')}: do they work together?",
            description: "A pairwise compatibility check for #{@stones.size} crystals." }
        else
          base
        end
    end
  end
end
