# frozen_string_literal: true

require "uri"

module ::CrimsonServerList
  class Server < ActiveRecord::Base
    self.table_name = "crimson_game_servers"

    STATUSES = %w[unknown online offline maintenance].freeze

    belongs_to :owner, class_name: "::User", optional: true
    has_many :votes,
             class_name: "::CrimsonServerList::Vote",
             dependent: :destroy,
             inverse_of: :server

    before_validation :ensure_slug

    validates :game_slug, inclusion: { in: CrimsonServerList::GAME_SLUGS }
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
    validates :status, inclusion: { in: STATUSES }
    validates :players_online,
              :players_max,
              :vote_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              }
    validates :country_code, length: { maximum: 2 }, allow_blank: true
    validates :language, :version, :mode, length: { maximum: 60 }, allow_blank: true
    validate :players_are_consistent
    validate :external_urls_are_safe

    scope :publicly_visible, -> { where(approved: true, enabled: true) }

    private

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
        value = public_send(attribute).to_s.strip
        next if value.blank?

        begin
          uri = URI.parse(value)
          valid = %w[http https].include?(uri.scheme&.downcase) && uri.host.present?
          errors.add(attribute, :invalid) unless valid
        rescue URI::InvalidURIError
          errors.add(attribute, :invalid)
        end
      end
    end
  end
end
