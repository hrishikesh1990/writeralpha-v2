# frozen_string_literal: true

# Shared UI for the /tools section and the tool embeds that appear inside
# existing content pages (hubs, sub-pages, articles, filter pages).
module ToolsHelper
  # The tools, in the order they appear on /tools and the home page.
  TOOLS = [
    { key: :stone_finder, name: "Stone Finder", icon: "✦", route: :tools_stone_finder_path,
      blurb: "Your birthday and what you want help with, matched to the stones that fit you and the ones to skip." },
    { key: :safety, name: "Crystal Safety Checker", icon: "💧", route: :tools_safety_path,
      blurb: "Water, salt, sun, sleep and toxicity for every stone, and the safe way to cleanse each one." },
    { key: :compatibility, name: "Compatibility Checker", icon: "∞", route: :tools_compatibility_path,
      blurb: "Can you wear two stones together? Element, chakra, energy and Vedic rules in one verdict." },
    { key: :real_or_fake, name: "Real or Fake?", icon: "🔍", route: :tools_real_or_fake_path,
      blurb: "Step-by-step home tests for each stone, scored as you go, plus an AI photo check." },
    { key: :birthstone, name: "Birthstone & Navaratna Calculator", icon: "☾", route: :tools_birthstone_path,
      blurb: "Modern, traditional, zodiac and Vedic stones from your date of birth, in English, Hindi and Bengali." },
    { key: :moon, name: "Moon Cleansing Calendar", icon: "◐", route: :tools_moon_path,
      blurb: "Every full and new moon for the year ahead, which stones to charge, and a calendar you can subscribe to." },
    { key: :api, name: "Open Gemstone Data", icon: "{ }", route: :developers_path,
      blurb: "A free JSON API and dataset for every stone in the atlas, licensed CC BY 4.0." }
  ].freeze

  # Where tool embeds appear. Each entry is a partial path; a partial that does
  # not exist yet is skipped, so features can ship independently.
  #   context :hub      — every gemstone hub      locals: gemstone:, entry:
  #   context :sub_page — keyed by guide path      locals: gemstone:, entry:, guide:
  #   context :article  — keyed by article slug or a pattern   locals: article:
  #   context :filter   — keyed by filter type     locals: filter_type:, value:
  TOOL_EMBEDS = {
    hub: { "*" => %w[tools/atlas/hub_panel] },
    sub_page: {
      "can-go-in-water" => %w[tools/safety/embed_stone],
      "sleeping-with" => %w[tools/safety/embed_stone],
      "how-to-cleanse" => %w[tools/safety/embed_cleanse tools/moon/embed_next_moon],
      "how-to-identify" => %w[tools/real_or_fake/embed_stone],
      "combinations" => %w[tools/compatibility/embed_stone],
      "who-should-not-wear" => %w[tools/stone_finder/embed_cautions]
    },
    article: {
      "what-crystals-can-go-in-water" => [["tools/safety/embed_matrix", { focus: "water" }]],
      "salt-safe-crystals" => [["tools/safety/embed_matrix", { focus: "salt" }]],
      "sun-safe-crystals" => [["tools/safety/embed_matrix", { focus: "sun" }]],
      "mohs-hardness-scale" => [["tools/safety/embed_matrix", { focus: "mohs" }]],
      "how-to-cleanse-crystals" => %w[tools/safety/embed_cleanse_picker tools/moon/embed_next_moon],
      "how-to-charge-crystals" => %w[tools/moon/embed_next_moon tools/safety/embed_cleanse_picker],
      "birthstone-guide" => %w[tools/birthstone/embed_calculator],
      "are-online-crystals-real" => %w[tools/real_or_fake/embed_picker],
      "how-to-know-if-a-chakra-bracelet-is-real" => %w[tools/real_or_fake/embed_picker],
      /\A[a-z0-9-]+-and-[a-z0-9-]+-together\z/ => %w[tools/compatibility/embed_pair],
      /\Acrystals-for-[a-z0-9-]+\z/ => %w[tools/stone_finder/embed_intention]
    },
    filter: {
      "zodiac" => %w[tools/stone_finder/embed_zodiac],
      "healing" => %w[tools/stone_finder/embed_intention],
      "birth_month" => %w[tools/birthstone/embed_month]
    }
  }.freeze

  def tools_list = TOOLS.map { |t| t.merge(path: public_send(t[:route])) }

  # Renders every registered embed for a context/key. Embeds never take a
  # content page down: in production a failing embed is logged and skipped.
  def tool_embeds(context, key = nil, **locals)
    table = TOOL_EMBEDS.fetch(context, {})
    entries = table.flat_map do |k, partials|
      matched = k == "*" || k == key.to_s || (k.is_a?(Regexp) && key.to_s.match?(k))
      matched ? partials : []
    end
    safe_join(entries.filter_map { |entry| render_embed(entry, locals) })
  end

  # The AtlasEntry for a Gemstone record, or nil when the stone has no Atlas file.
  def atlas_entry_for(gemstone)
    return nil unless gemstone && (stone = Atlas[gemstone.slug])

    AtlasEntry.new(stone, gemstone)
  end

  # ---- Shared visual vocabulary for tools ----------------------------------

  VERDICT_STYLES = {
    good: "bg-emerald-500/10 text-emerald-700 ring-emerald-600/20",
    warn: "bg-amber-500/12 text-amber-800 ring-amber-600/25",
    bad: "bg-rose-500/10 text-rose-700 ring-rose-600/20",
    info: "bg-violet/8 text-violet-deep ring-violet/20"
  }.freeze

  VERDICT_TONE = {
    "safe" => :good, "ok" => :good, "daily" => :good, "none" => :good, "direct" => :good,
    "brief" => :warn, "limit" => :warn, "caution" => :warn, "care" => :warn, "low" => :warn, "indirect" => :warn,
    "avoid" => :bad, "special" => :bad, "never" => :bad
  }.freeze

  VERDICT_LABELS = {
    "safe" => "Safe", "brief" => "Quick rinse only", "avoid" => "Avoid", "limit" => "Limit",
    "ok" => "OK", "caution" => "Caution", "daily" => "Daily wear", "care" => "Wear with care",
    "special" => "Occasional only", "none" => "Non-toxic", "low" => "Low", "direct" => "Direct OK",
    "indirect" => "Indirect only", "never" => "Never"
  }.freeze

  def verdict_tone(verdict) = VERDICT_TONE.fetch(verdict.to_s, :info)
  def verdict_label(verdict) = VERDICT_LABELS.fetch(verdict.to_s, verdict.to_s.humanize)

  # Pill for a safety verdict (or any tone: :good/:warn/:bad/:info).
  def verdict_badge(verdict, label: nil, tone: nil)
    tone ||= verdict_tone(verdict)
    content_tag(:span, label || verdict_label(verdict),
                class: "inline-flex items-center whitespace-nowrap rounded-full px-[10px] py-[4px] text-[11px] font-medium leading-none ring-1 ring-inset #{VERDICT_STYLES[tone]}")
  end

  # Standard tool page header: breadcrumb, eyebrow, h1, lede.
  def tool_header(title:, lede:, eyebrow: "Tool", crumbs: nil)
    render "tools/shared/header", title:, lede:, eyebrow:,
                                  crumbs: crumbs || [["Home", root_path], ["Tools", tools_path], [title, nil]]
  end

  # "This is tradition, not science" note shown under any metaphysical result.
  def tradition_note(text = nil)
    content_tag(:p, text || "Chakras, elements, zodiac and planetary associations come from crystal-healing and astrological tradition. They are not scientific claims, and no stone replaces medical care.",
                class: "mt-4 text-[11.5px] font-light leading-[1.6] text-faint")
  end

  # Tool result pages (any query string) are noindex so only the clean tool
  # URL is indexed; links on them are still followed.
  def noindex_when_params!(*keys)
    present = keys.empty? ? request.query_parameters.any? : keys.any? { |k| params[k].present? }
    content_for(:head, tag.meta(name: "robots", content: "noindex,follow")) if present
  end

  # schema.org WebApplication JSON-LD for a tool page.
  def tool_jsonld(name:, description:, path: request.path)
    data = { "@context" => "https://schema.org", "@type" => "WebApplication", "name" => name,
             "description" => description, "url" => canonical_url(path), "applicationCategory" => "LifestyleApplication",
             "operatingSystem" => "Any", "isAccessibleForFree" => true,
             "offers" => { "@type" => "Offer", "price" => "0", "priceCurrency" => "USD" },
             "publisher" => { "@type" => "Organization", "name" => "WriterAlpha", "url" => canonical_url("/") } }
    content_for(:jsonld, tag.script(data.to_json.html_safe, type: "application/ld+json"))
  end

  private

  def render_embed(entry, locals)
    partial, extra = entry.is_a?(Array) ? entry : [entry, {}]
    return unless lookup_context.exists?(partial, [], true)

    render(partial: partial, locals: locals.merge(extra))
  rescue StandardError => e
    raise if Rails.env.local?

    Rails.logger.error("[tool_embeds] #{partial}: #{e.class}: #{e.message}")
    nil
  end
end
