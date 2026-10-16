# frozen_string_literal: true

module Tools
  # /tools/stone-finder: which stones suit me, and which should I skip.
  # Everything renders from query params (a plain GET form), so every result
  # is a shareable URL and works without JavaScript.
  class StoneFinderController < ApplicationController
    EXAMPLES = [
      { title: "Crystals for anxiety", params: { i: ["anxiety"] } },
      { title: "Crystals for Leo", params: { sign: "leo" } },
      { title: "Crystals for sleep", params: { i: ["sleep"], use: "sleep" } },
      { title: "What Aries should skip", params: { sign: "aries" } },
      { title: "A daily-wear stone on a budget", params: { use: "wear", budget: "budget" } },
      { title: "Easy care, safe around kids and pets", params: { f: %w[kids water] } }
    ].freeze

    def show
      @entries = AtlasEntry.all
      @query = StoneFinder::Query.parse(params)
      @result = StoneFinder.new(@entries).call(@query) if @query.active?
      @examples = @result ? [] : build_examples
      @meta = meta_for(@query, @result)
    end

    private

    def build_examples
      finder = StoneFinder.new(@entries)
      EXAMPLES.map do |ex|
        q = StoneFinder::Query.new(**ex[:params].transform_keys { |k| { i: :intentions, f: :flags }.fetch(k, k) })
        top = finder.call(q, limit: 3, hints: false).picks.map { |p| p.entry.name }
        ex.merge(query: q, top: top)
      end
    end

    def meta_for(query, result)
      base = { title: "Stone Finder: Which Crystals Suit You? By Birthday, Sign and Goal",
               description: "Tell us your birthday, what you want help with and how you will use the stone. Get ranked crystal matches with reasons, plus the stones to skip for your sign, your home and your budget." }
      return base unless result && query.personal?

      bits = [(StoneFinder::Vocab.sign_name(query.sign) if query.sign), *query.intentions.map { |i| StoneFinder::Vocab.intention_name(i) }].compact
      base.merge(title: "Your Stone Matches: #{StoneFinder::Vocab.list_phrase(bits)} | Stone Finder")
    end
  end
end
