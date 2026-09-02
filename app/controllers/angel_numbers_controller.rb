class AngelNumbersController < ApplicationController
  # Angel numbers are unlinked from the nav and sitemap until real guides
  # exist; only published articles are listed and numbers without an
  # article return 404 rather than a placeholder.
  def index
    @articles = Article.published.where("slug LIKE ?", "angel-number-%").recent
    @meta = { title: "Angel Numbers — Meaning & Significance", description: "Explore the spiritual meaning behind the numbers you keep seeing." }
  end

  def show
    @number = params[:number]
    article = Article.published.find_by(slug: "angel-number-#{@number}")
    return render_not_found unless article

    @article = article
    @meta = { title: article.meta_title.presence || article.title,
              description: helpers.meta_description(article.meta_description.presence || article.excerpt.presence || article.content),
              type: "article", image: article.featured_image_url }
  end
end
