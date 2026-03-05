class TeamNamesController < ApplicationController
  def index
    @articles = Article.published.in_category("team-names").recent rescue []
    @meta = { title: "Team Name Ideas — Sports, Work, Gaming & More", description: "Find the perfect team name." }
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @meta = { title: @article.meta_title || @article.title, description: @article.meta_description || @article.excerpt }
  end

  def groups_index
    @articles = Article.published.in_category("group-names").recent rescue []
    @meta = { title: "Group Name Ideas", description: "Creative group name ideas." }
    render :index
  end

  def group_show
    @article = Article.published.find_by!(slug: params[:slug])
    @meta = { title: @article.title, description: @article.excerpt }
    render :show
  end
end
