module Admin
  class ArticlesController < BaseController
    before_action :set_article, only: [:show, :edit, :update, :destroy]

    def index; @articles = Article.order(updated_at: :desc).includes(:category); end
    def new; @article = Article.new; @categories = Category.order(:name); end
    def show; redirect_to edit_admin_article_path(@article); end
    def edit; @categories = Category.order(:name); end

    def create
      @article = Article.new(article_params)
      if @article.save
        redirect_to admin_articles_path, notice: "Article created."
      else
        @categories = Category.order(:name); render :new, status: :unprocessable_entity
      end
    end

    def update
      if @article.update(article_params)
        redirect_to admin_articles_path, notice: "Article updated."
      else
        @categories = Category.order(:name); render :edit, status: :unprocessable_entity
      end
    end

    def destroy; @article.destroy; redirect_to admin_articles_path, notice: "Deleted."; end

    private
    def set_article; @article = Article.find(params[:id]); end
    def article_params
      params.require(:article).permit(:title, :slug, :content, :excerpt, :category_id,
        :featured_image_url, :meta_title, :meta_description, :published, :published_at)
    end
  end
end
