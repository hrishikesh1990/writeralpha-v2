module Admin
  class BaseController < ApplicationController
    layout "admin"
    http_basic_authenticate_with(
      name: ENV.fetch("ADMIN_USER", "admin"),
      password: ENV.fetch("ADMIN_PASSWORD", "changeme"),
      realm: "Writer Alpha Admin"
    ) if Rails.env.production?
  end
end
