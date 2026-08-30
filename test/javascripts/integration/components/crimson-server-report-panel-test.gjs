import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CrimsonServerReportModal from "discourse/plugins/discourse-crimson-server-list/discourse/components/modal/crimson-server-report";
import CrimsonServerReportPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-report-panel";

module("Integration | Component | crimson-server-report-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousReportsEnabled =
      this.siteSettings.crimson_server_list_reports_enabled;
    this.siteSettings.crimson_server_list_reports_enabled = true;

    this.modal = this.owner.lookup("service:modal");
    this.originalModalShow = this.modal.show;
    this.modalCalls = [];
    this.modal.show = (component, options) => {
      this.modalCalls.push({ component, options });
    };
  });

  hooks.afterEach(function () {
    this.siteSettings.crimson_server_list_reports_enabled =
      this.previousReportsEnabled;
    this.modal.show = this.originalModalShow;
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

    await click(".csl-report-panel > button");

    assert.dom(".csl-report-form").doesNotExist("no inline form is inserted into the page");
    assert.strictEqual(this.modalCalls.length, 1, "the modal service is invoked once");
    assert.strictEqual(
      this.modalCalls[0].component,
      CrimsonServerReportModal,
      "the report DModal component is opened",
    );
    assert.strictEqual(
      this.modalCalls[0].options.model.server.id,
      42,
      "the selected server is passed to the modal",
    );
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
    assert.strictEqual(this.modalCalls.length, 0);
  });
});
