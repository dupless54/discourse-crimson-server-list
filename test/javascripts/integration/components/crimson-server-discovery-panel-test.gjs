import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CrimsonServerDiscoveryPanel from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-discovery-panel";

function serverFixture(id, name) {
  return {
    id,
    slug: `server-${id}`,
    detail_url: `/servers/server-${id}`,
    game_slug: "minecraft",
    game: {
      slug: "minecraft",
      name: "Minecraft",
      icon: "⛏️",
      category_url: "/servers?game=minecraft",
    },
    name,
    short_description: `${name} description`,
    website_url: null,
    discord_url: null,
    banner_url: null,
    country_code: "TR",
    language: "Türkçe",
    version: "1.21",
    mode: "Survival",
    tags: ["survival"],
    tag_rows: [
      {
        slug: "survival",
        name: "survival",
        url: "/servers?tag=survival",
      },
    ],
    status: "online",
    status_label: "Online",
    players_online: 12,
    players_max: 100,
    supports_player_count: true,
    vote_count: 7,
    review_count: 2,
    average_rating: 4.5,
    featured: false,
    verified: false,
    voted_today: false,
    owner: {
      username: "owner",
      profile_url: "/u/owner",
      avatar_url: null,
    },
  };
}

function modelFixture() {
  return {
    games: [
      {
        slug: "minecraft",
        name: "Minecraft",
        icon: "⛏️",
        server_count: 3,
      },
      {
        slug: "rust",
        name: "Rust",
        icon: "☢️",
        server_count: 1,
      },
    ],
    tags: [
      {
        slug: "survival",
        name: "survival",
        server_count: 3,
      },
    ],
    stats: {
      server_count: 4,
    },
    viewer: {
      logged_in: true,
      can_vote: true,
    },
    servers: [serverFixture(99, "Bootstrap Server")],
  };
}

module("Integration | Component | crimson-server-discovery-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.previousUrl = `${window.location.pathname}${window.location.search}`;
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.previousFollowsEnabled =
      this.siteSettings.crimson_server_list_follows_enabled;
    this.siteSettings.crimson_server_list_follows_enabled = false;
    this.set("model", modelFixture());
  });

  hooks.afterEach(function () {
    window.history.replaceState(window.history.state, "", this.previousUrl);
    this.siteSettings.crimson_server_list_follows_enabled =
      this.previousFollowsEnabled;
  });

  test("uses authoritative filtered pagination and replaces the legacy catalogue", async function (assert) {
    const requests = [];

    window.history.replaceState(
      window.history.state,
      "",
      "/servers?game=minecraft&tag=survival",
    );

    pretender.get("/crimson-server-list/discovery.json", (request) => {
      requests.push({ ...request.queryParams });

      if (request.queryParams.q === "alpha") {
        return response({
          servers: [serverFixture(4, "Alpha Search")],
          pagination: {
            page: 1,
            per_page: 24,
            total: 1,
            total_pages: 1,
            has_more: false,
          },
        });
      }

      if (request.queryParams.page === "2") {
        return response({
          servers: [
            serverFixture(2, "Second Server"),
            serverFixture(3, "Third Server"),
          ],
          pagination: {
            page: 2,
            per_page: 24,
            total: 3,
            total_pages: 2,
            has_more: false,
          },
        });
      }

      return response({
        servers: [
          serverFixture(1, "First Server"),
          serverFixture(2, "Second Server"),
        ],
        pagination: {
          page: 1,
          per_page: 24,
          total: 3,
          total_pages: 2,
          has_more: true,
        },
      });
    });

    await render(
      <template>
        <div class="csl-route-wrap--paginated-discovery">
          <main class="csl-page">
            <section class="csl-discovery legacy-discovery"></section>
            <section class="csl-server-list legacy-server-list"></section>
            <p class="csl-footnote legacy-footnote">Legacy</p>
          </main>
          <CrimsonServerDiscoveryPanel @model={{this.model}} />
        </div>
      </template>,
    );
    await settled();

    assert.dom(".legacy-discovery").hasAttribute("hidden");
    assert.dom(".legacy-server-list").hasAttribute("hidden");
    assert.dom(".legacy-footnote").hasAttribute("hidden");
    assert.strictEqual(requests.length, 1, "initial render performs one discovery request");
    assert.strictEqual(requests[0].game, "minecraft");
    assert.strictEqual(requests[0].tag, "survival");
    assert.strictEqual(requests[0].sort, "top");
    assert.strictEqual(requests[0].page, "1");
    assert.strictEqual(requests[0].per_page, "24");
    assert.dom(".csl-discovery-shell .csl-server-card").exists({ count: 2 });
    assert
      .dom(".csl-discovery-shell .csl-server-card__title-row h2 a")
      .hasText("First Server");
    assert.dom(".csl-discovery-shell").doesNotIncludeText("Bootstrap Server");
    assert.dom(".csl-discovery-shell").includesText("3 servers found");
    assert.dom(".csl-discovery-load-more button").exists();

    await click(".csl-discovery-load-more button");
    await settled();

    assert.strictEqual(requests.at(-1).page, "2");
    assert.dom(".csl-discovery-shell .csl-server-card").exists({ count: 3 });
    assert
      .dom(".csl-discovery-shell")
      .includesText("Third Server", "the next page is appended");
    assert.dom(".csl-discovery-load-more button").doesNotExist();

    await fillIn(".csl-discovery-shell .csl-search input", "alpha");
    await settled();

    assert.strictEqual(requests.at(-1).q, "alpha");
    assert.strictEqual(requests.at(-1).page, "1", "search resets pagination");
    assert.dom(".csl-discovery-shell .csl-server-card").exists({ count: 1 });
    assert.dom(".csl-discovery-shell").includesText("Alpha Search");
  });

  test("keeps vote state server-authoritative after a successful mutation", async function (assert) {
    let votes = 0;

    window.history.replaceState(window.history.state, "", "/servers");

    pretender.get("/crimson-server-list/discovery.json", () =>
      response({
        servers: [serverFixture(42, "Vote Server")],
        pagination: {
          page: 1,
          per_page: 24,
          total: 1,
          total_pages: 1,
          has_more: false,
        },
      }),
    );
    pretender.post("/crimson-server-list/servers/42/vote.json", () => {
      votes += 1;
      return response({
        server_id: 42,
        vote_count: 8,
        voted_today: true,
        message: "Vote saved.",
      });
    });

    await render(
      <template>
        <CrimsonServerDiscoveryPanel @model={{this.model}} />
      </template>,
    );
    await settled();

    assert
      .dom(".csl-discovery-shell .csl-vote-button")
      .hasAttribute("aria-pressed", "false");

    await click(".csl-discovery-shell .csl-vote-button");
    await settled();

    assert.strictEqual(votes, 1);
    assert.dom(".csl-discovery-shell .csl-votes strong").hasText("8");
    assert
      .dom(".csl-discovery-shell .csl-vote-button")
      .hasAttribute("aria-pressed", "true");
    assert
      .dom(".csl-discovery-shell .csl-vote-button")
      .hasText("Voted today");
  });

  test("loads card favorites once and keeps mutations server-authoritative", async function (assert) {
    let favoriteReads = 0;
    let additions = 0;
    let removals = 0;

    this.siteSettings.crimson_server_list_follows_enabled = true;
    window.history.replaceState(window.history.state, "", "/servers");

    pretender.get("/crimson-server-list/discovery.json", () =>
      response({
        servers: [
          serverFixture(41, "Favorite One"),
          serverFixture(42, "Favorite Two"),
        ],
        pagination: {
          page: 1,
          per_page: 24,
          total: 2,
          total_pages: 1,
          has_more: false,
        },
      }),
    );

    pretender.get("/crimson-server-list/me/follows.json", () => {
      favoriteReads += 1;
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

    pretender.put("/crimson-server-list/servers/41/follow.json", () => {
      additions += 1;
      return response({
        server_id: 41,
        favorited: true,
        notifications_enabled: false,
      });
    });

    pretender.delete("/crimson-server-list/servers/42/follow.json", () => {
      removals += 1;
      return response({
        server_id: 42,
        favorited: false,
        notifications_enabled: false,
      });
    });

    await render(
      <template>
        <CrimsonServerDiscoveryPanel @model={{this.model}} />
      </template>,
    );
    await settled();

    assert.strictEqual(
      favoriteReads,
      1,
      "all rendered server cards share one private favorites bootstrap request",
    );
    assert.dom(".csl-card-favorite").exists({ count: 2 });
    assert
      .dom('.csl-card-favorite[data-server-id="41"]')
      .hasAttribute("aria-pressed", "false");
    assert
      .dom('.csl-card-favorite[data-server-id="42"]')
      .hasAttribute("aria-pressed", "true");

    await click('.csl-card-favorite[data-server-id="41"]');
    await settled();

    assert.strictEqual(additions, 1, "adding uses one server-authoritative mutation");
    assert
      .dom('.csl-card-favorite[data-server-id="41"]')
      .hasAttribute("aria-pressed", "true");

    await click('.csl-card-favorite[data-server-id="42"]');
    await settled();

    assert.strictEqual(removals, 1, "removing uses one server-authoritative mutation");
    assert
      .dom('.csl-card-favorite[data-server-id="42"]')
      .hasAttribute("aria-pressed", "false");
    assert.strictEqual(favoriteReads, 1, "mutations do not refetch the favorite list");
  });
});
