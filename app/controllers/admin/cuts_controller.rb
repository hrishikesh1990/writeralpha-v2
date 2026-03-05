module Admin
  class CutsController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = Cut.order(:name); end
    def new; @record = Cut.new; end
    def edit; end
    def create
      @record = Cut.new(record_params)
      @record.save ? redirect_to(admin_cuts_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_cuts_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_cuts_path, notice: "Deleted."; end
    private
    def set_record; @record = Cut.find(params[:id]); end
    def record_params; params.require(:cut).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
