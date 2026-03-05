class Cut < ApplicationRecord
  has_many :gemstone_cuts, dependent: :destroy
has_many :gemstones, through: :gemstone_cuts
  validates :name, presence: true
  before_validation -> { self.slug = name.parameterize if slug.blank? && name.present? }
  def to_param; slug; end
end
