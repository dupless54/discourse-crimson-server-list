import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonReportModeration from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-report-moderation";

module("Integration | Component | crimson-report-moderation", function (hooks) {
  setupRenderingTest(hooks);

  test("renders and loads the moderation entry point for admins", async function (assert) {
    let reads = 0;
    pretender.get("/crimson-server-list/admin/reports.json", () => {
      reads += 1;
      return response({ reports: [] });
    });

    this.set("viewer", { is_admin: true });

    await render(
      <template>
        <CrimsonReportModeration @viewer={{this.viewer}} />
      </template>,
    );

    assert.dom(".csl-report-moderation").exists();
    assert.dom(".csl-report-moderation button").exists();
    assert.dom(".csl-v3-tab-empty").exists();
    assert.strictEqual(reads, 1, "the moderation queue auto-loads once");
  });

  test("does not render or load the moderation queue for non-admins", async function (assert) {
    let reads = 0;
    pretender.get("/crimson-server-list/admin/reports.json", () => {
      reads += 1;
      return response({ reports: [] });
    });

    this.set("viewer", { is_admin: false });

    await render(
      <template>
        <CrimsonReportModeration @viewer={{this.viewer}} />
      </template>,
    );

    assert.dom(".csl-report-moderation").doesNotExist();
    assert.strictEqual(reads, 0);
  });
});
