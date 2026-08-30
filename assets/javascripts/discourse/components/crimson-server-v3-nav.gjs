import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CrimsonServerV3Nav extends Component {
  get viewer() {
    return this.args.viewer || {};
  }

  get activeTab() {
    return this.args.activeTab || "discover";
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
        {{on "click" (fn @onActivate "discover")}}
      >{{i18n "crimson_server_list.v3.discover"}}</button>

      {{#if this.viewer.logged_in}}
        <button
          id="csl-v3-tab-favorites"
          class={{if (eq this.activeTab "favorites") "is-active" ""}}
          type="button"
          role="tab"
          aria-controls="csl-v3-favorites"
          aria-selected={{if (eq this.activeTab "favorites") "true" "false"}}
          {{on "click" (fn @onActivate "favorites")}}
        >{{i18n "crimson_server_list.v3.favorites"}}</button>
        <button
          id="csl-v3-tab-owned"
          class={{if (eq this.activeTab "owned") "is-active" ""}}
          type="button"
          role="tab"
          aria-controls="csl-v3-owned"
          aria-selected={{if (eq this.activeTab "owned") "true" "false"}}
          {{on "click" (fn @onActivate "owned")}}
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
          {{on "click" (fn @onActivate "administration")}}
        >{{i18n "crimson_server_list.v3.administration"}}</button>
      {{/if}}
    </nav>
  </template>
}
