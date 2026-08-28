import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CrimsonReportModeration from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-report-moderation";

module("Integration | Component | crimson-report-moderation", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the moderation entry point for admins", async function (assert) {
    this.set("viewer", { is_admin: true });

    await render(
      <template>
        <CrimsonReportModeration @viewer={{this.viewer}} />
      </template>
    );

    assert.dom(".csl-report-moderation").exists();
    assert.dom(".csl-report-moderation button").exists();
  });

  test("does not render the moderation entry point for non-admins", async function (assert) {
    this.set("viewer", { is_admin: false });

    await render(
      <template>
        <CrimsonReportModeration @viewer={{this.viewer}} />
      </template>
    );

    assert.dom(".csl-report-moderation").doesNotExist();
  });
});
