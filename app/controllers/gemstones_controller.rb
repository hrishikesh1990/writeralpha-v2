class GemstonesController < ApplicationController
  # Directory filter dimensions accepted as query params (AND-combined).
  FILTER_KEYS = %i[color healing transparency zodiac letter birth_month lustre element planet shape cut].freeze

  # Sub-page keys whose content column doesn't follow the "<key>_content" pattern.
  CONTENT_FIELDS = { "can_go_in_water" => "water_safety_content" }.freeze

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
    @meta = { title: "#{@gemstone.name}: Meaning, Properties & Complete Guide",
              description: @gemstone.meta_description || "Learn everything about #{@gemstone.name}." }
  end

  def sub_page
    page_key = params[:page]
    content_field = CONTENT_FIELDS.fetch(page_key, "#{page_key}_content")
    @content = @gemstone.respond_to?(content_field) ? @gemstone.send(content_field) : nil

    @sub_page = Gemstone::SUB_PAGES.find { |s| s[:path] == page_key.tr("_", "-") }
    @page_title = @sub_page ? (@sub_page[:title_tpl] % { name: @gemstone.name }) : @gemstone.name
    @page_icon = @sub_page&.dig(:icon) || "💎"
    @meta = { title: @page_title, description: "#{@page_title}. Complete guide and expert advice." }
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
    @meta = { title: "#{@filter_name} Gemstones — Complete Guide",
              description: "Discover all #{@filter_name&.downcase} gemstones and crystals." }
    render "gemstones/index"
  end

  private

  def load_gemstone
    @gemstone = Gemstone.published.includes(:colors, :healing_powers, :zodiac_signs, :transparency, :lustre, :birth_month).find_by!(slug: params[:slug])
  end

  def load_filter_options
    @colors = Color.joins(:gemstones).merge(Gemstone.published).distinct.order(:id)
    @healing_powers = HealingPower.joins(:gemstones).merge(Gemstone.published).distinct.order(:id)
    @transparencies = Transparency.joins(:gemstones).merge(Gemstone.published).distinct.order(:id)
    @zodiac_signs = ZodiacSign.order(:id)
    @letters = Gemstone.published.pluck(:name).map { |n| n[0].upcase }.uniq.sort
    @total_count = Gemstone.published.count
  end

  def directory_scope
    Gemstone.published.alphabetical.preload(:colors, :healing_powers, :transparency)
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
    Gemstone.published.where.not(id: gemstone.id).includes(:colors, :healing_powers)
      .map { |g| [g, (g.color_ids & color_ids).size + (g.healing_power_ids & power_ids).size] }
      .select { |_, score| score.positive? }
      .sort_by { |g, score| [-score, g.name] }
      .first(4).map(&:first)
  end
end
