import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerVerificationPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-verification-panel";

module("Integration | Component | crimson-server-verification-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("server", { id: 42, name: "CrimsonCraft", verified: false });
    this.set("viewer", { can_edit: true, verification_enabled: true });
  });

  test("shows a recoverable load error without falling through to ineligible state", async function (assert) {
    let reads = 0;

    pretender.get("/crimson-server-list/servers/42/verification.json", () => {
      reads += 1;
      if (reads === 1) {
        return response(500, { errors: ["Verification state failed"] });
      }

      return response({
        verification: {
          server_id: 42,
          verified: false,
          eligible: true,
          pending: false,
          record_name: "_crimson-server-list.example.net",
          expires_at: null,
        },
      });
    });

    await render(
      <template>
        <CrimsonServerVerificationPanel
          @server={{this.server}}
          @viewer={{this.viewer}}
        />
      </template>,
    );
    await settled();

    assert.strictEqual(reads, 1);
    assert.dom(".csl-notice--error").includesText("Verification state failed");
    assert.dom(".csl-verification-panel__actions").doesNotExist();
    assert.dom(".csl-verification-panel__status .csl-button").exists();

    await click(".csl-verification-panel__status .csl-button");
    await settled();

    assert.strictEqual(reads, 2);
    assert.dom(".csl-notice--error").doesNotExist();
    assert.dom(".csl-verification-panel__actions .csl-button--primary").exists();
  });

  test("starts a challenge and keeps the returned private TXT value in the owner-only panel", async function (assert) {
    let starts = 0;

    pretender.get("/crimson-server-list/servers/42/verification.json", () =>
      response({
        verification: {
          server_id: 42,
          verified: false,
          eligible: true,
          pending: false,
          record_name: "_crimson-server-list.example.net",
          expires_at: null,
        },
      }),
    );

    pretender.post("/crimson-server-list/servers/42/verification.json", () => {
      starts += 1;
      return response({
        verification: {
          server_id: 42,
          verified: false,
          eligible: true,
          pending: true,
          record_name: "_crimson-server-list.example.net",
          expires_at: "2026-09-01T12:00:00Z",
          challenge: {
            record_name: "_crimson-server-list.example.net",
            record_value: "crimson-verification-secret",
          },
        },
        message: "Verification started",
      });
    });

    await render(
      <template>
        <CrimsonServerVerificationPanel
          @server={{this.server}}
          @viewer={{this.viewer}}
        />
      </template>,
    );
    await settled();

    await click(".csl-verification-panel__actions .csl-button--primary");
    await settled();

    assert.strictEqual(starts, 1);
    assert.dom(".csl-notice--success").includesText("Verification started");
    assert.dom(".csl-verification-records").includesText("crimson-verification-secret");
  });
});
