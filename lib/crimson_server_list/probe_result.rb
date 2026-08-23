# frozen_string_literal: true

module ::CrimsonServerList
  ProbeResult = Struct.new(
    :status,
    :players_online,
    :players_max,
    :version,
    :message,
    :adapter,
    :supports_player_count,
    keyword_init: true,
  )
end
