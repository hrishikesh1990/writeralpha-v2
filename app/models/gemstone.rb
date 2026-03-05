class Gemstone < ApplicationRecord
  belongs_to :transparency, optional: true
  belongs_to :lustre, optional: true
  belongs_to :birth_month, optional: true

  has_many :gemstone_colors, dependent: :destroy
  has_many :colors, through: :gemstone_colors
  has_many :gemstone_shapes, dependent: :destroy
  has_many :shapes, through: :gemstone_shapes
  has_many :gemstone_cuts, dependent: :destroy
  has_many :cuts, through: :gemstone_cuts
  has_many :gemstone_healing_powers, dependent: :destroy
  has_many :healing_powers, through: :gemstone_healing_powers
  has_many :gemstone_zodiac_signs, dependent: :destroy
  has_many :zodiac_signs, through: :gemstone_zodiac_signs

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :published, -> { where(published: true) }
  scope :alphabetical, -> { order(:name) }
  scope :starting_with, ->(letter) { where("name LIKE ?", "#{letter}%") }
  scope :by_color, ->(slug) { joins(:colors).where(colors: { slug: slug }) }
  scope :by_shape, ->(slug) { joins(:shapes).where(shapes: { slug: slug }) }
  scope :by_cut, ->(slug) { joins(:cuts).where(cuts: { slug: slug }) }
  scope :by_healing_power, ->(slug) { joins(:healing_powers).where(healing_powers: { slug: slug }) }
  scope :by_transparency, ->(slug) { joins(:transparency).where(transparencies: { slug: slug }) }
  scope :by_lustre, ->(slug) { joins(:lustre).where(lustres: { slug: slug }) }
  scope :by_birth_month, ->(name_val) { joins(:birth_month).where("LOWER(birth_months.name) = ?", name_val.downcase) }
  scope :by_zodiac, ->(slug) { joins(:zodiac_signs).where(zodiac_signs: { slug: slug }) }
  scope :by_element, ->(el) { where("LOWER(element) = ?", el.downcase) }
  scope :by_planet, ->(pl) { where("LOWER(ruling_planet) = ?", pl.downcase) }

  def to_param; slug; end

  SUB_PAGES = [
    { title_tpl: "%{name} Meaning, Properties & Benefits", path: "meaning", icon: "✨" },
    { title_tpl: "Who Should Not Wear %{name}", path: "who-should-not-wear", icon: "⚠️" },
    { title_tpl: "Can %{name} Go in Water?", path: "can-go-in-water", icon: "💧" },
    { title_tpl: "How to Tell if %{name} is Real", path: "how-to-identify", icon: "🔍" },
    { title_tpl: "Sleeping With %{name} Under Pillow", path: "sleeping-with", icon: "🌙" },
    { title_tpl: "How to Cleanse & Charge %{name}", path: "how-to-cleanse", icon: "🔄" },
    { title_tpl: "Best Crystal Combinations for %{name}", path: "combinations", icon: "💎" },
    { title_tpl: "%{name} Affirmations", path: "affirmations", icon: "🙏" },
    { title_tpl: "Is %{name} Expensive? Price Guide", path: "price-guide", icon: "💰" },
  ].freeze

  def hub_sub_pages
    SUB_PAGES.map { |sp| { title: sp[:title_tpl] % { name: name }, path: sp[:path], icon: sp[:icon] } }
  end

  private
  def generate_slug; self.slug = name.parameterize; end
end
