import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerV3Shell from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-v3-shell";

module("Integration | Component | crimson-server-v3-history", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.previousUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;
    window.history.replaceState(window.history.state, "", "/servers");

    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;

    this.set("model", {
      viewer: {
        logged_in: true,
        is_admin: false,
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
    });

    pretender.get("/crimson-server-list/discovery.json", () =>
      response({
        servers: [],
        pagination: {
          page: 1,
          per_page: 24,
          total: 0,
          total_pages: 0,
          has_more: false,
        },
      }),
    );
    pretender.get("/crimson-server-list/me/follows.json", () =>
      response({ follows: [] }),
    );
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
    window.history.replaceState(window.history.state, "", this.previousUrl);
  });

  test("keeps the active panel in sync with browser history", async function (assert) {
    await render(
      <template>
        <CrimsonServerV3Shell @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.dom("#csl-v3-discover").exists();

    window.history.pushState(window.history.state, "", "/servers#favorites");
    window.dispatchEvent(new PopStateEvent("popstate"));
    await settled();

    assert.dom("#csl-v3-discover").doesNotExist();
    assert.dom("#csl-v3-favorites").exists();

    window.history.pushState(window.history.state, "", "/servers#discover");
    window.dispatchEvent(new PopStateEvent("popstate"));
    await settled();

    assert.dom("#csl-v3-favorites").doesNotExist();
    assert.dom("#csl-v3-discover").exists();
  });
});
