class Shape < ApplicationRecord
  has_many :gemstone_shapes, dependent: :destroy
has_many :gemstones, through: :gemstone_shapes
  validates :name, presence: true
  before_validation -> { self.slug = name.parameterize if slug.blank? && name.present? }
  def to_param; slug; end
end
