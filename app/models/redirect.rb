class Redirect < ApplicationRecord
  validates :old_path, presence: true, uniqueness: true
  validates :new_path, presence: true
  before_validation -> { self.status_code ||= 301 }
end
