import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CrimsonServerFeaturedStrip from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-featured-strip";

function featuredServer(id, name, status = "online") {
  return {
    id,
    featured: true,
    name,
    short_description: `${name} community`,
    detail_url: `/servers/server-${id}`,
    game_slug: "minecraft",
    game: { icon: "⛏️", name: "Minecraft" },
    status,
    supports_player_count: true,
    players_online: 12,
    players_max: 100,
    average_rating: 4.8,
    review_count: 20,
    verified: false,
  };
}

module("Integration | Component | crimson-server-featured-strip", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only featured servers and limits the strip to two", async function (assert) {
    this.set("servers", [
      {
        ...featuredServer(1, "CrimsonCraft"),
        game: { icon: "⛏️", name: "Minecraft" },
        verified: true,
        players_online: 128,
        players_max: 300,
      },
      {
        ...featuredServer(2, "RustEmpire"),
        game_slug: "rust",
        game: { icon: "☢️", name: "Rust" },
        players_online: 156,
        players_max: 250,
        average_rating: 4.7,
        review_count: 17,
      },
      {
        ...featuredServer(3, "Third Featured"),
        game_slug: "ark",
        game: { icon: "🦖", name: "ARK" },
        short_description: "Should not be shown in the compact strip",
        players_online: 10,
        players_max: 20,
        average_rating: 4.5,
        review_count: 4,
      },
      {
        ...featuredServer(4, "Regular Server"),
        featured: false,
        game_slug: "fivem",
        game: { icon: "🚓", name: "FiveM" },
        short_description: "Regular listing",
        players_online: 12,
        players_max: 30,
        average_rating: 4.0,
        review_count: 2,
      },
    ]);

    await render(
      <template>
        <CrimsonServerFeaturedStrip @servers={{this.servers}} />
      </template>,
    );

    assert.dom(".csl-v3-featured-card").exists({ count: 2 });
    assert.dom(".csl-v3-featured").includesText("CrimsonCraft");
    assert.dom(".csl-v3-featured").includesText("RustEmpire");
    assert.dom(".csl-v3-featured").doesNotIncludeText("Third Featured");
    assert.dom(".csl-v3-featured").doesNotIncludeText("Regular Server");
  });

  test("preserves maintenance and unknown status semantics", async function (assert) {
    this.set("servers", [
      featuredServer(1, "Maintenance Server", "maintenance"),
      featuredServer(2, "Unknown Server", "unknown"),
    ]);

    await render(
      <template>
        <CrimsonServerFeaturedStrip @servers={{this.servers}} />
      </template>,
    );

    assert
      .dom(".csl-v3-featured-card:first-child .csl-status")
      .hasClass("csl-status--maintenance")
      .hasText("Maintenance");
    assert
      .dom(".csl-v3-featured-card:last-child .csl-status")
      .hasClass("csl-status--unknown")
      .hasText("Unknown");
  });

  test("does not render when no featured servers are available", async function (assert) {
    this.set("servers", [{ id: 1, featured: false }]);

    await render(
      <template>
        <CrimsonServerFeaturedStrip @servers={{this.servers}} />
      </template>,
    );

    assert.dom(".csl-v3-featured").doesNotExist();
  });
});
