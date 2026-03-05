class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  has_many :articles, dependent: :nullify
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  before_validation :gen_slug, if: -> { slug.blank? && name.present? }
  def to_param; slug; end
  private
  def gen_slug; self.slug = name.parameterize; end
end
