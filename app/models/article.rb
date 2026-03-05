class Article < ApplicationRecord
  belongs_to :category, optional: true
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  before_validation :gen_slug, if: -> { slug.blank? && title.present? }
  scope :published, -> { where(published: true).where("published_at <= ?", Time.current) }
  scope :recent, -> { order(published_at: :desc) }
  scope :in_category, ->(slug) { joins(:category).where(categories: { slug: slug }) }
  def to_param; slug; end
  private
  def gen_slug; self.slug = title.parameterize; end
end
