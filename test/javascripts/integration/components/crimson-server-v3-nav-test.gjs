import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CrimsonServerV3Nav from "discourse/plugins/discourse-crimson-server-list/discourse/components/crimson-server-v3-nav";

module("Integration | Component | crimson-server-v3-nav", function (hooks) {
  setupRenderingTest(hooks);

  test("shows only discover navigation to anonymous viewers", async function (assert) {
    this.set("viewer", { logged_in: false, is_admin: false });
    this.set("activeTab", "discover");
    this.activate = (tab) => this.set("activeTab", tab);

    await render(
      <template>
        <CrimsonServerV3Nav
          @viewer={{this.viewer}}
          @activeTab={{this.activeTab}}
          @onActivate={{this.activate}}
        />
      </template>,
    );

    assert.dom(".csl-v3-nav button").exists({ count: 1 });
    assert.dom("#csl-v3-tab-discover").hasClass("is-active");
    assert.dom("#csl-v3-tab-discover").hasAttribute("aria-selected", "true");
    assert.dom("#csl-v3-tab-discover").hasAttribute("tabindex", "0");
  });

  test("drives the controlled active tab for an admin", async function (assert) {
    this.set("viewer", { logged_in: true, is_admin: true });
    this.set("activeTab", "discover");
    this.activate = (tab) => this.set("activeTab", tab);

    await render(
      <template>
        <CrimsonServerV3Nav
          @viewer={{this.viewer}}
          @activeTab={{this.activeTab}}
          @onActivate={{this.activate}}
        />
      </template>,
    );

    assert.dom(".csl-v3-nav button").exists({ count: 4 });

    await click("#csl-v3-tab-owned");

    assert.strictEqual(this.activeTab, "owned");
    assert.dom("#csl-v3-tab-owned").hasClass("is-active");
    assert.dom("#csl-v3-tab-owned").hasAttribute("aria-selected", "true");
    assert.dom("#csl-v3-tab-owned").hasAttribute("tabindex", "0");
    assert.dom("#csl-v3-tab-discover").doesNotHaveClass("is-active");
    assert.dom("#csl-v3-tab-discover").hasAttribute("aria-selected", "false");
    assert.dom("#csl-v3-tab-discover").hasAttribute("tabindex", "-1");
  });

  test("supports roving keyboard navigation across available tabs", async function (assert) {
    this.set("viewer", { logged_in: true, is_admin: true });
    this.set("activeTab", "discover");
    this.activate = (tab) => this.set("activeTab", tab);

    await render(
      <template>
        <CrimsonServerV3Nav
          @viewer={{this.viewer}}
          @activeTab={{this.activeTab}}
          @onActivate={{this.activate}}
        />
      </template>,
    );

    await triggerKeyEvent(
      "#csl-v3-tab-discover",
      "keydown",
      "ArrowRight",
    );

    assert.strictEqual(this.activeTab, "favorites");
    assert.dom("#csl-v3-tab-favorites").hasAttribute("tabindex", "0");
    assert.dom("#csl-v3-tab-favorites").isFocused();

    await triggerKeyEvent("#csl-v3-tab-favorites", "keydown", "End");

    assert.strictEqual(this.activeTab, "administration");
    assert.dom("#csl-v3-tab-administration").hasAttribute("tabindex", "0");
    assert.dom("#csl-v3-tab-administration").isFocused();

    await triggerKeyEvent(
      "#csl-v3-tab-administration",
      "keydown",
      "ArrowRight",
    );

    assert.strictEqual(this.activeTab, "discover", "right arrow wraps to the first tab");
    assert.dom("#csl-v3-tab-discover").isFocused();

    await triggerKeyEvent("#csl-v3-tab-discover", "keydown", "End");
    await triggerKeyEvent(
      "#csl-v3-tab-administration",
      "keydown",
      "Home",
    );

    assert.strictEqual(this.activeTab, "discover", "Home returns to the first tab");
    assert.dom("#csl-v3-tab-discover").isFocused();
  });
});
