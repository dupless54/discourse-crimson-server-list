import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CrimsonServerV3Nav extends Component {
  get viewer() {
    return this.args.viewer || {};
  }

  get activeTab() {
    return this.args.activeTab || "discover";
  }

  get availableTabs() {
    const tabs = ["discover"];

    if (this.viewer.logged_in) {
      tabs.push("favorites", "owned");
    }

    if (this.viewer.is_admin) {
      tabs.push("administration");
    }

    return tabs;
  }

  @action
  navigateTabs(tab, event) {
    const index = this.availableTabs.indexOf(tab);
    if (index === -1) {
      return;
    }

    let nextIndex;

    if (event.key === "ArrowLeft") {
      nextIndex =
        (index - 1 + this.availableTabs.length) % this.availableTabs.length;
    } else if (event.key === "ArrowRight") {
      nextIndex = (index + 1) % this.availableTabs.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = this.availableTabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    const nextTab = this.availableTabs[nextIndex];
    this.args.onActivate?.(nextTab);

    schedule("afterRender", () => {
      document.getElementById(`csl-v3-tab-${nextTab}`)?.focus();
    });
  }

  <template>
    <nav
      class="csl-v3-nav"
      aria-label={{i18n "crimson_server_list.v3.navigation_label"}}
      role="tablist"
    >
      <button
        id="csl-v3-tab-discover"
        class={{if (eq this.activeTab "discover") "is-active" ""}}
        type="button"
        role="tab"
        aria-controls="csl-v3-discover"
        aria-selected={{if (eq this.activeTab "discover") "true" "false"}}
        tabindex={{if (eq this.activeTab "discover") "0" "-1"}}
        {{on "click" (fn @onActivate "discover")}}
        {{on "keydown" (fn this.navigateTabs "discover")}}
      >{{i18n "crimson_server_list.v3.discover"}}</button>

      {{#if this.viewer.logged_in}}
        <button
          id="csl-v3-tab-favorites"
          class={{if (eq this.activeTab "favorites") "is-active" ""}}
          type="button"
          role="tab"
          aria-controls="csl-v3-favorites"
          aria-selected={{if (eq this.activeTab "favorites") "true" "false"}}
          tabindex={{if (eq this.activeTab "favorites") "0" "-1"}}
          {{on "click" (fn @onActivate "favorites")}}
          {{on "keydown" (fn this.navigateTabs "favorites")}}
        >{{i18n "crimson_server_list.v3.favorites"}}</button>
        <button
          id="csl-v3-tab-owned"
          class={{if (eq this.activeTab "owned") "is-active" ""}}
          type="button"
          role="tab"
          aria-controls="csl-v3-owned"
          aria-selected={{if (eq this.activeTab "owned") "true" "false"}}
          tabindex={{if (eq this.activeTab "owned") "0" "-1"}}
          {{on "click" (fn @onActivate "owned")}}
          {{on "keydown" (fn this.navigateTabs "owned")}}
        >{{i18n "crimson_server_list.v3.owned"}}</button>
      {{/if}}

      {{#if this.viewer.is_admin}}
        <button
          id="csl-v3-tab-administration"
          class={{if (eq this.activeTab "administration") "is-active" ""}}
          type="button"
          role="tab"
          aria-controls="csl-v3-admin"
          aria-selected={{if (eq this.activeTab "administration") "true" "false"}}
          tabindex={{if (eq this.activeTab "administration") "0" "-1"}}
          {{on "click" (fn @onActivate "administration")}}
          {{on "keydown" (fn this.navigateTabs "administration")}}
        >{{i18n "crimson_server_list.v3.administration"}}</button>
      {{/if}}
    </nav>
  </template>
}
