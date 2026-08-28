import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerFavoriteAction from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-favorite-action";

module("Integration | Component | crimson-server-favorite-action", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;
    this.set("model", {
      server: { id: 42, name: "CrimsonCraft", approved: true, enabled: true },
      viewer: { logged_in: true },
    });
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
  });

  test("loads private state and toggles the favorite", async function (assert) {
    let reads = 0;
    let additions = 0;
    let removals = 0;

    pretender.get("/crimson-server-list/servers/42/follow.json", () => {
      reads += 1;
      return response({
        server_id: 42,
        favorited: false,
        notifications_enabled: false,
      });
    });
    pretender.put("/crimson-server-list/servers/42/follow.json", () => {
      additions += 1;
      return response({
        server_id: 42,
        favorited: true,
        notifications_enabled: false,
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
        <CrimsonServerFavoriteAction @model={{this.model}} />
      </template>
    );
    await settled();

    assert.strictEqual(reads, 1, "favorite state is read once");
    assert.dom(".csl-favorite-action").exists();
    assert
      .dom(".csl-favorite-action__button")
      .hasAttribute("aria-pressed", "false");

    await click(".csl-favorite-action__button");
    await settled();

    assert.strictEqual(additions, 1, "favorite is added with one mutation");
    assert
      .dom(".csl-favorite-action__button")
      .hasAttribute("aria-pressed", "true");

    await click(".csl-favorite-action__button");
    await settled();

    assert.strictEqual(removals, 1, "favorite is removed with one mutation");
    assert
      .dom(".csl-favorite-action__button")
      .hasAttribute("aria-pressed", "false");
  });

  test("does not request or render favorite controls when unavailable", async function (assert) {
    let requested = false;
    this.set("model", {
      server: { id: 42, approved: false, enabled: true },
      viewer: { logged_in: true },
    });

    pretender.get("/crimson-server-list/servers/42/follow.json", () => {
      requested = true;
      return response({ favorited: false });
    });

    await render(
      <template>
        <CrimsonServerFavoriteAction @model={{this.model}} />
      </template>
    );
    await settled();

    assert.false(requested, "unpublished listings do not trigger a private-state request");
    assert.dom(".csl-favorite-action").doesNotExist();
  });
});
