# frozen_string_literal: true

require "ipaddr"
require "socket"
require "timeout"

module ::CrimsonServerList
  module NetworkPolicy
    class Error < StandardError; end
    class InvalidHost < Error; end
    class BlockedTarget < Error; end
    class PortNotAllowed < Error; end

    Endpoint = Struct.new(:hostname, :ip, :port, :family, keyword_init: true)

    DEFAULT_PORT_RULES = {
      "minecraft" => [20_000..30_000],
      "fivem" => [30_000..30_250],
      "rust" => [27_000..29_000],
      "ark" => [7_000..8_100, 27_000..29_000],
      "silkroad-online" => [15_000..16_500],
      "metin2" => [10_000..14_500],
      "knight-online" => [15_000..16_500],
      "world-of-warcraft" => [3_000..9_000],
    }.freeze

    BLOCKED_SUFFIXES = %w[
      localhost
      local
      internal
      intranet
      home
      lan
      test
      invalid
      example
    ].freeze

    BLOCKED_NETWORKS = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.88.99.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
      ::/128
      ::1/128
      64:ff9b:1::/48
      100::/64
      2001::/23
      2001:db8::/32
      2002::/16
      3fff::/20
      5f00::/16
      fc00::/7
      fe80::/10
      ff00::/8
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    module_function

    def resolve!(host, port:, game_slug:)
      hostname = normalize_host(host)
      raise InvalidHost, "invalid hostname" unless hostname_valid?(hostname)
      raise BlockedTarget, "hostname suffix is blocked" unless hostname_allowed?(hostname)
      raise PortNotAllowed, "query port is not allowed" unless port_allowed?(game_slug, port)

      addresses = resolve_addresses(hostname)
      raise BlockedTarget, "hostname has no address" if addresses.empty?
      raise BlockedTarget, "hostname resolves to a non-public address" unless addresses.all? { |ip| public_ip?(ip) }

      selected = addresses.sort_by { |ip| IPAddr.new(ip).ipv4? ? 0 : 1 }.first
      family = IPAddr.new(selected).ipv4? ? Socket::AF_INET : Socket::AF_INET6

      Endpoint.new(hostname: hostname, ip: selected, port: port.to_i, family: family)
    end

    def normalize_host(host)
      host.to_s.strip.downcase.delete_suffix(".")
    end

    def hostname_valid?(hostname)
      return false if hostname.blank? || hostname.length > 253
      return true if ip_literal?(hostname)

      labels = hostname.split(".")
      return false if labels.length < 2

      labels.all? do |label|
        label.length.between?(1, 63) &&
          label.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i)
      end
    end

    def hostname_allowed?(hostname)
      return false if BLOCKED_SUFFIXES.any? { |suffix| hostname == suffix || hostname.end_with?(".#{suffix}") }
      return false if ip_literal?(hostname) && !public_ip?(hostname)

      allowlist = setting_entries(:crimson_server_list_allowed_host_suffixes)
      return true if allowlist.empty?

      allowlist.any? do |suffix|
        normalized = normalize_host(suffix).delete_prefix(".")
        hostname == normalized || hostname.end_with?(".#{normalized}")
      end
    end

    def port_allowed?(game_slug, port)
      value = Integer(port)
      return false unless value.between?(1, 65_535)

      rules = Array(DEFAULT_PORT_RULES[game_slug]) + extra_port_rules
      rules.any? { |rule| rule.is_a?(Range) ? rule.cover?(value) : rule == value }
    rescue ArgumentError, TypeError
      false
    end

    def public_ip?(value)
      ip = IPAddr.new(value)
      ip = ip.native if ip.ipv4_mapped?
      return false if ip.loopback? || ip.private? || ip.link_local?

      BLOCKED_NETWORKS.none? { |network| network.include?(ip) }
    rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
      false
    end

    def resolve_addresses(hostname)
      return [IPAddr.new(hostname).to_s] if ip_literal?(hostname)

      timeout = [connect_timeout, 1.5].min
      records =
        Timeout.timeout(timeout) do
          Addrinfo.getaddrinfo(hostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM)
        end

      records.filter_map(&:ip_address).uniq
    rescue SocketError, SystemCallError, Timeout::Error
      []
    end

    def connect_timeout
      SiteSetting.crimson_server_list_connect_timeout_ms.to_i.clamp(500, 5_000) / 1000.0
    end

    def read_timeout
      SiteSetting.crimson_server_list_read_timeout_ms.to_i.clamp(500, 5_000) / 1000.0
    end

    def extra_port_rules
      setting_entries(:crimson_server_list_extra_allowed_ports).filter_map do |entry|
        if entry.match?(/\A\d+\z/)
          entry.to_i
        elsif (match = entry.match(/\A(\d+)-(\d+)\z/))
          first = match[1].to_i
          last = match[2].to_i
          first..last if first.between?(1, 65_535) && last.between?(first, 65_535)
        end
      end
    end

    def setting_entries(name)
      SiteSetting.public_send(name).to_s.split("|").map(&:strip).reject(&:blank?)
    end

    def ip_literal?(hostname)
      IPAddr.new(hostname)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
