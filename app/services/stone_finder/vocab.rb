# frozen_string_literal: true

class StoneFinder
  # Labels and vocabularies shared by the engine, the form and the embeds.
  module Vocab
    MAX_INTENTIONS = 3

    # Display order for the intention chips: most-searched needs first.
    INTENTION_ORDER = %w[
      anxiety sleep peace-calm love self-love protection confidence wealth luck career
      creativity concentration clarity motivation energy courage grounding emotional-balance
      grief healing intuition spiritual-growth communication transformation friendship
    ].freeze

    INTENTION_NAMES = {
      "peace-calm" => "peace & calm", "self-love" => "self-love", "emotional-balance" => "emotional balance",
      "spiritual-growth" => "spiritual growth"
    }.freeze

    USES = {
      "wear" => { label: "Wear it daily", hint: "Ring, bracelet or pendant" },
      "sleep" => { label: "Sleep with it", hint: "Under the pillow or by the bed" },
      "meditate" => { label: "Meditate with it", hint: "Hold it or keep it nearby" },
      "home" => { label: "Home or desk", hint: "On a shelf, desk or windowsill" },
      "gift" => { label: "Give it as a gift", hint: "For someone else" }
    }.freeze

    # Ordered cheapest to dearest. A budget means "up to and including this tier".
    BUDGETS = {
      "budget" => { label: "Budget", hint: "Tumbled and raw pieces" },
      "mid" => { label: "Mid-range", hint: "Nicer cuts and jewellery" },
      "premium" => { label: "Premium", hint: "Fine jewellery pieces" },
      "luxury" => { label: "Luxury", hint: "Gem-grade stones" }
    }.freeze
    TIER_RANK = BUDGETS.keys.each_with_index.to_h.freeze

    FLAGS = {
      "water" => "I cleanse my stones with water",
      "kids" => "Children or pets at home",
      "sensitive" => "I'm sensitive to strong energy"
    }.freeze

    CALM_INTENTIONS = %w[sleep anxiety peace-calm].freeze
    LIVELY_INTENTIONS = %w[energy motivation courage].freeze

    # /crystals/crystals-for-<purpose> article slug => intention (or :beginners).
    ARTICLE_INTENTIONS = {
      "anxiety" => "anxiety", "sleep" => "sleep", "money" => "wealth", "love" => "love",
      "protection" => "protection", "grounding" => "grounding", "confidence" => "confidence",
      "creativity" => "creativity", "healing" => "healing", "meditation" => "spiritual-growth",
      "concentration" => "concentration", "self-love" => "self-love", "grief" => "grief",
      "jealousy" => "emotional-balance", "nightmares" => "sleep", "beginners" => :beginners
    }.freeze

    module_function

    def intentions
      ordered = INTENTION_ORDER & Atlas::INTENTIONS
      ordered + (Atlas::INTENTIONS - ordered)
    end

    def intention_name(slug) = INTENTION_NAMES.fetch(slug.to_s) { slug.to_s.tr("-", " ") }
    def intention_title(slug) = intention_name(slug).sub(/\A./, &:upcase)
    def sign_name(sign) = Atlas::Astro::SIGN_LABELS[sign.to_s] || sign.to_s.capitalize
    def sign_glyph(sign) = Atlas::Astro::SIGN_GLYPHS[sign.to_s]
    def month_name(index) = Atlas::MONTHS[index.to_i - 1].to_s.capitalize

    def list_phrase(items, conjunction = "and")
      items = Array(items)
      case items.size
      when 0 then ""
      when 1 then items.first
      when 2 then items.join(" #{conjunction} ")
      else "#{items[0..-2].join(', ')} #{conjunction} #{items.last}"
      end
    end

    def first_sentence(text)
      s = text.to_s.strip
      return s if s.empty?

      s.split(/(?<=[.!?])\s+(?=[A-Z])/).first.to_s
    end

    def article_intention(slug)
      m = slug.to_s.match(/\Acrystals-for-([a-z0-9-]+)\z/)
      m && ARTICLE_INTENTIONS[m[1]]
    end
  end
end
