# Parse the Atlas (data/atlas/stones/*.yml) once at boot in production so the
# first request does not pay for loading 85 files. Elsewhere it loads lazily.
Rails.application.config.after_initialize do
  Atlas.index if Rails.env.production?
end
