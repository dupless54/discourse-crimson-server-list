# frozen_string_literal: true

require "uri"

module ::CrimsonServerList
  class Server < ActiveRecord::Base
    self.table_name = "crimson_game_servers"

    STATUSES = %w[unknown online offline maintenance].freeze
    VERIFICATION_METHODS = %w[dns_txt].freeze

    belongs_to :owner, class_name: "::User", optional: false
    has_many :votes,
             class_name: "::CrimsonServerList::Vote",
             dependent: :destroy,
             inverse_of: :server
    has_many :reviews,
             class_name: "::CrimsonServerList::Review",
             dependent: :destroy,
             inverse_of: :server
    has_many :claim_requests,
             class_name: "::CrimsonServerList::ClaimRequest",
             dependent: :destroy,
             inverse_of: :server
    has_many :reports,
             class_name: "::CrimsonServerList::Report",
             dependent: :destroy,
             inverse_of: :server
    has_many :uptime_samples,
             class_name: "::CrimsonServerList::UptimeSample",
             dependent: :delete_all,
             inverse_of: :server

    before_validation :reset_verification_if_identity_changed
    before_validation :ensure_slug
    before_validation :normalize_tags

    validates :game_slug, inclusion: { in: CrimsonServerList::GAME_SLUGS }
    validates :owner_id, presence: true
    validates :name, presence: true, length: { maximum: 100 }
    validates :slug, presence: true, uniqueness: true, length: { maximum: 120 }
    validates :short_description, presence: true, length: { maximum: 180 }
    validates :description, length: { maximum: 4000 }, allow_blank: true
    validates :host,
              presence: true,
              length: { maximum: 255 },
              format: {
                with: /\A[a-z0-9][a-z0-9.\-:]*\z/i,
                message: :invalid,
              }
    validates :port,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: 65_535,
              }
    validates :query_port,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: 65_535,
              },
              allow_nil: true
    validates :status, inclusion: { in: STATUSES }
    validates :players_online,
              :players_max,
              :vote_count,
              :review_count,
              :rating_sum,
              :view_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              }
    validates :country_code, length: { maximum: 2 }, allow_blank: true
    validates :language, :version, :mode, length: { maximum: 60 }, allow_blank: true
    validates :verification_method, inclusion: { in: VERIFICATION_METHODS }, allow_nil: true
    validates :verification_token_digest, length: { is: 64 }, allow_nil: true
    validate :players_are_consistent
    validate :external_urls_are_safe
    validate :host_is_allowed
    validate :query_endpoint_is_allowed
    validate :game_details_are_valid
    validate :tags_are_valid

    scope :publicly_visible, -> { where(approved: true, enabled: true) }

    def effective_query_port
      query_port.presence || port
    end

    def average_rating
      return 0.0 if review_count.to_i.zero?

      (rating_sum.to_f / review_count.to_i).round(1)
    end

    def verified?
      verified_at.present?
    end

    private

    def reset_verification_if_identity_changed
      return unless new_record? || will_save_change_to_host? || will_save_change_to_owner_id?

      self.verified_at = nil
      self.verification_method = nil
      self.verification_token_digest = nil
      self.verification_requested_at = nil
      self.verification_expires_at = nil
    end

    def ensure_slug
      return if name.blank?

      base = Slug.for(name).presence || SecureRandom.hex(4)
      candidate = base
      suffix = 2

      while self.class.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      self.slug = candidate
    end

    def players_are_consistent
      return if players_max.to_i.zero? || players_online.to_i <= players_max.to_i

      errors.add(:players_online, :less_than_or_equal_to, count: players_max)
    end

    def external_urls_are_safe
      %i[website_url discord_url banner_url].each do |attribute|
        next unless new_record? || will_save_change_to_attribute?(attribute)

        value = public_send(attribute).to_s.strip
        next if value.blank?

        begin
          uri = URI.parse(value)
          valid =
            %w[http https].include?(uri.scheme&.downcase) && uri.host.present? &&
              uri.userinfo.blank?
          errors.add(attribute, :invalid) unless valid
        rescue URI::InvalidURIError
          errors.add(attribute, :invalid)
        end
      end
    end

    def query_endpoint_is_allowed
      endpoint_changed =
        new_record? || will_save_change_to_game_slug? || will_save_change_to_host? ||
          will_save_change_to_port? || will_save_change_to_query_port?
      return unless endpoint_changed
      return if game_slug.blank? || effective_query_port.blank?
      return if CrimsonServerList::NetworkPolicy.port_allowed?(game_slug, effective_query_port)

      errors.add(:query_port, :invalid)
    end

    def host_is_allowed
      return unless new_record? || will_save_change_to_host?

      normalized = CrimsonServerList::NetworkPolicy.normalize_host(host)
      return if CrimsonServerList::NetworkPolicy.hostname_valid?(normalized) &&
        CrimsonServerList::NetworkPolicy.hostname_allowed?(normalized)

      errors.add(:host, :invalid)
    end

    def game_details_are_valid
      values = game_details.respond_to?(:to_h) ? game_details.to_h : {}
      fields = CrimsonServerList.game_fields(game_slug)
      allowed = fields.index_by { |field| field[:key] }

      values.each do |key, value|
        field = allowed[key.to_s]
        unless field
          errors.add(:game_details, :invalid)
          next
        end

        text = value.to_s.strip
        next if text.blank?

        if field[:type] == "number"
          begin
            number = Float(text)
            valid = number.finite?
            valid &&= number >= field[:min].to_f if field.key?(:min)
            valid &&= number <= field[:max].to_f if field.key?(:max)
            errors.add(:game_details, :invalid) unless valid
          rescue ArgumentError, TypeError
            errors.add(:game_details, :invalid)
          end
        elsif text.length > 100
          errors.add(:game_details, :too_long, count: 100)
        end
      end
    end

    def normalize_tags
      source = tags.is_a?(Array) ? tags : tags.to_s.split(/[\n,]/)
      self.tags =
        source
          .filter_map { |value| CrimsonServerList.normalize_tag(value) }
          .uniq
          .first(CrimsonServerList::TAG_LIMIT)
    end

    def tags_are_valid
      unless tags.is_a?(Array) && tags.length <= CrimsonServerList::TAG_LIMIT
        errors.add(:tags, :invalid)
        return
      end

      tags.each do |tag|
        unless tag.is_a?(String) && tag.length.between?(1, CrimsonServerList::TAG_MAX_LENGTH) &&
                 tag.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
          errors.add(:tags, :invalid)
          break
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: crimson_game_servers
#
#  id                        :bigint           not null, primary key
#  approved                  :boolean          default(FALSE), not null
#  banner_url                :string
#  country_code              :string(2)
#  description               :text
#  discord_url               :string
#  enabled                   :boolean          default(TRUE), not null
#  featured                  :boolean          default(FALSE), not null
#  game_details              :jsonb            not null
#  game_slug                 :string(60)       not null
#  host                      :string           not null
#  language                  :string(60)
#  last_checked_at           :datetime
#  last_query_error          :string(500)
#  last_response_ms          :integer
#  mode                      :string(60)
#  monitoring_enabled        :boolean          default(TRUE), not null
#  name                      :string(100)      not null
#  players_max               :integer          default(0), not null
#  players_online            :integer          default(0), not null
#  port                      :integer          not null
#  query_port                :integer
#  rating_sum                :integer          default(0), not null
#  review_count              :integer          default(0), not null
#  short_description         :string(180)      not null
#  slug                      :string(120)      not null
#  status                    :string(20)       default("unknown"), not null
#  tags                      :jsonb            not null
#  verification_expires_at   :datetime
#  verification_method       :string(20)
#  verification_requested_at :datetime
#  verification_token_digest :string(64)
#  verified_at               :datetime
#  version                   :string(60)
#  view_count                :bigint           default(0), not null
#  vote_count                :integer          default(0), not null
#  website_url               :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  owner_id                  :integer
#
# Indexes
#
#  idx_crimson_servers_live_monitoring                    (approved,enabled,monitoring_enabled)
#  index_crimson_game_servers_on_approved_and_enabled     (approved,enabled)
#  index_crimson_game_servers_on_featured_and_vote_count  (featured,vote_count)
#  index_crimson_game_servers_on_game_slug                (game_slug)
#  index_crimson_game_servers_on_owner_id                 (owner_id)
#  index_crimson_game_servers_on_slug                     (slug) UNIQUE
#  index_crimson_game_servers_on_tags                     (tags) USING gin
#  index_crimson_game_servers_on_verified_at              (verified_at)
#
