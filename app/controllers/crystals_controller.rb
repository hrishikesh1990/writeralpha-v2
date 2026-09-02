class CrystalsController < ApplicationController
  def for_purpose
    render_article_or_redirect(Article.published.find_by(slug: "crystals-for-#{params[:purpose]}"))
  end

  def pair
    render_article_or_redirect(Article.published.find_by(slug: params[:slug]))
  end
end
