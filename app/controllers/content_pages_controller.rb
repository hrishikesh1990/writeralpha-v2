class ContentPagesController < ApplicationController
  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @section = params[:section]
    @meta = { title: @article.meta_title || @article.title, description: @article.meta_description || @article.excerpt }
  end
end
