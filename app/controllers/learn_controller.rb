class LearnController < ApplicationController
  def show
    @article = Article.published.find_by(slug: params[:slug])
    @meta = { title: @article&.meta_title || @article&.title || "Learn", description: @article&.meta_description || @article&.excerpt }
  end

  def compare
    @article = Article.published.find_by(slug: params[:slug])
    @comparison_name = params[:slug].tr("-", " ").titleize.gsub(" Vs ", " vs ")
    @meta = { title: "#{@comparison_name}: Comparison Guide", description: "Side-by-side comparison." }
  end
end
