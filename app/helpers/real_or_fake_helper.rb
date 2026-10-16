# frozen_string_literal: true

# View helpers for the Real or Fake? tool and its embeds.
module RealOrFakeHelper
  ROF_CHOICES = [
    ["real", "Looked real"],
    ["fake", "Looked fake"],
    ["unsure", "Couldn't tell"]
  ].freeze

  # Choice pill classes (the pill is the span after a visually hidden radio).
  ROF_CHOICE_BASE = "flex min-h-[48px] cursor-pointer select-none items-center justify-center rounded-[14px] border border-violet/15 bg-white px-2 text-center text-[13px] font-medium leading-tight text-ui card-transition before:mr-1.5 hover:border-violet/40 peer-focus-visible:ring-2 peer-focus-visible:ring-violet/60 peer-focus-visible:ring-offset-2 peer-checked:before:content-['✓']"
  ROF_CHOICE_TONES = {
    "real" => "peer-checked:border-emerald-600/50 peer-checked:bg-emerald-500/10 peer-checked:text-emerald-800",
    "fake" => "peer-checked:border-amber-600/50 peer-checked:bg-amber-500/12 peer-checked:text-amber-900",
    "unsure" => "peer-checked:border-violet/50 peer-checked:bg-violet/10 peer-checked:text-violet-deep"
  }.freeze

  # What you need in your hand, derived from the stone's own tests.
  ROF_KIT = {
    "magnification" => "A 10x loupe or a phone macro lens",
    "bubbles" => "A 10x loupe or a phone macro lens",
    "inclusions" => "A 10x loupe or a phone macro lens",
    "magnet" => "A small magnet",
    "uv" => "A UV torch",
    "light" => "A lamp or a bright window",
    "color" => "White paper and daylight",
    "weight" => "A bead or stone of similar size to compare",
    "streak" => "An unglazed ceramic tile",
    "acetone" => "A cotton swab and nail-polish remover",
    "flame" => "A pin and a lighter",
    "hardness" => "A fingernail, a coin or a piece of plain glass",
    "scratch" => "A fingernail, a coin or a piece of plain glass",
    "water_dissolve" => "A glass of water",
    "refractive" => "A printed page and a lamp"
  }.freeze

  def rof_path(entry, answers = {}, **opts)
    tools_real_or_fake_path(stone: entry.slug, a: answers.presence, **opts)
  end

  def rof_url(entry, answers = {})
    tools_real_or_fake_url(stone: entry.slug, a: answers.presence)
  end

  def rof_choice_pill(value) = "#{ROF_CHOICE_BASE} #{ROF_CHOICE_TONES.fetch(value)}"

  # Three dots, filled to the test's weight. Text label always sits beside it.
  def rof_dots(weight)
    safe_join((1..3).map { |i| tag.span("", class: "size-[7px] rounded-full #{i <= weight ? 'bg-violet' : 'bg-violet/20'}") }, "")
  end

  def rof_kit(check)
    (["Daylight, ideally by a window"] + check.tests.filter_map { |t| ROF_KIT[t.id] }).uniq
  end

  def rof_kind_blurb(entry)
    case entry.kind
    when "mineral" then "Natural mineral"
    when "variety" then "Natural variety of #{entry.species.presence || 'its mineral'}"
    when "rock" then "Natural rock"
    when "mineraloid" then "Natural mineraloid"
    when "organic" then "Organic material"
    when "glass" then "Glass, sold under this name"
    when "synthetic" then "Lab-made stone"
    when "treated" then "Treated stone"
    else nil
    end
  end

  def rof_evidence_pips(level)
    filled = { none: 0, thin: 1, moderate: 2, good: 3 }.fetch(level, 0)
    safe_join((1..3).map { |i| tag.span("", class: "h-[5px] w-7 rounded-full #{i <= filled ? 'bg-lavender' : 'bg-white/15'}") }, "")
  end

  def rof_panel_accent(verdict)
    { genuine: "text-emerald-300", imitation: "text-amber-300", inconclusive: "text-lavender" }.fetch(verdict)
  end
end
