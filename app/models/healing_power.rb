class HealingPower < ApplicationRecord
  has_many :gemstone_healing_powers, dependent: :destroy
has_many :gemstones, through: :gemstone_healing_powers
  validates :name, presence: true
  before_validation -> { self.slug = name.parameterize if slug.blank? && name.present? }
  def to_param; slug; end
end
