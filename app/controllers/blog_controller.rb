class BlogController < ApplicationController
  def index
    @articles = Article.published.recent.includes(:category)
    @meta = { title: "Blog — Writer Alpha", description: "Latest articles." }
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @meta = { title: @article.meta_title || @article.title, description: @article.meta_description || @article.excerpt }
  end
end
