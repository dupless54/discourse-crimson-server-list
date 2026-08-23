# frozen_string_literal: true

# name: discourse-crimson-server-list
# about: Adds an independent, moderated private game server top list to Discourse.
# version: 2.0.0
# authors: TSKEliteForces
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
  require_relative "lib/crimson_server_list/network_policy"
  require_relative "lib/crimson_server_list/probe_result"
  require_relative "lib/crimson_server_list/adapters"
  require_relative "lib/crimson_server_list/probe_service"
  require_relative "app/models/crimson_server_list/server"
  require_relative "app/models/crimson_server_list/vote"
  require_relative "app/models/crimson_server_list/review"
  require_relative "app/controllers/crimson_server_list/servers_controller"
  require_relative "app/jobs/regular/crimson_server_list_probe"
  require_relative "app/jobs/scheduled/crimson_server_list_refresh"

  Discourse::Application.routes.append do
    # Public Ember pages still need a Rails route for direct visits and hard
    # refreshes in production. ListController renders the normal Discourse
    # application shell; the Ember `servers` route takes over in the browser.
    get "/servers" => "list#latest"
    get "/servers/:slug" => "list#latest", constraints: { slug: /[a-z0-9\-]+/ }

    defaults format: :json do
      get "/crimson-server-list" => "crimson_server_list/servers#index"
      get "/crimson-server-list/servers/:slug" => "crimson_server_list/servers#show"
      post "/crimson-server-list/servers" => "crimson_server_list/servers#create"
      put "/crimson-server-list/servers/:id" => "crimson_server_list/servers#update_owned"
      post "/crimson-server-list/servers/:id/vote" => "crimson_server_list/servers#vote"
      post "/crimson-server-list/servers/:id/refresh" => "crimson_server_list/servers#refresh"
      put "/crimson-server-list/servers/:id/review" => "crimson_server_list/servers#upsert_review"
      delete "/crimson-server-list/servers/:id/review" => "crimson_server_list/servers#destroy_review"
      put "/crimson-server-list/admin/servers/:id" => "crimson_server_list/servers#update"
    end
  end
end
