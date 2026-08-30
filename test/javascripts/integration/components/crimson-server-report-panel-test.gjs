import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CrimsonServerReportPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-report-panel";

module("Integration | Component | crimson-server-report-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousReportsEnabled =
      this.siteSettings.crimson_server_list_reports_enabled;
    this.siteSettings.crimson_server_list_reports_enabled = true;
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_reports_enabled =
      this.previousReportsEnabled;
  });

  test("opens the report flow in DModal instead of page flow", async function (assert) {
    this.set("model", {
      server: { id: 42, name: "CrimsonCraft" },
      viewer: { logged_in: true, can_edit: false },
    });

    await render(
      <template>
        <CrimsonServerReportPanel @model={{this.model}} />
      </template>,
    );

    assert.dom(".csl-report-panel").exists();
    assert.dom(".csl-report-form").doesNotExist();
    assert.dom(".csl-server-report-modal").doesNotExist();

    await click(".csl-report-panel > button");

    assert.dom(".csl-report-form").doesNotExist("no inline form is inserted into the page");
    assert.dom(".csl-server-report-modal").exists();
    assert.dom("#csl-server-report-form select[name='reason']").exists();
    assert.dom("#csl-server-report-form textarea[name='details']").exists();
  });

  test("does not expose the member report action to the listing owner", async function (assert) {
    this.set("model", {
      server: { id: 42, name: "CrimsonCraft" },
      viewer: { logged_in: true, can_edit: true },
    });

    await render(
      <template>
        <CrimsonServerReportPanel @model={{this.model}} />
      </template>,
    );

    assert.dom(".csl-report-panel").doesNotExist();
  });
});
