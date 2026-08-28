import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerFavoritesPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-favorites-panel";

module("Integration | Component | crimson-server-favorites-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;
    this.set("viewer", { logged_in: true });
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
  });

  test("lazy-loads the private list once and removes a favorite", async function (assert) {
    let listReads = 0;
    let removals = 0;

    pretender.get("/crimson-server-list/me/follows.json", () => {
      listReads += 1;
      return response({
        follows: [
          {
            server_id: 42,
            favorited: true,
            notifications_enabled: false,
            followed_at: "2026-08-28T20:00:00Z",
            updated_at: "2026-08-28T20:00:00Z",
            server: {
              id: 42,
              slug: "crimsoncraft",
              detail_url: "/servers/crimsoncraft",
              game_slug: "minecraft",
              name: "CrimsonCraft",
              short_description: "Private favorite fixture.",
              banner_url: null,
              status: "online",
              verified: true,
            },
          },
        ],
      });
    });
    pretender.delete("/crimson-server-list/servers/42/follow.json", () => {
      removals += 1;
      return response({
        server_id: 42,
        favorited: false,
        notifications_enabled: false,
      });
    });

    await render(
      <template>
        <CrimsonServerFavoritesPanel @viewer={{this.viewer}} />
      </template>
    );
    await settled();

    assert.strictEqual(listReads, 0, "closed panel does not request the private list");
    assert.dom(".csl-favorite-card").doesNotExist();

    await click(".csl-favorites-panel__toggle");
    await settled();

    assert.strictEqual(listReads, 1, "opening the panel performs one private-list request");
    assert.dom(".csl-favorite-card").exists({ count: 1 });
    assert.dom(".csl-favorite-card h3 a").hasText("CrimsonCraft");

    await click(".csl-favorite-card__remove");
    await settled();

    assert.strictEqual(removals, 1, "removal uses one delete mutation");
    assert.dom(".csl-favorite-card").doesNotExist();

    await click(".csl-favorites-panel__toggle");
    await click(".csl-favorites-panel__toggle");
    await settled();

    assert.strictEqual(listReads, 1, "reopening an already loaded panel does not refetch");
  });

  test("does not render or request the private list for guests", async function (assert) {
    let requested = false;
    this.set("viewer", { logged_in: false });

    pretender.get("/crimson-server-list/me/follows.json", () => {
      requested = true;
      return response({ follows: [] });
    });

    await render(
      <template>
        <CrimsonServerFavoritesPanel @viewer={{this.viewer}} />
      </template>
    );
    await settled();

    assert.false(requested);
    assert.dom(".csl-favorites-panel").doesNotExist();
  });
});
