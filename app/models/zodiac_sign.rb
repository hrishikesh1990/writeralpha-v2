class ZodiacSign < ApplicationRecord
  has_many :gemstone_zodiac_signs, dependent: :destroy
has_many :gemstones, through: :gemstone_zodiac_signs
  validates :name, presence: true
  before_validation -> { self.slug = name.parameterize if slug.blank? && name.present? }
  def to_param; slug; end
end
