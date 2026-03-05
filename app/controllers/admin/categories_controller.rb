module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: [:edit, :update, :destroy]
    def index; @categories = Category.includes(:parent).order(:name); end
    def new; @category = Category.new; @parents = Category.where(parent_id: nil).order(:name); end
    def edit; @parents = Category.where(parent_id: nil).where.not(id: @category.id).order(:name); end
    def create
      @category = Category.new(cat_params)
      @category.save ? redirect_to(admin_categories_path, notice: "Created.") : ((@parents = Category.where(parent_id: nil).order(:name)); render(:new, status: :unprocessable_entity))
    end
    def update
      @category.update(cat_params) ? redirect_to(admin_categories_path, notice: "Updated.") : ((@parents = Category.where(parent_id: nil).where.not(id: @category.id).order(:name)); render(:edit, status: :unprocessable_entity))
    end
    def destroy; @category.destroy; redirect_to admin_categories_path, notice: "Deleted."; end
    private
    def set_category; @category = Category.find(params[:id]); end
    def cat_params; params.require(:category).permit(:name, :slug, :description, :parent_id); end
  end
end
