import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CrimsonVerifiedBadge from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-verified-badge";

module("Integration | Component | crimson-verified-badge", function (hooks) {
  setupRenderingTest(hooks);

  test("renders for a verified server", async function (assert) {
    this.set("server", { verified: true });

    await render(
      <template>
        <CrimsonVerifiedBadge @server={{this.server}} />
      </template>
    );

    assert.dom(".csl-verified-badge").exists();
    assert.dom(".csl-verified-badge .d-icon").exists();
  });

  test("does not render for an unverified server", async function (assert) {
    this.set("server", { verified: false });

    await render(
      <template>
        <CrimsonVerifiedBadge @server={{this.server}} />
      </template>
    );

    assert.dom(".csl-verified-badge").doesNotExist();
  });
});
