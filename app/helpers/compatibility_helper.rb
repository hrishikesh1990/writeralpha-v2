# frozen_string_literal: true

# View helpers for the Crystal Compatibility tool and its embeds. Every method
# is prefixed compat_ because Rails mixes all helpers into all views.
module CompatibilityHelper
  RING_RADIUS = 52
  RING_CIRCUMFERENCE = (2 * Math::PI * RING_RADIUS).round(1)

  # Colours for the dark verdict panel (stroke, text, soft background).
  COMPAT_COLORS = {
    great: { stroke: "#34d399", text: "text-emerald-300", pill: "bg-emerald-400/15 text-emerald-200 ring-emerald-300/30", bar: "bg-emerald-400" },
    good: { stroke: "#6ee7b7", text: "text-emerald-200", pill: "bg-emerald-300/12 text-emerald-100 ring-emerald-200/25", bar: "bg-emerald-300" },
    neutral: { stroke: "#fcd34d", text: "text-amber-200", pill: "bg-amber-300/15 text-amber-100 ring-amber-200/30", bar: "bg-amber-300" },
    avoid: { stroke: "#fb7185", text: "text-rose-300", pill: "bg-rose-400/15 text-rose-200 ring-rose-300/30", bar: "bg-rose-400" }
  }.freeze

  # Light-surface equivalents for lists and tables.
  COMPAT_LIGHT = {
    great: "bg-emerald-500/12 text-emerald-800 ring-emerald-600/25",
    good: "bg-emerald-500/10 text-emerald-700 ring-emerald-600/20",
    neutral: "bg-amber-500/12 text-amber-800 ring-amber-600/25",
    avoid: "bg-rose-500/10 text-rose-700 ring-rose-600/20"
  }.freeze

  BASIS_LABELS = { tradition: "Tradition", vedic: "Vedic astrology", physical: "Physical" }.freeze
  BASIS_STYLES = {
    tradition: "bg-violet/8 text-violet-deep",
    vedic: "bg-amber-500/12 text-amber-800",
    physical: "bg-sky/12 text-sky-text"
  }.freeze

  def compat_colors(verdict) = COMPAT_COLORS.fetch(verdict, COMPAT_COLORS[:neutral])

  def compat_pill(verdict, label = nil)
    label ||= CrystalCompatibility::VERDICTS.dig(verdict, :label)
    content_tag(:span, label, class: "inline-flex items-center whitespace-nowrap rounded-full px-[10px] py-[4px] text-[11px] font-medium leading-none ring-1 ring-inset #{COMPAT_LIGHT[verdict]}")
  end

  def compat_basis_chip(basis)
    content_tag(:span, BASIS_LABELS.fetch(basis, basis.to_s.humanize),
                class: "inline-flex rounded-full px-2 py-[3px] font-mono text-[8.5px] uppercase tracking-[0.14em] #{BASIS_STYLES[basis]}")
  end

  # Strength of a reason's influence, shown as dots with a text alternative
  # (we deliberately do not show raw points: the curve is not additive).
  def compat_strength(points)
    n = points.to_i.abs
    return nil if n.zero?

    level = n >= 12 ? 3 : (n >= 5 ? 2 : 1)
    word = %w[slight moderate strong][level - 1]
    content_tag(:span, class: "inline-flex items-center gap-[3px]", title: "#{word.capitalize} influence") do
      dots = Array.new(3) { |i| content_tag(:span, "", class: "size-[5px] rounded-full #{i < level ? 'bg-current' : 'bg-current opacity-20'}") }
      safe_join(dots + [content_tag(:span, "#{word} influence", class: "sr-only")])
    end
  end

  # One-time CSS for the animated ring (kept here so embeds work on any page).
  def compat_ring_css
    return "".html_safe if @compat_ring_css_rendered

    @compat_ring_css_rendered = true
    content_tag(:style, ".compat-ring-arc{animation:compat-ring .9s cubic-bezier(.2,.7,.2,1) both}@keyframes compat-ring{from{stroke-dashoffset:#{RING_CIRCUMFERENCE}}}@media (prefers-reduced-motion:reduce){.compat-ring-arc{animation:none}}".html_safe)
  end

  # Score ring: SVG arc plus the number in HTML. Text, not colour alone, carries the verdict.
  def compat_ring(score, verdict, size: 132)
    c = RING_CIRCUMFERENCE
    offset = (c * (1 - score.to_f / 100)).round(1)
    colors = compat_colors(verdict)
    content_tag(:div, class: "relative flex-none", style: "width:#{size}px;height:#{size}px") do
      svg = tag.svg(viewBox: "0 0 120 120", class: "size-full -rotate-90", role: "img", "aria-label": "Compatibility score #{score} out of 100") do
        tag.circle(cx: 60, cy: 60, r: RING_RADIUS, fill: "none", stroke: "rgba(255,255,255,0.10)", "stroke-width": 9) +
          tag.circle(cx: 60, cy: 60, r: RING_RADIUS, fill: "none", stroke: colors[:stroke], "stroke-width": 9, "stroke-linecap": "round",
                     "stroke-dasharray": c, "stroke-dashoffset": offset, class: "compat-ring-arc")
      end
      label = content_tag(:div, class: "absolute inset-0 flex flex-col items-center justify-center") do
        content_tag(:span, score, class: "font-semibold leading-none text-white", style: "font-size:#{(size * 0.3).round}px") +
          content_tag(:span, "out of 100", class: "mt-[3px] font-mono uppercase tracking-[0.14em] text-white/55", style: "font-size:#{[(size * 0.065).round, 8].max}px")
      end
      svg + label
    end
  end

  # Where the score sits among the four verdict bands.
  def compat_bands(score, verdict)
    v = CrystalCompatibility::VERDICTS
    bands = [[:avoid, 0, v[:neutral][:min], "Apart"], [:neutral, v[:neutral][:min], v[:good][:min], "Neutral"],
             [:good, v[:good][:min], v[:great][:min], "Good"], [:great, v[:great][:min], 100, "Great"]]
    content_tag(:div, class: "mt-5") do
      bar = content_tag(:div, class: "relative flex h-[7px] gap-[3px]") do
        segs = bands.map do |v, lo, hi, _|
          content_tag(:span, "", class: "h-full rounded-full #{compat_colors(v)[:bar]} #{v == verdict ? 'opacity-100' : 'opacity-25'}", style: "width:#{hi - lo}%")
        end
        marker = content_tag(:span, "", class: "absolute -top-[4px] size-[15px] -translate-x-1/2 rounded-full border-[3px] border-ink bg-white shadow", style: "left:#{score.clamp(2, 98)}%", "aria-hidden": "true")
        safe_join(segs + [marker])
      end
      labels = content_tag(:div, class: "mt-2 flex gap-[3px] font-mono text-[8.5px] uppercase tracking-[0.1em] text-white/45", "aria-hidden": "true") do
        safe_join(bands.map { |v, lo, hi, l| content_tag(:span, l, class: "truncate #{'text-white/85' if v == verdict}", style: "width:#{hi - lo}%") })
      end
      bar + labels
    end
  end

  # Round stone image with a gradient fallback.
  def compat_avatar(entry, size: 52)
    style = "width:#{size}px;height:#{size}px"
    inner = if entry.image_url.present?
              image_tag(image_url_for(entry.image_url), alt: "", loading: "lazy", width: size, height: size, class: "size-full object-cover", onerror: "this.remove()")
            else
              ""
            end
    content_tag(:span, inner, class: "relative inline-block flex-none overflow-hidden rounded-full ring-2 ring-white/30", style: "#{style};background:#{stone_gradient(entry.gemstone)}")
  end

  def compat_pair_path(a, b, ctx = nil)
    tools_compatibility_path({ a: a.respond_to?(:slug) ? a.slug : a, b: b.respond_to?(:slug) ? b.slug : b, ctx: ctx.presence }.compact)
  end

  def compat_method_label(key)
    Atlas::Stone::CLEANSE_METHODS.fetch(key, key.to_s.humanize)
  end

  # Short, honest status lines that keep tradition, Vedic and physical separate.
  def compat_vedic_line(result)
    v = result.vedic
    a, b = result.a, result.b
    case v.status
    when :enemy
      # The hard rule applies when a main Navaratna gem is involved; two substitutes get a soft caution.
      Array(v.primary).any? ? ["Enemy planets: advised against", :bad] : ["Enemy planets: soft caution", :warn]
    when :friend then ["Friends", :good]
    when :same then ["Same planet", :good]
    when :neutral then ["No objection", :info]
    else
      if a.vedic_planet.blank? && b.vedic_planet.blank?
        ["Not applicable: neither stone has a planet", :info]
      else
        who = a.vedic_planet.blank? ? a : b
        ["Not applicable: #{who.name} is not a Navaratna or substitute stone", :info]
      end
    end
  end

  def compat_pairing_status(result)
    n = result.reasons.count { |r| r.topic == :pairing && r.plus? }
    m = result.reasons.count { |r| r.topic == :pairing && r.minus? }
    return ["Keep apart in the atlas", :bad] if m.positive? && n.zero?
    return ["Entries disagree", :warn] if m.positive?

    case result.a.pair_with?(result.b.slug) && result.b.pair_with?(result.a.slug)
    when true then ["Recommended by both entries", :good]
    else n.positive? ? ["Recommended by one entry", :good] : ["Not a listed pairing", :info]
    end
  end

  def compat_chip(text, tone, dark: true)
    dark_styles = { good: "bg-emerald-400/15 text-emerald-100 ring-emerald-300/25", bad: "bg-rose-400/15 text-rose-100 ring-rose-300/30",
                    warn: "bg-amber-300/15 text-amber-100 ring-amber-200/30", info: "bg-white/8 text-white/75 ring-white/15" }
    light_styles = ToolsHelper::VERDICT_STYLES
    content_tag(:span, text, class: "inline-flex items-center rounded-[10px] px-[10px] py-[6px] text-[11px] leading-[1.35] ring-1 ring-inset #{(dark ? dark_styles : light_styles)[tone]}")
  end

  def compat_reason_icon(reason)
    glyph, color = case reason.sign
                   when :plus then ["+", "bg-emerald-500/12 text-emerald-700"]
                   when :minus then ["−", "bg-rose-500/12 text-rose-700"]
                   when :practical then reason.tone == :good ? ["✓", "bg-emerald-500/12 text-emerald-700"] : (reason.tone == :warn ? ["!", "bg-amber-500/15 text-amber-800"] : ["i", "bg-sky/12 text-sky-text"])
                   else ["i", "bg-violet/8 text-violet-deep"]
                   end
    content_tag(:span, glyph, class: "mt-[2px] flex size-[20px] flex-none items-center justify-center rounded-full font-mono text-[11px] font-medium #{color}", "aria-hidden": "true")
  end

  def compat_reason_label(sign)
    { plus: "Reason for", minus: "Reason against", neutral: "Note", practical: "Care note" }[sign]
  end
end
