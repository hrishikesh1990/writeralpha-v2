# frozen_string_literal: true

# An Atlas stone joined to its published Gemstone row: Atlas supplies the
# structured facts, the DB supplies the URL, image and which guides exist.
# Only stones that are both published and have an Atlas file appear.
#
#   AtlasEntry.all                      # => [AtlasEntry, ...] by name
#   AtlasEntry.find("amethyst")         # => AtlasEntry or nil
#   e.stone.safety("water")             # Atlas::Stone accessors are also delegated:
#   e.safety("water"); e.path; e.image_url; e.guide?("can-go-in-water")
class AtlasEntry
  attr_reader :stone, :gemstone

  delegate_missing_to :stone
  delegate :featured_image_url, :colors, to: :gemstone

  # Lightweight projection: no content columns, plus one boolean per guide.
  GUIDE_FLAGS = Gemstone::SUB_PAGE_FIELDS.map do |path, field|
    "(gemstones.#{field} IS NOT NULL AND gemstones.#{field} <> '') AS has_#{path.tr('-', '_')}"
  end.freeze

  class << self
    # One lean query per call (85 rows, no content columns); controllers
    # call this once per request.
    def all
      gems = rows.index_by(&:slug)
      Atlas.stones.filter_map { |s| (g = gems[s.slug]) && new(s, g) }
    end

    def find(slug) = all.find { |e| e.slug == slug.to_s }
    def by_slug = all.index_by(&:slug)
    def options = all.map { |e| [e.name, e.slug] } # for <select>

    private

    def rows
      Gemstone.published
              .select(:id, :slug, :name, :featured_image_url, :listed, :updated_at, *GUIDE_FLAGS.map { |f| Arel.sql(f) })
              .includes(:colors)
              .to_a
    end
  end

  def initialize(stone, gemstone)
    @stone = stone
    @gemstone = gemstone
  end

  def path = "/gemstones/#{slug}"
  def guide_path(guide) = "/gemstones/#{slug}/#{guide}"
  def image_url = gemstone.featured_image_url
  def listed? = gemstone.listed

  # Does this stone have a published guide at /gemstones/<slug>/<path>?
  def guide?(path)
    v = gemstone.attributes["has_#{path.to_s.tr('-', '_')}"]
    v == true || v == 1 || v == "t"
  end
end
