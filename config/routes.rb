Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"

  # ===== ADMIN =====
  namespace :admin do
    root "dashboard#index"
    resources :gemstones
    resources :articles
    resources :categories, except: [:show]
    resources :redirects, except: [:show]
    resources :colors, except: [:show]
    resources :shapes, except: [:show]
    resources :cuts, except: [:show]
    resources :lustres, except: [:show]
    resources :transparencies, except: [:show]
    resources :healing_powers, except: [:show]
    resources :zodiac_signs, except: [:show]
  end

  # ===== GEMSTONES =====
  get "gemstones", to: "gemstones#index", as: :gemstones
  # Filters (must be before :slug to avoid conflicts)
  get "gemstones/color/:color", to: "gemstones#by_filter", defaults: { filter_type: "color" }, as: :gemstones_by_color
  get "gemstones/transparency/:value", to: "gemstones#by_filter", defaults: { filter_type: "transparency" }, as: :gemstones_by_transparency
  get "gemstones/shape/:value", to: "gemstones#by_filter", defaults: { filter_type: "shape" }, as: :gemstones_by_shape
  get "gemstones/cut/:value", to: "gemstones#by_filter", defaults: { filter_type: "cut" }, as: :gemstones_by_cut
  get "gemstones/lustre/:value", to: "gemstones#by_filter", defaults: { filter_type: "lustre" }, as: :gemstones_by_lustre
  get "gemstones/healing/:value", to: "gemstones#by_filter", defaults: { filter_type: "healing" }, as: :gemstones_by_healing
  get "gemstones/birth-month/:value", to: "gemstones#by_filter", defaults: { filter_type: "birth_month" }, as: :gemstones_by_birth_month
  get "gemstones/starting-with/:value", to: "gemstones#by_filter", defaults: { filter_type: "letter" }, as: :gemstones_by_letter
  get "gemstones/zodiac/:value", to: "gemstones#by_filter", defaults: { filter_type: "zodiac" }, as: :gemstones_by_zodiac
  get "gemstones/element/:value", to: "gemstones#by_filter", defaults: { filter_type: "element" }, as: :gemstones_by_element
  get "gemstones/planet/:value", to: "gemstones#by_filter", defaults: { filter_type: "planet" }, as: :gemstones_by_planet
  # Hub + sub-pages
  get "gemstones/:slug", to: "gemstones#show", as: :gemstone
  get "gemstones/:slug/meaning", to: "gemstones#sub_page", defaults: { page: "meaning" }, as: :gemstone_meaning
  get "gemstones/:slug/who-should-not-wear", to: "gemstones#sub_page", defaults: { page: "who_should_not_wear" }, as: :gemstone_who_should_not_wear
  get "gemstones/:slug/can-go-in-water", to: "gemstones#sub_page", defaults: { page: "can_go_in_water" }, as: :gemstone_water
  get "gemstones/:slug/how-to-identify", to: "gemstones#sub_page", defaults: { page: "how_to_identify" }, as: :gemstone_identify
  get "gemstones/:slug/sleeping-with", to: "gemstones#sub_page", defaults: { page: "sleeping_with" }, as: :gemstone_sleeping
  get "gemstones/:slug/how-to-cleanse", to: "gemstones#sub_page", defaults: { page: "how_to_cleanse" }, as: :gemstone_cleanse
  get "gemstones/:slug/combinations", to: "gemstones#sub_page", defaults: { page: "combinations" }, as: :gemstone_combinations
  get "gemstones/:slug/affirmations", to: "gemstones#sub_page", defaults: { page: "affirmations" }, as: :gemstone_affirmations
  get "gemstones/:slug/price-guide", to: "gemstones#sub_page", defaults: { page: "price_guide" }, as: :gemstone_price

  # ===== CRYSTALS FOR / PAIRS =====
  get "crystals/crystals-for-:purpose", to: "crystals#for_purpose", as: :crystals_for
  get "crystals/:slug", to: "crystals#pair", as: :crystal_pair

  # ===== COMPARE / LEARN / ANGEL NUMBERS =====
  get "compare/:slug", to: "learn#compare", as: :compare
  get "learn/:slug", to: "learn#show", as: :learn
  get "angel-numbers", to: "angel_numbers#index", as: :angel_numbers
  get "angel-numbers/:number", to: "angel_numbers#show", as: :angel_number

  # ===== BUSINESS NAMING =====
  get "business-names", to: "business_names#index", as: :business_names
  get "business-names/style/:style", to: "business_names#by_style", as: :business_names_by_style
  get "business-names/:slug", to: "business_names#show", as: :business_name

  # ===== TEAM NAMES =====
  get "team-names", to: "team_names#index", as: :team_names
  get "team-names/:slug", to: "team_names#show", as: :team_name
  get "group-names", to: "team_names#groups_index", as: :group_names
  get "group-names/:slug", to: "team_names#group_show", as: :group_name

  # ===== SOCIAL MEDIA NAMES =====
  get "instagram-names", to: "platform_names#index", defaults: { platform: "instagram" }, as: :instagram_names
  get "instagram-names/:slug", to: "platform_names#show", defaults: { platform: "instagram" }, as: :instagram_name
  get "tiktok-names", to: "platform_names#index", defaults: { platform: "tiktok" }, as: :tiktok_names
  get "youtube-names", to: "platform_names#index", defaults: { platform: "youtube" }, as: :youtube_names
  get "gaming-names", to: "platform_names#index", defaults: { platform: "gaming" }, as: :gaming_names
  get "discord-names", to: "platform_names#index", defaults: { platform: "discord" }, as: :discord_names

  # ===== SLOGANS / TOOLS / GUIDES / START =====
  get "slogans/:slug", to: "content_pages#show", defaults: { section: "slogans" }, as: :slogan
  get "tools/:slug", to: "content_pages#show", defaults: { section: "tools" }, as: :tool
  get "guides/:slug", to: "content_pages#show", defaults: { section: "guides" }, as: :guide
  get "start/:slug", to: "content_pages#show", defaults: { section: "start" }, as: :start_guide

  # ===== SHARED =====
  get "blog", to: "blog#index", as: :blog
  get "blog/:slug", to: "blog#show", as: :blog_post
  get "about", to: "pages#about"
  get "contact", to: "pages#contact"
  get "write-for-us", to: "pages#write_for_us"
  get "sitemap.xml", to: "sitemaps#index", defaults: { format: :xml }
end
