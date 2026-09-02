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
  # slug: "crystals-for-*" guides live under /crystals, "x-vs-y" comparisons
  # under /compare, everything else under /learn. /blog/:slug 301s here.
  def canonical_section
    if slug.include?("crystals-for-") then "crystals"
    elsif slug.include?("-vs-") then "compare"
    else "learn"
    end
  end

  def canonical_path
    "/#{canonical_section}/#{slug}"
  end
  private
  def gen_slug; self.slug = title.parameterize; end
end
