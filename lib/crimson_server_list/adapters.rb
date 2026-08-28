# frozen_string_literal: true

require "json"
require "socket"

module ::CrimsonServerList
  module Adapters
    class ProbeError < StandardError; end

    class Base
      MAX_RESPONSE_BYTES = 65_536

      def initialize(server:, endpoint:, connect_timeout:, read_timeout:)
        @server = server
        @endpoint = endpoint
        @connect_timeout = connect_timeout
        @read_timeout = read_timeout
      end

      private

      attr_reader :server, :endpoint, :connect_timeout, :read_timeout

      def tcp_socket
        Socket.tcp(endpoint.ip, endpoint.port, connect_timeout: connect_timeout)
      end

      def read_exact(socket, length)
        raise ProbeError, "response is too large" if length.negative? || length > MAX_RESPONSE_BYTES

        buffer = +"".b
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + read_timeout

        while buffer.bytesize < length
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise Timeout::Error, "read timeout" if remaining <= 0
          raise Timeout::Error, "read timeout" unless IO.select([socket], nil, nil, remaining)

          chunk = socket.readpartial([length - buffer.bytesize, 16_384].min)
          buffer << chunk
        end

        buffer
      rescue EOFError
        raise ProbeError, "truncated response"
      end

      def read_to_eof(socket)
        buffer = +"".b
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + read_timeout

        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise Timeout::Error, "read timeout" if remaining <= 0
          break unless IO.select([socket], nil, nil, remaining)

          chunk = socket.read_nonblock(16_384, exception: false)
          break if chunk.nil?
          next if chunk == :wait_readable

          buffer << chunk
          raise ProbeError, "response is too large" if buffer.bytesize > MAX_RESPONSE_BYTES
        end

        buffer
      end

      def text(value)
        value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
      end
    end

    class Minecraft < Base
      def call
        socket = tcp_socket
        handshake = encode_varint(-1) + encode_string(endpoint.hostname) + [server.port].pack("n") + encode_varint(1)
        write_packet(socket, encode_varint(0) + handshake)
        write_packet(socket, encode_varint(0))

        packet_length = read_varint(socket)
        payload = read_exact(socket, packet_length)
        packet_id, offset = decode_varint(payload, 0)
        raise ProbeError, "unexpected Minecraft packet" if packet_id.nonzero?

        json_length, offset = decode_varint(payload, offset)
        json_payload = payload.byteslice(offset, json_length)
        raise ProbeError, "truncated Minecraft JSON" unless json_payload&.bytesize == json_length
        document = JSON.parse(json_payload)
        players = document.fetch("players", {})

        ProbeResult.new(
          status: "online",
          players_online: players.fetch("online", 0).to_i,
          players_max: players.fetch("max", 0).to_i,
          version: document.dig("version", "name"),
          message: "Minecraft Java status",
          adapter: "minecraft-java",
          supports_player_count: true,
        )
      ensure
        socket&.close
      end

      private

      def encode_string(value)
        bytes = value.to_s.b
        encode_varint(bytes.bytesize) + bytes
      end

      def encode_varint(value)
        unsigned = value.to_i & 0xffff_ffff
        bytes = +"".b

        loop do
          byte = unsigned & 0x7f
          unsigned >>= 7
          byte |= 0x80 if unsigned.nonzero?
          bytes << byte
          break if unsigned.zero?
        end

        bytes
      end

      def write_packet(socket, payload)
        socket.write(encode_varint(payload.bytesize) + payload)
      end

      def read_varint(socket)
        value = 0
        5.times do |index|
          byte = read_exact(socket, 1).getbyte(0)
          value |= (byte & 0x7f) << (7 * index)
          return value if (byte & 0x80).zero?
        end
        raise ProbeError, "invalid varint"
      end

      def decode_varint(data, offset)
        value = 0
        5.times do |index|
          byte = data.getbyte(offset + index)
          raise ProbeError, "truncated varint" if byte.nil?
          value |= (byte & 0x7f) << (7 * index)
          return [value, offset + index + 1] if (byte & 0x80).zero?
        end
        raise ProbeError, "invalid varint"
      end
    end

    class FiveM < Base
      def call
        dynamic = fetch_json("/dynamic.json")
        online = integer_value(dynamic["clients"] || dynamic["players"])
        maximum = integer_value(dynamic["sv_maxclients"] || dynamic["maxclients"])

        if online.nil?
          players = fetch_json("/players.json")
          online = players.is_a?(Array) ? players.length : 0
        end

        ProbeResult.new(
          status: "online",
          players_online: online.to_i,
          players_max: maximum.to_i,
          version: dynamic["iv"]&.to_s,
          message: [dynamic["gametype"], dynamic["mapname"]].compact.join(" · ").first(120),
          adapter: "fivem-http",
          supports_player_count: true,
        )
      end

      private

      def fetch_json(path)
        socket = tcp_socket
        request =
          "GET #{path} HTTP/1.1\r\n" \
            "Host: #{endpoint.hostname}:#{endpoint.port}\r\n" \
            "Accept: application/json\r\n" \
            "User-Agent: CrimsonServerList/2.0\r\n" \
            "Connection: close\r\n\r\n"
        socket.write(request)
        response = read_to_eof(socket)
        headers, body = response.split("\r\n\r\n", 2)
        header_lines = headers.to_s.split("\r\n")
        status = header_lines.shift.to_s.split[1].to_i
        raise ProbeError, "FiveM HTTP #{status}" unless status == 200 && body.present?

        parsed_headers =
          header_lines.each_with_object({}) do |line, result|
            key, value = line.split(":", 2)
            result[key.to_s.downcase] = value.to_s.strip if value
          end

        if parsed_headers["transfer-encoding"].to_s.downcase.include?("chunked")
          body = decode_chunked(body)
        elsif parsed_headers["content-length"].present?
          length = Integer(parsed_headers["content-length"])
          raise ProbeError, "response is too large" if length > MAX_RESPONSE_BYTES
          raise ProbeError, "truncated HTTP response" if body.bytesize < length
          body = body.byteslice(0, length)
        end

        JSON.parse(body)
      ensure
        socket&.close
      end

      def decode_chunked(body)
        output = +"".b
        offset = 0

        loop do
          line_end = body.index("\r\n", offset)
          raise ProbeError, "invalid chunked response" unless line_end

          token = body.byteslice(offset, line_end - offset).to_s.split(";", 2).first
          size = Integer(token, 16)
          return output if size.zero?

          chunk_start = line_end + 2
          chunk_end = chunk_start + size
          raise ProbeError, "truncated chunked response" if chunk_end + 2 > body.bytesize
          raise ProbeError, "invalid chunk terminator" unless body.byteslice(chunk_end, 2) == "\r\n"

          output << body.byteslice(chunk_start, size)
          raise ProbeError, "response is too large" if output.bytesize > MAX_RESPONSE_BYTES
          offset = chunk_end + 2
        end
      rescue ArgumentError
        raise ProbeError, "invalid chunk size"
      end

      def integer_value(value)
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end
    end

    class SteamA2S < Base
      INFO_QUERY = "\xFF\xFF\xFF\xFFTSource Engine Query\x00".b

      def call
        socket = UDPSocket.new(endpoint.family)
        socket.connect(endpoint.ip, endpoint.port)
        packet = query(socket, INFO_QUERY)

        if packet.getbyte(4) == 0x41
          challenge = packet.byteslice(5, 4)
          raise ProbeError, "invalid A2S challenge" unless challenge&.bytesize == 4
          packet = query(socket, INFO_QUERY + challenge)
        end

        raise ProbeError, "split A2S packets are not supported" if packet.byteslice(0, 4) == "\xFE\xFF\xFF\xFF".b
        raise ProbeError, "invalid A2S response" unless packet.byteslice(0, 4) == "\xFF\xFF\xFF\xFF".b
        raise ProbeError, "unexpected A2S packet" unless packet.getbyte(4) == 0x49

        offset = 6
        name, offset = read_cstring(packet, offset)
        _map, offset = read_cstring(packet, offset)
        _folder, offset = read_cstring(packet, offset)
        _game, offset = read_cstring(packet, offset)
        offset += 2
        raise ProbeError, "truncated A2S player fields" if packet.bytesize < offset + 2
        players_online = packet.getbyte(offset).to_i
        players_max = packet.getbyte(offset + 1).to_i

        ProbeResult.new(
          status: "online",
          players_online: players_online,
          players_max: players_max,
          message: text(name).first(120),
          adapter: server.game_slug == "rust" ? "rust-a2s" : "ark-a2s",
          supports_player_count: true,
        )
      ensure
        socket&.close
      end

      private

      def query(socket, payload)
        socket.send(payload, 0)
        raise Timeout::Error, "UDP read timeout" unless IO.select([socket], nil, nil, read_timeout)
        socket.recv(MAX_RESPONSE_BYTES)
      end

      def read_cstring(packet, offset)
        ending = packet.index("\x00".b, offset)
        raise ProbeError, "truncated A2S string" unless ending
        [packet.byteslice(offset, ending - offset), ending + 1]
      end
    end

    class TcpReachability < Base
      ADAPTER_NAME = "tcp-reachability"

      def call
        socket = tcp_socket
        ProbeResult.new(
          status: "online",
          players_online: 0,
          players_max: 0,
          message: "TCP port reachable",
          adapter: self.class::ADAPTER_NAME,
          supports_player_count: false,
        )
      ensure
        socket&.close
      end
    end

    class SilkroadOnline < TcpReachability
      ADAPTER_NAME = "silkroad-tcp"
    end

    class Metin2 < TcpReachability
      ADAPTER_NAME = "metin2-tcp"
    end

    class KnightOnline < TcpReachability
      ADAPTER_NAME = "knight-online-tcp"
    end

    class WorldOfWarcraft < TcpReachability
      ADAPTER_NAME = "wow-realm-tcp"
    end

    REGISTRY = {
      "minecraft" => Minecraft,
      "fivem" => FiveM,
      "rust" => SteamA2S,
      "ark" => SteamA2S,
      "silkroad-online" => SilkroadOnline,
      "metin2" => Metin2,
      "knight-online" => KnightOnline,
      "world-of-warcraft" => WorldOfWarcraft,
    }.freeze

    module_function

    def for(game_slug)
      REGISTRY.fetch(game_slug) { raise ProbeError, "unsupported game adapter" }
    end
  end
end
