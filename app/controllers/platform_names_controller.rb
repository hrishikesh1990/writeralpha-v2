class PlatformNamesController < ApplicationController
  def index
    @platform = params[:platform].capitalize
    @articles = Article.published.in_category("#{params[:platform]}-names").recent rescue []
    @meta = { title: "#{@platform} Username Ideas", description: "Creative #{@platform} username ideas." }
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @platform = params[:platform].capitalize
    @meta = { title: @article.title, description: @article.excerpt }
  end
end
