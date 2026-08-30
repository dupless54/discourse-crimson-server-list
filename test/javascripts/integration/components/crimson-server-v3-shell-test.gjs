import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerV3Shell from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-v3-shell";

function modelFixture() {
  return {
    viewer: {
      logged_in: true,
      is_admin: true,
      can_submit: false,
      can_vote: false,
    },
    games: [],
    tags: [],
    servers: [],
    pending_servers: [],
    pending_claims: [],
    stats: {
      server_count: 0,
      online_count: 0,
      vote_count: 0,
      game_count: 0,
    },
  };
}

module("Integration | Component | crimson-server-v3-shell", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.previousUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;
    window.history.replaceState(window.history.state, "", "/servers");

    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;
    this.set("model", modelFixture());
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
    window.history.replaceState(window.history.state, "", this.previousUrl);
  });

  test("renders exactly one real route panel and refreshes private panels on remount", async function (assert) {
    let discoveryReads = 0;
    let favoriteReads = 0;
    let ownedReads = 0;
    let adminBootstrapReads = 0;
    let reportReads = 0;

    pretender.get("/crimson-server-list/discovery.json", () => {
      discoveryReads += 1;
      return response({
        servers: [],
        pagination: {
          page: 1,
          per_page: 24,
          total: 0,
          total_pages: 0,
          has_more: false,
        },
      });
    });

    pretender.get("/crimson-server-list/me/follows.json", () => {
      favoriteReads += 1;
      return response({ follows: [] });
    });

    pretender.get("/crimson-server-list/me/servers.json", () => {
      ownedReads += 1;
      return response({
        servers: [],
        stats: {
          total: 0,
          published: 0,
          pending: 0,
          disabled: 0,
          online: 0,
          verified: 0,
        },
        pagination: {
          page: 1,
          per_page: 12,
          total: 0,
          total_pages: 0,
          has_more: false,
        },
      });
    });

    pretender.get("/crimson-server-list/bootstrap.json", () => {
      adminBootstrapReads += 1;
      return response({
        viewer: this.model.viewer,
        games: [],
        tags: [],
        stats: this.model.stats,
        pending_servers: [],
        pending_claims: [],
      });
    });

    pretender.get("/crimson-server-list/admin/reports.json", () => {
      reportReads += 1;
      return response({ reports: [] });
    });

    await render(
      <template>
        <CrimsonServerV3Shell @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(discoveryReads, 1);
    assert.strictEqual(favoriteReads, 0);
    assert.strictEqual(ownedReads, 0);
    assert.strictEqual(adminBootstrapReads, 0);
    assert.strictEqual(reportReads, 0);
    assert.dom("#csl-v3-discover").exists();
    assert.dom("#csl-v3-favorites").doesNotExist();
    assert.dom("#csl-v3-owned").doesNotExist();
    assert.dom("#csl-v3-admin").doesNotExist();

    await click("#csl-v3-tab-favorites");
    await settled();

    assert.dom("#csl-v3-discover").doesNotExist();
    assert.dom("#csl-v3-favorites").exists();
    assert.dom("#csl-v3-owned").doesNotExist();
    assert.dom("#csl-v3-admin").doesNotExist();
    assert.strictEqual(favoriteReads, 1);
    assert.strictEqual(window.location.hash, "#favorites");

    await click("#csl-v3-tab-owned");
    await settled();

    assert.dom("#csl-v3-favorites").doesNotExist();
    assert.dom("#csl-v3-owned").exists();
    assert.dom("#csl-v3-admin").doesNotExist();
    assert.strictEqual(ownedReads, 1);

    await click("#csl-v3-tab-administration");
    await settled();

    assert.dom("#csl-v3-owned").doesNotExist();
    assert.dom("#csl-v3-admin").exists();
    assert.dom("#csl-v3-discover").doesNotExist();
    assert.strictEqual(adminBootstrapReads, 1, "the admin queue is refreshed on mount");
    assert.strictEqual(reportReads, 1);

    await click("#csl-v3-tab-discover");
    await settled();

    assert.dom("#csl-v3-admin").doesNotExist();
    assert.dom("#csl-v3-discover").exists();
    assert.strictEqual(discoveryReads, 2, "returning to Discover remounts a clean discovery panel");

    await click("#csl-v3-tab-favorites");
    await settled();

    assert.dom("#csl-v3-discover").doesNotExist();
    assert.dom("#csl-v3-favorites").exists();
    assert.strictEqual(favoriteReads, 2, "revisiting Favorites remounts only that active panel");
    assert.strictEqual(ownedReads, 1);
    assert.strictEqual(adminBootstrapReads, 1);
    assert.strictEqual(reportReads, 1);

    await click("#csl-v3-tab-administration");
    await settled();

    assert.dom("#csl-v3-favorites").doesNotExist();
    assert.dom("#csl-v3-admin").exists();
    assert.strictEqual(
      adminBootstrapReads,
      2,
      "revisiting Administration fetches a fresh authoritative queue",
    );
    assert.strictEqual(reportReads, 2, "the report queue also refreshes on remount");
  });
});
