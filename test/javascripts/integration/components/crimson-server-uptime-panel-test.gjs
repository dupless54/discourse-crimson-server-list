import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerUptimePanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-uptime-panel";

module("Integration | Component | crimson-server-uptime-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousUptimeEnabled =
      this.siteSettings.crimson_server_list_uptime_history_enabled;
    this.siteSettings.crimson_server_list_uptime_history_enabled = true;
    this.set("model", { server: { id: 42, name: "CrimsonCraft" } });
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_uptime_history_enabled =
      this.previousUptimeEnabled;
  });

  test("loads observed uptime and switches ranges", async function (assert) {
    const requestedRanges = [];

    pretender.get("/crimson-server-list/servers/42/uptime.json", (request) => {
      requestedRanges.push(request.queryParams.range);
      const sevenDays = request.queryParams.range === "7d";

      return response({
        range: request.queryParams.range,
        sample_count: sevenDays ? 6 : 3,
        known_sample_count: sevenDays ? 5 : 2,
        online_sample_count: sevenDays ? 4 : 1,
        uptime_percent: sevenDays ? 80 : 50,
        series: [
          {
            sampled_at: "2026-08-28T20:00:00Z",
            status: "online",
            response_ms: 45,
            supports_player_count: true,
            players_online: 12,
            players_max: 100,
          },
          {
            sampled_at: "2026-08-28T20:10:00Z",
            status: "offline",
            response_ms: null,
            supports_player_count: false,
            players_online: null,
            players_max: null,
          },
        ],
      });
    });

    await render(
      <template>
        <CrimsonServerUptimePanel @model={{this.model}} />
      </template>
    );
    await settled();

    assert.deepEqual(requestedRanges, ["24h"]);
    assert.dom(".csl-uptime-panel").exists();
    assert.dom(".csl-uptime-summary strong").hasText("50%");
    assert.dom(".csl-uptime-point").exists({ count: 2 });
    assert.dom(".csl-uptime-point--online").exists();
    assert.dom(".csl-uptime-point--offline").exists();

    await click(".csl-uptime-ranges button:nth-child(2)");
    await settled();

    assert.deepEqual(requestedRanges, ["24h", "7d"]);
    assert.dom(".csl-uptime-summary strong").hasText("80%");
  });

  test("does not render or request history when the feature is disabled", async function (assert) {
    let requested = false;
    this.siteSettings.crimson_server_list_uptime_history_enabled = false;

    pretender.get("/crimson-server-list/servers/42/uptime.json", () => {
      requested = true;
      return response({});
    });

    await render(
      <template>
        <CrimsonServerUptimePanel @model={{this.model}} />
      </template>
    );
    await settled();

    assert.false(requested);
    assert.dom(".csl-uptime-panel").doesNotExist();
  });
});
