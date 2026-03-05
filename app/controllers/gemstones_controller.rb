class GemstonesController < ApplicationController
  before_action :load_gemstone, only: [:show, :sub_page]
  before_action :load_filter_options, only: [:index]

  def index
    @gemstones = Gemstone.published.alphabetical
      .includes(:colors, :shapes, :cuts, :healing_powers, :transparency, :lustre, :birth_month, :zodiac_signs)
    apply_query_filters
    @gemstones = @gemstones.distinct
    @meta = { title: "Gemstone Directory — Explore All Gemstones & Crystals",
              description: "Browse our comprehensive gemstone directory. Filter by color, shape, healing power, zodiac, and more." }
  end

  def show
    @meta = { title: "#{@gemstone.name}: Meaning, Properties & Complete Guide",
              description: @gemstone.meta_description || "Learn everything about #{@gemstone.name}." }
  end

  def sub_page
    page_key = params[:page]
    content_field = "#{page_key}_content"
    @content = @gemstone.respond_to?(content_field) ? @gemstone.send(content_field) : nil

    sp = Gemstone::SUB_PAGES.find { |s| s[:path] == page_key.tr("_", "-") }
    @page_title = sp ? (sp[:title_tpl] % { name: @gemstone.name }) : @gemstone.name
    @page_icon = sp&.dig(:icon) || "💎"
    @meta = { title: @page_title, description: "#{@page_title}. Complete guide and expert advice." }
    render "gemstones/sub_page"
  end

  def by_filter
    ft = params[:filter_type]
    value = params[:value] || params[:color]
    @gemstones = Gemstone.published.alphabetical.includes(:colors, :transparency, :lustre)

    case ft
    when "color" then @filter_name = (c = Color.find_by(slug: value))&.name; @gemstones = @gemstones.by_color(value)
    when "transparency" then @filter_name = (t = Transparency.find_by(slug: value))&.name; @gemstones = @gemstones.by_transparency(value)
    when "shape" then @filter_name = Shape.find_by(slug: value)&.name; @gemstones = @gemstones.by_shape(value)
    when "cut" then @filter_name = Cut.find_by(slug: value)&.name; @gemstones = @gemstones.by_cut(value)
    when "lustre" then @filter_name = Lustre.find_by(slug: value)&.name; @gemstones = @gemstones.by_lustre(value)
    when "healing" then @filter_name = HealingPower.find_by(slug: value)&.name; @gemstones = @gemstones.by_healing_power(value)
    when "birth_month" then @filter_name = value.capitalize; @gemstones = @gemstones.by_birth_month(value)
    when "letter" then @filter_name = value.upcase; @gemstones = @gemstones.starting_with(value.upcase)
    when "zodiac" then @filter_name = ZodiacSign.find_by(slug: value)&.name; @gemstones = @gemstones.by_zodiac(value)
    when "element" then @filter_name = value.capitalize; @gemstones = @gemstones.by_element(value)
    when "planet" then @filter_name = value.capitalize; @gemstones = @gemstones.by_planet(value)
    end

    @filter_type_label = ft.tr("_", " ").capitalize
    @gemstones = @gemstones.distinct
    @meta = { title: "#{@filter_name} Gemstones — Complete Guide",
              description: "Discover all #{@filter_name&.downcase} gemstones and crystals." }
    render "gemstones/filtered"
  end

  private

  def load_gemstone
    @gemstone = Gemstone.published.find_by!(slug: params[:slug])
  end

  def load_filter_options
    @colors = Color.joins(:gemstones).merge(Gemstone.published).distinct.order(:name)
    @healing_powers = HealingPower.joins(:gemstones).merge(Gemstone.published).distinct.order(:name)
    @birth_months = BirthMonth.joins(:gemstones).merge(Gemstone.published).distinct.order(:month_number)
    @zodiac_signs = ZodiacSign.joins(:gemstones).merge(Gemstone.published).distinct.order(:name)
    @transparencies = Transparency.joins(:gemstones).merge(Gemstone.published).distinct.order(:name)
    @letters = Gemstone.published.pluck(:name).map { |n| n[0].upcase }.uniq.sort
  end

  def apply_query_filters
    @gemstones = @gemstones.by_color(params[:color]) if params[:color].present?
    @gemstones = @gemstones.by_healing_power(params[:healing]) if params[:healing].present?
    @gemstones = @gemstones.by_transparency(params[:transparency]) if params[:transparency].present?
  end
end
