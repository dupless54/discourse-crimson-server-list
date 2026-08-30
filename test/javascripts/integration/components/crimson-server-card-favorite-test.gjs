import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerCardFavorite from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-card-favorite";

module("Integration | Component | crimson-server-card-favorite", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = true;
    this.set("viewer", { logged_in: true });
    this.set("firstServer", { id: 41 });
    this.set("secondServer", { id: 42 });
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
  });

  test("recovers all cards when the shared private favorite state reload succeeds", async function (assert) {
    let reads = 0;

    pretender.get("/crimson-server-list/me/follows.json", () => {
      reads += 1;

      if (reads === 1) {
        return response(500, { errors: ["Favorites temporarily unavailable"] });
      }

      return response({
        follows: [
          {
            server_id: 42,
            favorited: true,
            notifications_enabled: false,
          },
        ],
      });
    });

    await render(
      <template>
        <CrimsonServerCardFavorite
          @server={{this.firstServer}}
          @viewer={{this.viewer}}
        />
        <CrimsonServerCardFavorite
          @server={{this.secondServer}}
          @viewer={{this.viewer}}
        />
      </template>,
    );
    await settled();

    assert.strictEqual(reads, 1, "the initial shared private read is deduplicated");
    assert.dom(".csl-card-favorite--retry").exists({ count: 2 });
    assert.dom('[data-server-id="41"] + .sr-only').includesText(
      "Favorites temporarily unavailable",
    );

    await click('.csl-card-favorite--retry[data-server-id="41"]');
    await settled();

    assert.strictEqual(reads, 2, "retry performs one fresh authoritative read");
    assert.dom(".csl-card-favorite--retry").doesNotExist();
    assert.dom(".csl-card-favorite").exists({ count: 2 });
    assert
      .dom('.csl-card-favorite[data-server-id="41"]')
      .hasAttribute("aria-pressed", "false");
    assert
      .dom('.csl-card-favorite[data-server-id="42"]')
      .hasAttribute("aria-pressed", "true");
    assert.dom(".sr-only[role='alert']").doesNotExist();
  });
});
