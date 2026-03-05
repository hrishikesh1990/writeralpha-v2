class AngelNumbersController < ApplicationController
  def index
    @articles = Article.published.in_category("angel-numbers").recent rescue []
    @meta = { title: "Angel Numbers — Meaning & Significance", description: "Explore angel number meanings." }
  end

  def show
    @number = params[:number]
    @article = Article.published.find_by(slug: "angel-number-#{@number}")
    @meta = { title: "Angel Number #{@number}: Meaning & Significance", description: "Discover the meaning of angel number #{@number}." }
  end
end
