class BlogController < ApplicationController
  def index
    @articles = Article.published.recent.includes(:category)
    if params[:category].present?
      @category = Category.find_by(slug: params[:category])
      @articles = @articles.in_category(params[:category])
    end
    @meta = { title: "#{@category ? @category.name : 'Blog'} — WriterAlpha",
              description: @category&.description.presence || "Guides, comparisons and stories from the atlas of stones — crystal care, safety, meanings and more." }
  end

  # /blog/:slug is never canonical; send readers (and crawlers) to the
  # article's section URL.
  def show
    article = Article.published.find_by(slug: params[:slug])
    return render_not_found unless article

    redirect_to article.canonical_path, status: :moved_permanently
  end
end
