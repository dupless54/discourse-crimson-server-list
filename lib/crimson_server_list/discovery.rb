# frozen_string_literal: true

module ::CrimsonServerList
  class Discovery
    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 50
    MAX_PAGE = 200
    MAX_QUERY_LENGTH = 80
    SORT_MODES = %w[top new players rating online].freeze

    def initialize(params)
      @params = params
    end

    def call
      filters = normalized_filters
      scope = CrimsonServerList::Server.publicly_visible
      scope = scope.where(game_slug: filters[:game]) if filters[:game]
      scope = scope.where(status: filters[:status]) if filters[:status]
      scope = scope.where.not(verified_at: nil) if filters[:verified] == true
      scope = scope.where(verified_at: nil) if filters[:verified] == false
      scope = filter_tag(scope, filters[:tag]) if filters[:tag]
      scope = filter_query(scope, filters[:q]) if filters[:q]

      total = scope.count
      records =
        order_scope(scope, filters[:sort])
          .includes(:owner)
          .offset((filters[:page] - 1) * filters[:per_page])
          .limit(filters[:per_page])
          .to_a

      {
        records: records,
        total: total,
        page: filters[:page],
        per_page: filters[:per_page],
        total_pages: total.zero? ? 0 : (total.to_f / filters[:per_page]).ceil,
        has_more: filters[:page] * filters[:per_page] < total,
        filters: filters.except(:page, :per_page),
      }
    end

    private

    def normalized_filters
      {
        game: normalized_game,
        tag: normalized_tag,
        status: normalized_status,
        verified: normalized_verified,
        q: normalized_query,
        sort: normalized_sort,
        page: normalized_page,
        per_page: normalized_per_page,
      }
    end

    def normalized_game
      value = @params[:game].to_s
      CrimsonServerList::GAME_SLUGS.include?(value) ? value : nil
    end

    def normalized_tag
      value = CrimsonServerList.normalize_tag(@params[:tag])
      value if value.present?
    end

    def normalized_status
      value = @params[:status].to_s
      CrimsonServerList::Server::STATUSES.include?(value) ? value : nil
    end

    def normalized_verified
      case @params[:verified].to_s.downcase
      when "1", "true", "yes"
        true
      when "0", "false", "no"
        false
      end
    end

    def normalized_query
      @params[:q].to_s.strip.first(MAX_QUERY_LENGTH).presence
    end

    def normalized_sort
      value = @params[:sort].to_s
      SORT_MODES.include?(value) ? value : "top"
    end

    def normalized_page
      @params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end

    def normalized_per_page
      value = @params[:per_page].to_s.to_i
      value = DEFAULT_PER_PAGE if value <= 0
      value.clamp(1, MAX_PER_PAGE)
    end

    def filter_tag(scope, tag)
      scope.where("crimson_game_servers.tags @> ?::jsonb", [tag].to_json)
    end

    def filter_query(scope, query)
      escaped = ActiveRecord::Base.sanitize_sql_like(query)
      pattern = "%#{escaped}%"
      scope.where(
        <<~SQL.squish,
          crimson_game_servers.name ILIKE :pattern OR
          crimson_game_servers.short_description ILIKE :pattern OR
          crimson_game_servers.mode ILIKE :pattern OR
          crimson_game_servers.version ILIKE :pattern OR
          crimson_game_servers.language ILIKE :pattern OR
          crimson_game_servers.tags::text ILIKE :pattern
        SQL
        pattern: pattern,
      )
    end

    def order_scope(scope, sort)
      case sort
      when "new"
        scope.order(created_at: :desc, id: :desc)
      when "players"
        scope.order(
          Arel.sql("CASE WHEN crimson_game_servers.status = 'online' THEN 0 ELSE 1 END ASC"),
          players_online: :desc,
          vote_count: :desc,
          id: :desc,
        )
      when "rating"
        scope.order(
          Arel.sql(
            "CASE WHEN crimson_game_servers.review_count > 0 " \
              "THEN crimson_game_servers.rating_sum::float / crimson_game_servers.review_count ELSE 0 END DESC",
          ),
          review_count: :desc,
          vote_count: :desc,
          id: :desc,
        )
      when "online"
        scope.order(
          Arel.sql("CASE WHEN crimson_game_servers.status = 'online' THEN 0 ELSE 1 END ASC"),
          vote_count: :desc,
          players_online: :desc,
          id: :desc,
        )
      else
        scope.order(
          featured: :desc,
          vote_count: :desc,
          players_online: :desc,
          created_at: :desc,
          id: :desc,
        )
      end
    end
  end
end
