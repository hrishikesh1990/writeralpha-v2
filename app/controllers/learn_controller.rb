class LearnController < ApplicationController
  def show
    render_article_or_redirect(Article.published.find_by(slug: params[:slug]))
  end

  def compare
    render_article_or_redirect(Article.published.find_by(slug: params[:slug]))
  end
end
