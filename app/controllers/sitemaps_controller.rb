class SitemapsController < ApplicationController
  layout false

  def index
    @gemstones = Gemstone.published
    @articles = Article.published
    @colors = Color.all
    @healing_powers = HealingPower.all
    @birth_months = BirthMonth.all
    @zodiac_signs = ZodiacSign.all
    respond_to { |f| f.xml }
  end
end
