module Admin
  class GemstonesController < BaseController
    before_action :set_gemstone, only: [:show, :edit, :update, :destroy]
    before_action :load_options, only: [:new, :edit, :create, :update]

    def index
      @gemstones = Gemstone.order(:name).includes(:colors, :transparency, :lustre, :birth_month)
    end

    def new; @gemstone = Gemstone.new; end
    def show; redirect_to edit_admin_gemstone_path(@gemstone); end
    def edit; end

    def create
      @gemstone = Gemstone.new(gemstone_params)
      if @gemstone.save
        sync_associations
        redirect_to admin_gemstones_path, notice: "#{@gemstone.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @gemstone.update(gemstone_params)
        sync_associations
        redirect_to admin_gemstones_path, notice: "#{@gemstone.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @gemstone.destroy
      redirect_to admin_gemstones_path, notice: "Deleted."
    end

    private

    def set_gemstone; @gemstone = Gemstone.find(params[:id]); end

    def load_options
      @colors = Color.order(:name)
      @shapes = Shape.order(:name)
      @cuts = Cut.order(:name)
      @lustres = Lustre.order(:name)
      @transparencies = Transparency.order(:name)
      @healing_powers = HealingPower.order(:name)
      @birth_months = BirthMonth.order(:month_number)
      @zodiac_signs = ZodiacSign.order(:name)
    end

    def gemstone_params
      params.require(:gemstone).permit(
        :name, :slug, :subtitle, :description,
        :meaning_content, :properties_content, :benefits_content, :uses_content,
        :water_safety_content, :who_should_not_wear_content, :sleeping_with_content,
        :how_to_identify_content, :how_to_cleanse_content,
        :combinations_content, :affirmations_content, :price_guide_content,
        :zodiac_content, :chakra_content,
        :mohs_hardness, :chemical_formula, :crystal_system, :element, :ruling_planet,
        :transparency_id, :lustre_id, :birth_month_id,
        :featured_image_url, :meta_title, :meta_description, :published
      )
    end

    def sync_associations
      if params[:color_ids]
        @gemstone.gemstone_colors.destroy_all
        params[:color_ids].reject(&:blank?).each { |id| GemstoneColor.find_or_create_by!(gemstone: @gemstone, color_id: id) }
      end
      if params[:healing_power_ids]
        @gemstone.gemstone_healing_powers.destroy_all
        params[:healing_power_ids].reject(&:blank?).each { |id| GemstoneHealingPower.find_or_create_by!(gemstone: @gemstone, healing_power_id: id) }
      end
      if params[:zodiac_sign_ids]
        @gemstone.gemstone_zodiac_signs.destroy_all
        params[:zodiac_sign_ids].reject(&:blank?).each { |id| GemstoneZodiacSign.find_or_create_by!(gemstone: @gemstone, zodiac_sign_id: id) }
      end
    end
  end
end
