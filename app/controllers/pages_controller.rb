class PagesController < ApplicationController
  # Home "Featured stones" grid, in display order.
  FEATURED_SLUGS = %w[amethyst rose-quartz labradorite citrine moonstone black-tourmaline lapis-lazuli tiger-eye].freeze

  def home
    by_slug = Gemstone.published.where(slug: FEATURED_SLUGS).includes(:colors, :healing_powers).index_by(&:slug)
    @featured_gemstones = FEATURED_SLUGS.filter_map { |slug| by_slug[slug] }
    if @featured_gemstones.size < FEATURED_SLUGS.size
      @featured_gemstones += Gemstone.published.alphabetical.where.not(slug: FEATURED_SLUGS)
        .includes(:colors, :healing_powers).limit(FEATURED_SLUGS.size - @featured_gemstones.size).to_a
    end

    @gemstone_count = Gemstone.published.count
    @color_count = Color.count
    @healing_power_count = HealingPower.count
    @zodiac_signs = ZodiacSign.order(:id)
    @meta = { title: "WriterAlpha — Find the crystal your energy is asking for",
              description: "#{@gemstone_count} stones, 11 ways to search — by color, healing power, zodiac, birth month and more." }
  end

  def about; end
  def contact; end
  def write_for_us; end
end
