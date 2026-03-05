module Admin
  class HealingPowersController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = HealingPower.order(:name); end
    def new; @record = HealingPower.new; end
    def edit; end
    def create
      @record = HealingPower.new(record_params)
      @record.save ? redirect_to(admin_healing_powers_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_healing_powers_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_healing_powers_path, notice: "Deleted."; end
    private
    def set_record; @record = HealingPower.find(params[:id]); end
    def record_params; params.require(:healing_power).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
