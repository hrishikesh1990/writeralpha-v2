module Admin
  class ZodiacSignsController < BaseController
    before_action :set_record, only: [:edit, :update, :destroy]
    def index; @records = ZodiacSign.order(:name); end
    def new; @record = ZodiacSign.new; end
    def edit; end
    def create
      @record = ZodiacSign.new(record_params)
      @record.save ? redirect_to(admin_zodiac_signs_path, notice: "Created.") : render(:new, status: :unprocessable_entity)
    end
    def update
      @record.update(record_params) ? redirect_to(admin_zodiac_signs_path, notice: "Updated.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy; @record.destroy; redirect_to admin_zodiac_signs_path, notice: "Deleted."; end
    private
    def set_record; @record = ZodiacSign.find(params[:id]); end
    def record_params; params.require(:zodiac_sign).permit(:name, :slug, :description, :hex_code, :symbol, :date_range, :element, :month_number); end
  end
end
