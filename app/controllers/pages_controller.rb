class PagesController < ApplicationController
  def home
    @featured_gemstones = Gemstone.published.alphabetical.limit(12).includes(:colors, :transparency, :lustre)
    @gemstone_count = Gemstone.published.count
    @recent_articles = Article.published.recent.limit(6) rescue []
  end

  def about; end
  def contact; end
  def write_for_us; end
end
