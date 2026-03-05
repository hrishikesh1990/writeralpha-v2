module Admin
  class LustresController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = Lustre.order(:name); end
    def new; @record = Lustre.new; end
    def edit; end
    def create
      @record = Lustre.new(record_params)
      @record.save ? redirect_to(admin_lustres_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_lustres_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_lustres_path, notice: "Deleted."; end
    private
    def set_record; @record = Lustre.find(params[:id]); end
    def record_params; params.require(:lustre).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
