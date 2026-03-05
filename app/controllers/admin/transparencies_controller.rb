module Admin
  class TransparencysController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = Transparency.order(:name); end
    def new; @record = Transparency.new; end
    def edit; end
    def create
      @record = Transparency.new(record_params)
      @record.save ? redirect_to(admin_transparencies_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_transparencies_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_transparencies_path, notice: "Deleted."; end
    private
    def set_record; @record = Transparency.find(params[:id]); end
    def record_params; params.require(:transparency).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
