# frozen_string_literal: true

require "active_support/security_utils"
require "digest"
require "ipaddr"
require "resolv"
require "securerandom"
require "timeout"

module ::CrimsonServerList
  class VerificationService
    class Error < StandardError; end
    class NotEligible < Error; end
    class ChallengeMissing < Error; end
    class ChallengeExpired < Error; end
    class VerificationFailed < Error; end
    class LookupFailed < Error; end

    RECORD_LABEL = "_crimson-server-list"
    VALUE_PREFIX = "crimson-server-list="
    DNS_TIMEOUT_SECONDS = 3
    MAX_TXT_RECORDS = 20
    MAX_TXT_BYTES = 512

    def self.eligible?(server)
      host = normalized_host(server)
      return false if host.blank?
      return false unless CrimsonServerList::NetworkPolicy.hostname_valid?(host)
      return false unless CrimsonServerList::NetworkPolicy.hostname_allowed?(host)
      return false if ip_literal?(host)

      true
    end

    def self.record_name(server)
      return nil unless eligible?(server)

      "#{RECORD_LABEL}.#{normalized_host(server)}"
    end

    def self.start!(server)
      raise NotEligible unless eligible?(server)

      token = SecureRandom.urlsafe_base64(24)
      record_value = "#{VALUE_PREFIX}#{token}"
      now = Time.zone.now
      expires_at = now + challenge_hours.hours

      server.update_columns(
        verified_at: nil,
        verification_method: nil,
        verification_token_digest: digest(record_value),
        verification_requested_at: now,
        verification_expires_at: expires_at,
        updated_at: now,
      )

      {
        record_type: "TXT",
        record_name: record_name(server),
        record_value: record_value,
        expires_at: expires_at.iso8601,
      }
    end

    def self.verify!(server)
      raise NotEligible unless eligible?(server)
      raise ChallengeMissing if server.verification_token_digest.blank? || server.verification_expires_at.blank?
      raise ChallengeExpired unless server.verification_expires_at.future?

      expected_digest = server.verification_token_digest
      matched =
        lookup_txt_values(record_name(server)).any? do |value|
          candidate = digest(value)
          ActiveSupport::SecurityUtils.secure_compare(candidate, expected_digest)
        end
      raise VerificationFailed unless matched

      now = Time.zone.now
      server.update_columns(
        verified_at: now,
        verification_method: "dns_txt",
        verification_token_digest: nil,
        verification_requested_at: nil,
        verification_expires_at: nil,
        updated_at: now,
      )

      server.reload
    end

    def self.pending?(server)
      server.verification_token_digest.present? && server.verification_expires_at.present? &&
        server.verification_expires_at.future?
    end

    def self.challenge_hours
      SiteSetting.crimson_server_list_verification_challenge_hours.to_i.clamp(1, 168)
    end

    def self.normalized_host(server)
      CrimsonServerList::NetworkPolicy.normalize_host(server.host).to_s.downcase.chomp(".")
    end
    private_class_method :normalized_host

    def self.ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
    private_class_method :ip_literal?

    def self.digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end
    private_class_method :digest

    def self.lookup_txt_values(name)
      resolver = Resolv::DNS.new
      resolver.timeouts = [DNS_TIMEOUT_SECONDS]
      resources = resolver.getresources(name, Resolv::DNS::Resource::IN::TXT).first(MAX_TXT_RECORDS)

      resources.filter_map do |resource|
        value = resource.strings.join
        next if value.bytesize > MAX_TXT_BYTES

        value
      end
    rescue Resolv::ResolvError, IOError, SystemCallError, Timeout::Error
      raise LookupFailed
    ensure
      resolver&.close
    end
    private_class_method :lookup_txt_values
  end
end
