module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        gemstones: Gemstone.count, published_gemstones: Gemstone.published.count,
        articles: Article.count, categories: Category.count,
        colors: Color.count, redirects: Redirect.count
      }
      @recent_gemstones = Gemstone.order(updated_at: :desc).limit(10)
      @recent_articles = Article.order(updated_at: :desc).limit(10)
    end
  end
end
