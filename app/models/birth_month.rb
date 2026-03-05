class BirthMonth < ApplicationRecord
  has_many :gemstones
  validates :name, presence: true
  validates :month_number, presence: true
end
