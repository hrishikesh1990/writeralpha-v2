class SitemapsController < ApplicationController
  layout false

  # Filter pages are only worth indexing once they list a few stones.
  MIN_STONES_FOR_FILTER_PAGE = 3

  def index
    @gemstones = Gemstone.published.order(:name)
    @articles = Article.published.order(:slug)
    @filter_pages = filter_pages
    respond_to { |f| f.xml }
  end

  private

  def filter_pages
    listed = Gemstone.published.listed
    pages = []
    Color.joins(:gemstones).merge(listed).group("colors.id").having("COUNT(*) >= ?", MIN_STONES_FOR_FILTER_PAGE).pluck(:slug)
      .each { |slug| pages << gemstones_by_color_path(color: slug) }
    HealingPower.joins(:gemstones).merge(listed).group("healing_powers.id").having("COUNT(*) >= ?", MIN_STONES_FOR_FILTER_PAGE).pluck(:slug)
      .each { |slug| pages << gemstones_by_healing_path(value: slug) }
    ZodiacSign.joins(:gemstones).merge(listed).group("zodiac_signs.id").having("COUNT(*) >= ?", MIN_STONES_FOR_FILTER_PAGE).pluck(:slug)
      .each { |slug| pages << gemstones_by_zodiac_path(value: slug) }
    Transparency.joins(:gemstones).merge(listed).group("transparencies.id").having("COUNT(*) >= ?", MIN_STONES_FOR_FILTER_PAGE).pluck(:slug)
      .each { |slug| pages << gemstones_by_transparency_path(value: slug) }
    BirthMonth.joins(:gemstones).merge(listed).group("birth_months.id").having("COUNT(*) >= ?", MIN_STONES_FOR_FILTER_PAGE).pluck(:name)
      .each { |name| pages << gemstones_by_birth_month_path(value: name.downcase) }
    pages
  end
end
