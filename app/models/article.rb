class Article < ApplicationRecord
  belongs_to :category, optional: true
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  before_validation :gen_slug, if: -> { slug.blank? && title.present? }
  scope :published, -> { where(published: true).where("published_at <= ?", Time.current) }
  scope :recent, -> { order(published_at: :desc) }
  scope :in_category, ->(slug) { joins(:category).where(categories: { slug: slug }) }
  def to_param; slug; end

  # Every article has exactly one canonical URL. Section is derived from the
  # slug: "crystals-for-*" guides and "a-and-b-together" pairings live under
  # /crystals, "x-vs-y" comparisons under /compare, "angel-number-N" under
  # /angel-numbers/N, everything else under /learn. /blog/:slug 301s here.
  ANGEL_PREFIX = "angel-number-"

  # Category decides the section when it is one of the section categories
  # (set by sro:import); the slug shape is the fallback for legacy rows whose
  # category is a WordPress leftover. Needed because a learn article like
  # gemstone-vs-crystal-vs-mineral would otherwise read as a comparison.
  SECTION_BY_CATEGORY = {
    "learn" => "learn", "comparisons" => "compare", "crystals-for" => "crystals",
    "crystal-pairs" => "crystals", "angel-numbers" => "angel-numbers"
  }.freeze

  def canonical_section
    SECTION_BY_CATEGORY[category&.slug] || section_from_slug
  end

  def section_from_slug
    if slug.include?("crystals-for-") || slug.match?(/-and-.+-together\z/) then "crystals"
    elsif slug.include?("-vs-") then "compare"
    elsif slug.start_with?(ANGEL_PREFIX) then "angel-numbers"
    else "learn"
    end
  end

  def canonical_path
    return "/angel-numbers/#{slug.delete_prefix(ANGEL_PREFIX)}" if canonical_section == "angel-numbers"

    "/#{canonical_section}/#{slug}"
  end
  private
  def gen_slug; self.slug = title.parameterize; end
end
