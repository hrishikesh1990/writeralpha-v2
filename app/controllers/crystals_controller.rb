class CrystalsController < ApplicationController
  def for_purpose
    @purpose = params[:purpose].tr("-", " ").titleize
    @article = Article.published.find_by(slug: "crystals-for-#{params[:purpose]}")
    @meta = { title: "Best Crystals for #{@purpose}", description: "Discover the best healing crystals for #{@purpose.downcase}." }
  end

  def pair
    @article = Article.published.find_by(slug: params[:slug])
    @pair_name = params[:slug].tr("-", " ").titleize.gsub(" And ", " and ").gsub(" Together", "")
    @meta = { title: "#{@pair_name} Together: Meaning & Benefits", description: "Benefits of using #{@pair_name.downcase} together." }
  end
end
