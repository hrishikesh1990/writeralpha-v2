# frozen_string_literal: true

# /developers: documentation for the Open Gemstone Data API and dataset.
class DevelopersController < ApplicationController
  def show
    @entries = AtlasEntry.all
    @base = AtlasApi.base_url(request)
    @example = @entries.find { |e| e.slug == "amethyst" } || @entries.first
    @meta = {
      title: "Open Gemstone Data: free JSON API and dataset (CC BY 4.0) | WriterAlpha",
      description: "A free, sourced JSON API for #{@entries.size} gemstones: hardness, water, salt and sun safety, toxicity, identification tests and tradition. " \
                   "CC BY 4.0, no API key, CORS enabled."
    }
  end
end
