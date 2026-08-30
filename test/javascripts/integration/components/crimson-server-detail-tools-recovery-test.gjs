import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerFavoriteAction from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-favorite-action";
import CrimsonServerUptimePanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-uptime-panel";

module("Integration | Component | crimson-server-detail-tools-recovery", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.previousUptimeEnabled =
      this.siteSettings.crimson_server_list_uptime_history_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;
    this.siteSettings.crimson_server_list_uptime_history_enabled = true;
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
    this.siteSettings.crimson_server_list_uptime_history_enabled =
      this.previousUptimeEnabled;
  });

  test("locks favorite mutation controls until private state is recovered", async function (assert) {
    let reads = 0;
    this.set("model", {
      server: { id: 42, approved: true, enabled: true },
      viewer: { logged_in: true },
    });

    pretender.get("/crimson-server-list/servers/42/follow.json", () => {
      reads += 1;
      if (reads === 1) {
        return response(500, { errors: ["Favorite state failed"] });
      }

      return response({
        server_id: 42,
        favorited: true,
        notifications_enabled: false,
      });
    });

    await render(
      <template>
        <CrimsonServerFavoriteAction @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(reads, 1);
    assert.dom(".csl-favorite-action__error").includesText("Favorite state failed");
    assert.dom(".csl-favorite-action__button").isDisabled();
    assert.dom(".csl-favorite-action__error .csl-button").exists();

    await click(".csl-favorite-action__error .csl-button");
    await settled();

    assert.strictEqual(reads, 2);
    assert.dom(".csl-favorite-action__error").doesNotExist();
    assert.dom(".csl-favorite-action__button").isNotDisabled();
    assert.dom(".csl-favorite-action__button").hasAttribute("aria-pressed", "true");
  });

  test("offers an explicit retry when uptime history fails to load", async function (assert) {
    let reads = 0;
    this.set("model", {
      server: { id: 42, approved: true, enabled: true },
    });

    pretender.get("/crimson-server-list/servers/42/uptime.json", () => {
      reads += 1;
      if (reads === 1) {
        return response(500, { errors: ["Uptime failed"] });
      }

      return response({
        uptime: {
          range: "24h",
          sample_count: 0,
          known_sample_count: 0,
          online_sample_count: 0,
          uptime_percent: null,
          series: [],
        },
      });
    });

    await render(
      <template>
        <CrimsonServerUptimePanel @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(reads, 1);
    assert.dom(".csl-uptime-panel .csl-v3-panel-error").includesText("Uptime failed");

    await click(".csl-uptime-panel .csl-v3-panel-error .csl-button");
    await settled();

    assert.strictEqual(reads, 2);
    assert.dom(".csl-uptime-panel .csl-v3-panel-error").doesNotExist();
    assert.dom(".csl-uptime-panel .csl-empty").exists();
  });
});
