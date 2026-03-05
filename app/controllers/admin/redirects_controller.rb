module Admin
  class RedirectsController < BaseController
    before_action :set_redirect, only: [:edit, :update, :destroy]
    def index; @redirects = Redirect.order(:old_path); end
    def new; @redirect = Redirect.new; end
    def edit; end
    def create
      @redirect = Redirect.new(redirect_params)
      @redirect.save ? redirect_to(admin_redirects_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @redirect.update(redirect_params) ? redirect_to(admin_redirects_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @redirect.destroy; redirect_to admin_redirects_path, notice: "Deleted."; end
    private
    def set_redirect; @redirect = Redirect.find(params[:id]); end
    def redirect_params; params.require(:redirect).permit(:old_path, :new_path, :status_code); end
  end
end
