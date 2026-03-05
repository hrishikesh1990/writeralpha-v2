class BusinessNamesController < ApplicationController
  def index
    @articles = Article.published.in_category("business-names").recent.limit(50) rescue Article.published.recent.limit(50)
    @meta = { title: "Business Name Ideas — Names for Every Industry", description: "Find the perfect business name." }
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @meta = { title: @article.meta_title || @article.title, description: @article.meta_description || @article.excerpt }
  end

  def by_style
    @style = params[:style].tr("-", " ").titleize
    @articles = Article.published.where("title LIKE ?", "%#{@style}%").recent rescue []
    @meta = { title: "#{@style} Business Names", description: "#{@style} business name ideas." }
    render :index
  end
end
