import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CrimsonServerFeaturedStrip from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-featured-strip";

module("Integration | Component | crimson-server-featured-strip", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only featured servers and limits the strip to two", async function (assert) {
    this.set("servers", [
      {
        id: 1,
        featured: true,
        name: "CrimsonCraft",
        short_description: "Featured Minecraft community",
        detail_url: "/servers/crimsoncraft",
        game_slug: "minecraft",
        game: { icon: "⛏️", name: "Minecraft" },
        status: "online",
        supports_player_count: true,
        players_online: 128,
        players_max: 300,
        average_rating: 4.8,
        review_count: 20,
        verified: true,
      },
      {
        id: 2,
        featured: true,
        name: "RustEmpire",
        short_description: "Featured Rust community",
        detail_url: "/servers/rustempire",
        game_slug: "rust",
        game: { icon: "☢️", name: "Rust" },
        status: "online",
        supports_player_count: true,
        players_online: 156,
        players_max: 250,
        average_rating: 4.7,
        review_count: 17,
        verified: false,
      },
      {
        id: 3,
        featured: true,
        name: "Third Featured",
        short_description: "Should not be shown in the compact strip",
        detail_url: "/servers/third",
        game_slug: "ark",
        game: { icon: "🦖", name: "ARK" },
        status: "online",
        supports_player_count: true,
        players_online: 10,
        players_max: 20,
        average_rating: 4.5,
        review_count: 4,
        verified: false,
      },
      {
        id: 4,
        featured: false,
        name: "Regular Server",
        short_description: "Regular listing",
        detail_url: "/servers/regular",
        game_slug: "fivem",
        game: { icon: "🚓", name: "FiveM" },
        status: "online",
        supports_player_count: true,
        players_online: 12,
        players_max: 30,
        average_rating: 4.0,
        review_count: 2,
        verified: false,
      },
    ]);

    await render(
      <template>
        <CrimsonServerFeaturedStrip @servers={{this.servers}} />
      </template>
    );

    assert.dom(".csl-v3-featured-card").exists({ count: 2 });
    assert.dom(".csl-v3-featured").includesText("CrimsonCraft");
    assert.dom(".csl-v3-featured").includesText("RustEmpire");
    assert.dom(".csl-v3-featured").doesNotIncludeText("Third Featured");
    assert.dom(".csl-v3-featured").doesNotIncludeText("Regular Server");
  });

  test("does not render when no featured servers are available", async function (assert) {
    this.set("servers", [{ id: 1, featured: false }]);

    await render(
      <template>
        <CrimsonServerFeaturedStrip @servers={{this.servers}} />
      </template>
    );

    assert.dom(".csl-v3-featured").doesNotExist();
  });
});
