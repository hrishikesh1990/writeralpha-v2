module Admin
  class ShapesController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = Shape.order(:name); end
    def new; @record = Shape.new; end
    def edit; end
    def create
      @record = Shape.new(record_params)
      @record.save ? redirect_to(admin_shapes_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_shapes_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_shapes_path, notice: "Deleted."; end
    private
    def set_record; @record = Shape.find(params[:id]); end
    def record_params; params.require(:shape).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
