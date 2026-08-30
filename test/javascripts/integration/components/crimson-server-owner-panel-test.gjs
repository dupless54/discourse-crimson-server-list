import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerOwnerPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-owner-panel";

function serverFixture(id, name, publicationState, overrides = {}) {
  return {
    id,
    slug: name.toLowerCase().replaceAll(" ", "-"),
    detail_url: `/servers/${name.toLowerCase().replaceAll(" ", "-")}`,
    game_slug: "minecraft",
    game: { icon: "⛏️", name: "Minecraft" },
    name,
    short_description: "Owner panel fixture.",
    status: "online",
    address: `${name.toLowerCase().replaceAll(" ", "-")}.example.net:25565`,
    vote_count: 5,
    view_count: 20,
    review_count: 2,
    verified: false,
    management: {
      publication_state: publicationState,
      can_edit: true,
      can_refresh: publicationState === "published",
      edit_requires_approval: true,
    },
    ...overrides,
  };
}

module("Integration | Component | crimson-server-owner-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("viewer", { logged_in: true });
  });

  test("loads owned servers on mount and appends pagination without duplicates", async function (assert) {
    const reads = [];

    pretender.get("/crimson-server-list/me/servers.json", (request) => {
      const page = Number(request.queryParams.page || 1);
      reads.push({ page, perPage: Number(request.queryParams.per_page) });

      if (page === 1) {
        return response({
          servers: [
            serverFixture(42, "Published Mine", "published", {
              verified: true,
              address: "owner.example.net:25565",
            }),
            serverFixture(43, "Pending Mine", "pending", { status: "unknown" }),
          ],
          stats: {
            total: 13,
            published: 10,
            pending: 2,
            disabled: 1,
            online: 8,
            monitored: 11,
            verified: 4,
          },
          pagination: {
            page: 1,
            per_page: 12,
            total: 13,
            total_pages: 2,
            has_more: true,
          },
        });
      }

      return response({
        servers: [
          serverFixture(43, "Pending Mine", "pending", { status: "unknown" }),
          serverFixture(44, "Disabled Mine", "disabled", { status: "offline" }),
        ],
        stats: {
          total: 13,
          published: 10,
          pending: 2,
          disabled: 1,
          online: 8,
          monitored: 11,
          verified: 4,
        },
        pagination: {
          page: 2,
          per_page: 12,
          total: 13,
          total_pages: 2,
          has_more: false,
        },
      });
    });

    await render(
      <template>
        <CrimsonServerOwnerPanel @viewer={{this.viewer}} />
      </template>,
    );
    await settled();

    assert.deepEqual(reads, [{ page: 1, perPage: 12 }]);
    assert.dom(".csl-owner-panel__toggle").doesNotExist();
    assert.dom(".csl-owner-card").exists({ count: 2 });
    assert.dom(".csl-owner-card__address").includesText("owner.example.net:25565");
    assert.dom(".csl-owner-card__publication--published").exists();
    assert.dom(".csl-owner-card__publication--pending").exists();
    assert.dom(".csl-owner-panel__stats").exists();

    await click(".csl-owner-panel__more .csl-button");
    await settled();

    assert.deepEqual(reads, [
      { page: 1, perPage: 12 },
      { page: 2, perPage: 12 },
    ]);
    assert.dom(".csl-owner-card").exists({ count: 3 });
    assert.dom(".csl-owner-card__publication--disabled").exists();
  });

  test("shows an explicit error state and retries the private request", async function (assert) {
    let reads = 0;

    pretender.get("/crimson-server-list/me/servers.json", () => {
      reads += 1;
      if (reads === 1) {
        return response(500, { errors: ["Owner dashboard failed"] });
      }

      return response({
        servers: [],
        stats: {
          total: 0,
          published: 0,
          pending: 0,
          disabled: 0,
          online: 0,
          monitored: 0,
          verified: 0,
        },
        pagination: {
          page: 1,
          per_page: 12,
          total: 0,
          total_pages: 0,
          has_more: false,
        },
      });
    });

    await render(
      <template>
        <CrimsonServerOwnerPanel @viewer={{this.viewer}} />
      </template>,
    );
    await settled();

    assert.strictEqual(reads, 1);
    assert.dom(".csl-owner-panel__error").exists();
    assert.dom(".csl-owner-panel__error").includesText("Owner dashboard failed");

    await click(".csl-owner-panel__error .csl-button");
    await settled();

    assert.strictEqual(reads, 2);
    assert.dom(".csl-owner-panel__error").doesNotExist();
    assert.dom(".csl-owner-card").doesNotExist();
  });

  test("does not render or request the private list for guests", async function (assert) {
    let requested = false;
    this.set("viewer", { logged_in: false });

    pretender.get("/crimson-server-list/me/servers.json", () => {
      requested = true;
      return response({ servers: [] });
    });

    await render(
      <template>
        <CrimsonServerOwnerPanel @viewer={{this.viewer}} />
      </template>,
    );
    await settled();

    assert.false(requested);
    assert.dom(".csl-owner-panel").doesNotExist();
  });
});
