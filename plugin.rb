# frozen_string_literal: true

# name: discourse-crimson-server-list
# about: Adds an independent, moderated private game server top list to Discourse.
# version: 2.2.1
# authors: dupless54
# url: https://forum.senin.me/servers
# required_version: 3.3.0

require "set"

enabled_site_setting :crimson_server_list_enabled

register_asset "stylesheets/crimson-server-list.scss"

module ::CrimsonServerList
  PLUGIN_NAME = "discourse-crimson-server-list"
  TAG_LIMIT = 8
  TAG_MAX_LENGTH = 30

  GAME_FIELDS = {
    "minecraft" => [
      { key: "edition", label: "Sürüm türü", type: "text", placeholder: "Java / Bedrock / Crossplay" },
      { key: "server_type", label: "Sunucu türü", type: "text", placeholder: "Survival / SkyBlock / Factions" },
      { key: "difficulty", label: "Zorluk", type: "text", placeholder: "Normal / Hard" },
    ],
    "fivem" => [
      { key: "framework", label: "Framework", type: "text", placeholder: "ESX / QBCore / Standalone" },
      { key: "roleplay_type", label: "Roleplay türü", type: "text", placeholder: "Serious RP / Fun RP" },
      { key: "economy", label: "Ekonomi", type: "text", placeholder: "Hard / Medium / Easy" },
    ],
    "rust" => [
      { key: "gather_rate", label: "Toplama oranı", type: "number", min: 0.1, max: 10_000, step: 0.1, unit: "x" },
      { key: "group_limit", label: "Takım sınırı", type: "number", min: 1, max: 1_000, step: 1, unit: "kişi" },
      { key: "wipe_schedule", label: "Wipe takvimi", type: "text", placeholder: "Haftalık / Aylık" },
      { key: "map_size", label: "Harita boyutu", type: "number", min: 500, max: 20_000, step: 1 },
    ],
    "ark" => [
      { key: "map_name", label: "Harita", type: "text", placeholder: "The Island / Ragnarok" },
      { key: "exp_rate", label: "EXP oranı", type: "number", min: 0.1, max: 100_000, step: 0.1, unit: "x" },
      { key: "tame_rate", label: "Evcilleştirme oranı", type: "number", min: 0.1, max: 100_000, step: 0.1, unit: "x" },
      { key: "harvest_rate", label: "Toplama oranı", type: "number", min: 0.1, max: 100_000, step: 0.1, unit: "x" },
    ],
    "silkroad-online" => [
      { key: "level_cap", label: "Maximum CAP", type: "number", min: 1, max: 1_000, step: 1 },
      { key: "exp_rate", label: "EXP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "sp_rate", label: "SP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "drop_rate", label: "Drop oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "server_type", label: "Sunucu türü", type: "text", placeholder: "Chinese / European / Mixed" },
    ],
    "metin2" => [
      { key: "level_cap", label: "Maximum seviye", type: "number", min: 1, max: 1_000, step: 1 },
      { key: "exp_rate", label: "EXP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "drop_rate", label: "Drop oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "yang_rate", label: "Yang oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "server_type", label: "Sunucu türü", type: "text", placeholder: "Emek / Orta / PvP" },
    ],
    "knight-online" => [
      { key: "level_cap", label: "Maximum seviye", type: "number", min: 1, max: 255, step: 1 },
      { key: "exp_rate", label: "EXP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "drop_rate", label: "Drop oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "national_points_rate", label: "NP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "server_type", label: "Sunucu türü", type: "text", placeholder: "Farm / PK / MYKO" },
    ],
    "world-of-warcraft" => [
      { key: "expansion", label: "Genişleme paketi", type: "text", placeholder: "WotLK / Cataclysm / Legion" },
      { key: "level_cap", label: "Maximum seviye", type: "number", min: 1, max: 255, step: 1 },
      { key: "exp_rate", label: "EXP oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "drop_rate", label: "Drop oranı", type: "number", min: 0.1, max: 1_000_000, step: 0.1, unit: "x" },
      { key: "realm_type", label: "Realm türü", type: "text", placeholder: "PvE / PvP / RP" },
    ],
  }.freeze

  GAMES = [
    { slug: "minecraft", name: "Minecraft", icon: "⛏️", accent: "#57f287", fields: GAME_FIELDS["minecraft"] },
    { slug: "fivem", name: "FiveM", icon: "🚓", accent: "#5d8cff", fields: GAME_FIELDS["fivem"] },
    { slug: "rust", name: "Rust", icon: "☢️", accent: "#f07b4f", fields: GAME_FIELDS["rust"] },
    { slug: "ark", name: "ARK", icon: "🦖", accent: "#36c7b4", fields: GAME_FIELDS["ark"] },
    { slug: "silkroad-online", name: "Silkroad Online", icon: "🐫", accent: "#d8a657", fields: GAME_FIELDS["silkroad-online"] },
    { slug: "metin2", name: "Metin2", icon: "⚔️", accent: "#db5f78", fields: GAME_FIELDS["metin2"] },
    { slug: "knight-online", name: "Knight Online", icon: "🛡️", accent: "#b89cff", fields: GAME_FIELDS["knight-online"] },
    { slug: "world-of-warcraft", name: "World of Warcraft", icon: "🐲", accent: "#f3c969", fields: GAME_FIELDS["world-of-warcraft"] },
  ].freeze

  GAME_SLUGS = GAMES.map { |game| game[:slug] }.freeze
  GAME_DETAIL_KEYS = GAME_FIELDS.values.flatten.map { |field| field[:key] }.uniq.freeze

  def self.game(slug)
    GAMES.find { |game| game[:slug] == slug }
  end

  def self.game_fields(slug)
    GAME_FIELDS.fetch(slug.to_s, [])
  end

  def self.normalize_tag(value)
    Slug.for(value.to_s.strip).to_s.first(TAG_MAX_LENGTH).presence
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
  require_relative "app/models/crimson_server_list/claim_request"
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
      delete "/crimson-server-list/servers/:id" => "crimson_server_list/servers#destroy"
      post "/crimson-server-list/servers/:id/vote" => "crimson_server_list/servers#vote"
      post "/crimson-server-list/servers/:id/refresh" => "crimson_server_list/servers#refresh"
      post "/crimson-server-list/servers/:id/claim" => "crimson_server_list/servers#request_claim"
      put "/crimson-server-list/servers/:id/review" => "crimson_server_list/servers#upsert_review"
      delete "/crimson-server-list/servers/:id/review" => "crimson_server_list/servers#destroy_review"
      put "/crimson-server-list/admin/servers/:id" => "crimson_server_list/servers#update"
      put "/crimson-server-list/admin/claims/:id" => "crimson_server_list/servers#review_claim"
    end
  end
end
