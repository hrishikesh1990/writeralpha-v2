class Lustre < ApplicationRecord
  has_many :gemstones
  validates :name, presence: true
  before_validation -> { self.slug = name.parameterize if slug.blank? && name.present? }
  def to_param; slug; end
end
