import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerApprovalPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-approval-panel";

function serverFixture(id, name) {
  return {
    id,
    game_slug: "minecraft",
    game: { icon: "⛏️", name: "Minecraft" },
    name,
    short_description: `${name} description`,
    address: `${name.toLowerCase()}.example.net:25565`,
    owner: { username: "owner" },
  };
}

module("Integration | Component | crimson-server-approval-panel", function (hooks) {
  setupRenderingTest(hooks);

  test("replaces stale bootstrap queues with a fresh admin read and keeps moderation server-authoritative", async function (assert) {
    let bootstrapReads = 0;
    let publishes = 0;

    this.set("model", {
      viewer: { is_admin: true },
      pending_servers: [serverFixture(1, "Stale")],
      pending_claims: [],
    });

    pretender.get("/crimson-server-list/bootstrap.json", () => {
      bootstrapReads += 1;
      return response({
        viewer: { is_admin: true },
        pending_servers: [serverFixture(2, "Fresh")],
        pending_claims: [],
      });
    });

    pretender.put("/crimson-server-list/admin/servers/2.json", () => {
      publishes += 1;
      return response({ server: serverFixture(2, "Fresh") });
    });

    await render(
      <template>
        <CrimsonServerApprovalPanel @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(bootstrapReads, 1);
    assert.dom(".csl-v3-admin-card").exists({ count: 1 });
    assert.dom(".csl-v3-admin-card").includesText("Fresh");
    assert.dom(".csl-v3-admin-card").doesNotIncludeText("Stale");

    await click(".csl-v3-admin-card .csl-button--primary");
    await settled();

    assert.strictEqual(publishes, 1);
    assert.dom(".csl-v3-admin-card").doesNotExist();
    assert.dom(".csl-notice--success").exists();
  });

  test("does not render or request admin queues for non-admins", async function (assert) {
    let bootstrapReads = 0;
    this.set("model", { viewer: { is_admin: false } });

    pretender.get("/crimson-server-list/bootstrap.json", () => {
      bootstrapReads += 1;
      return response({ pending_servers: [], pending_claims: [] });
    });

    await render(
      <template>
        <CrimsonServerApprovalPanel @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(bootstrapReads, 0);
    assert.dom(".csl-v3-admin-panel").doesNotExist();
  });
});
