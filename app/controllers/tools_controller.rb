class ToolsController < ApplicationController
  def index
    @meta = { title: "Free Crystal & Gemstone Tools — Finder, Safety Checker, Birthstone Calculator",
              description: "Free interactive gemstone tools: find your stone, check water and sun safety, test if a crystal is real, check pairings, calculate birthstones and plan moon cleansing." }
  end
end
