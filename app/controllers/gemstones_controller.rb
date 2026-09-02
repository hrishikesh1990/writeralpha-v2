class GemstonesController < ApplicationController
  # Directory filter dimensions accepted as query params (AND-combined).
  FILTER_KEYS = %i[color healing transparency zodiac letter birth_month lustre element planet shape cut].freeze

  before_action :load_gemstone, only: [:show, :sub_page]
  before_action :load_filter_options, only: [:index, :by_filter]

  def index
    @active = active_filters_from_params
    @gemstones = apply_filters(directory_scope, @active).distinct
    @heading = "Gemstone directory"
    @meta = { title: "Gemstone Directory — Explore All Gemstones & Crystals",
              description: "Browse our comprehensive gemstone directory. Filter by color, healing power, transparency, zodiac, and more." }
  end

  def show
    @similar_gemstones = similar_stones(@gemstone)
    @meta = { title: helpers.gemstone_hub_title(@gemstone),
              description: @gemstone.meta_description.presence || helpers.gemstone_hub_description(@gemstone),
              image: @gemstone.featured_image_url }
  end

  def sub_page
    path = params[:page].to_s.tr("_", "-")
    @sub_page = Gemstone::SUB_PAGES.find { |s| s[:path] == path }
    @content = @gemstone.sub_page_content(path)
    # A guide that was never written is a 404, not a placeholder page.
    return render_not_found if @sub_page.nil? || @content.blank?

    @page_title = @sub_page[:title_tpl] % { name: @gemstone.name }
    @page_icon = @sub_page[:icon]
    @meta = { title: @page_title, description: helpers.meta_description(@content), type: "article", image: @gemstone.featured_image_url }
    render "gemstones/sub_page"
  end

  def by_filter
    ft = params[:filter_type]
    value = params[:value] || params[:color]

    @filter_name =
      case ft
      when "color"        then Color.find_by(slug: value)&.name
      when "transparency" then Transparency.find_by(slug: value)&.name
      when "shape"        then Shape.find_by(slug: value)&.name
      when "cut"          then Cut.find_by(slug: value)&.name
      when "lustre"       then Lustre.find_by(slug: value)&.name
      when "healing"      then HealingPower.find_by(slug: value)&.name
      when "zodiac"       then ZodiacSign.find_by(slug: value)&.name
      when "letter"       then value.to_s.upcase
      else value.to_s.capitalize
      end

    @active = { ft.to_sym => (ft == "letter" ? value.to_s.upcase : value) }
    @gemstones = apply_filters(directory_scope, @active).distinct
    @filter_type_label = ft.tr("_", " ").capitalize
    @heading = "#{@filter_name} gemstones"
    @meta = { title: "#{@filter_name} Gemstones — #{@gemstones.size} #{'Stone'.pluralize(@gemstones.size)} With Meanings & Properties",
              description: helpers.filter_page_description(@filter_name, @filter_type_label, @gemstones) }
    render "gemstones/index"
  end

  private

  # Unknown slugs consult the redirects table first (merged duplicates such
  # as jade-crystal -> jade), then 404 inside the layout.
  def load_gemstone
    @gemstone = Gemstone.published.includes(:colors, :healing_powers, :zodiac_signs, :transparency, :lustre, :birth_month).find_by(slug: params[:slug])
    return if @gemstone

    if (entry = Redirect.find_by(old_path: request.path))
      redirect_to entry.new_path, status: (entry.status_code || 301)
    else
      render_not_found
    end
  end

  def load_filter_options
    browsable = Gemstone.published.listed
    @colors = Color.joins(:gemstones).merge(browsable).distinct.order(:id)
    @healing_powers = HealingPower.joins(:gemstones).merge(browsable).distinct.order(:id)
    @transparencies = Transparency.joins(:gemstones).merge(browsable).distinct.order(:id)
    @zodiac_signs = ZodiacSign.order(:id)
    @letters = browsable.pluck(:name).map { |n| n[0].upcase }.uniq.sort
    @total_count = browsable.count
  end

  def directory_scope
    Gemstone.published.listed.alphabetical.preload(:colors, :healing_powers, :transparency)
  end

  def active_filters_from_params
    active = params.permit(*FILTER_KEYS, :q).to_h.symbolize_keys.compact_blank
    active[:letter] = active[:letter].to_s[0].upcase if active[:letter]
    active
  end

  def apply_filters(scope, f)
    scope = scope.by_color(f[:color])               if f[:color]
    scope = scope.by_healing_power(f[:healing])     if f[:healing]
    scope = scope.by_transparency(f[:transparency]) if f[:transparency]
    scope = scope.by_zodiac(f[:zodiac])             if f[:zodiac]
    scope = scope.starting_with(f[:letter])         if f[:letter]
    scope = scope.by_birth_month(f[:birth_month])   if f[:birth_month]
    scope = scope.by_lustre(f[:lustre])             if f[:lustre]
    scope = scope.by_element(f[:element])           if f[:element]
    scope = scope.by_planet(f[:planet])             if f[:planet]
    scope = scope.by_shape(f[:shape])               if f[:shape]
    scope = scope.by_cut(f[:cut])                   if f[:cut]
    scope = scope.search(f[:q])                     if f[:q]
    scope
  end

  # Up to four stones sharing colors and/or healing powers, best overlap first.
  def similar_stones(gemstone)
    color_ids = gemstone.color_ids
    power_ids = gemstone.healing_power_ids
    Gemstone.published.listed.where.not(id: gemstone.id).includes(:colors, :healing_powers)
      .map { |g| [g, (g.color_ids & color_ids).size + (g.healing_power_ids & power_ids).size] }
      .select { |_, score| score.positive? }
      .sort_by { |g, score| [-score, g.name] }
      .first(4).map(&:first)
  end
end
