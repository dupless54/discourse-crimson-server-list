import { click, render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CrimsonServerV3Nav from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-v3-nav";

module("Integration | Component | crimson-server-v3-nav", function (hooks) {
  setupRenderingTest(hooks);

  test("shows only discover navigation to anonymous viewers", async function (assert) {
    this.set("viewer", { logged_in: false, is_admin: false });

    await render(
      <template>
        <CrimsonServerV3Nav @viewer={{this.viewer}} />
      </template>
    );

    assert.dom(".csl-v3-nav a").exists({ count: 1 });
    assert.dom('.csl-v3-nav a[href="#csl-v3-discover"]').hasClass("is-active");
  });

  test("shows personal and administration sections to an admin", async function (assert) {
    this.set("viewer", { logged_in: true, is_admin: true });

    await render(
      <template>
        <CrimsonServerV3Nav @viewer={{this.viewer}} />
      </template>
    );

    assert.dom(".csl-v3-nav a").exists({ count: 4 });

    await click('.csl-v3-nav a[href="#csl-v3-owned"]');

    assert.dom('.csl-v3-nav a[href="#csl-v3-owned"]').hasClass("is-active");
    assert
      .dom('.csl-v3-nav a[href="#csl-v3-discover"]')
      .doesNotHaveClass("is-active");
  });
});
