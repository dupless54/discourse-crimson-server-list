# frozen_string_literal: true

# name: discourse-crimson-server-list
# about: Adds an independent, moderated private game server top list to Discourse.
# version: 1.0.1
# authors: ErespawN
# url: https://forum.senin.me/servers
# required_version: 3.3.0

require "set"

enabled_site_setting :crimson_server_list_enabled

register_asset "stylesheets/crimson-server-list.scss"

module ::CrimsonServerList
  PLUGIN_NAME = "discourse-crimson-server-list"

  GAMES = [
    { slug: "minecraft", name: "Minecraft", icon: "⛏️", accent: "#57f287" },
    { slug: "fivem", name: "FiveM", icon: "🚓", accent: "#5d8cff" },
    { slug: "rust", name: "Rust", icon: "☢️", accent: "#f07b4f" },
    { slug: "ark", name: "ARK", icon: "🦖", accent: "#36c7b4" },
    { slug: "silkroad-online", name: "Silkroad Online", icon: "🐫", accent: "#d8a657" },
    { slug: "metin2", name: "Metin2", icon: "⚔️", accent: "#db5f78" },
    { slug: "knight-online", name: "Knight Online", icon: "🛡️", accent: "#b89cff" },
    { slug: "world-of-warcraft", name: "World of Warcraft", icon: "🐲", accent: "#f3c969" },
  ].freeze

  GAME_SLUGS = GAMES.map { |game| game[:slug] }.freeze

  def self.game(slug)
    GAMES.find { |game| game[:slug] == slug }
  end
end

after_initialize do
  require_relative "app/models/crimson_server_list/server"
  require_relative "app/models/crimson_server_list/vote"
  require_relative "app/controllers/crimson_server_list/servers_controller"

  Discourse::Application.routes.append do
    # Public Ember pages still need a Rails route for direct visits and hard
    # refreshes in production. ListController renders the normal Discourse
    # application shell; the Ember `servers` route takes over in the browser.
    get "/servers" => "list#latest"

    defaults format: :json do
      get "/crimson-server-list" => "crimson_server_list/servers#index"
      post "/crimson-server-list/servers" => "crimson_server_list/servers#create"
      post "/crimson-server-list/servers/:id/vote" => "crimson_server_list/servers#vote"
      put "/crimson-server-list/admin/servers/:id" => "crimson_server_list/servers#update"
    end
  end
end
