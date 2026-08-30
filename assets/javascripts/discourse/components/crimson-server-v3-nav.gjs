import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CrimsonServerV3Nav extends Component {
  @tracked activeTab = "discover";

  get viewer() {
    return this.args.viewer || {};
  }

  get navigationLabel() {
    return i18n("crimson_server_list.v3.navigation_label");
  }

  get discoverLabel() {
    return i18n("crimson_server_list.v3.discover");
  }

  get favoritesLabel() {
    return i18n("crimson_server_list.v3.favorites");
  }

  get ownedLabel() {
    return i18n("crimson_server_list.v3.owned");
  }

  get administrationLabel() {
    return i18n("crimson_server_list.v3.administration");
  }

  @action
  activate(tab) {
    this.activeTab = tab;
  }

  <template>
    <nav class="csl-v3-nav" aria-label={{this.navigationLabel}}>
      <a
        class={{if (eq this.activeTab "discover") "is-active" ""}}
        href="#csl-v3-discover"
        {{on "click" (fn this.activate "discover")}}
      >{{this.discoverLabel}}</a>

      {{#if this.viewer.logged_in}}
        <a
          class={{if (eq this.activeTab "favorites") "is-active" ""}}
          href="#csl-v3-favorites"
          {{on "click" (fn this.activate "favorites")}}
        >{{this.favoritesLabel}}</a>
        <a
          class={{if (eq this.activeTab "owned") "is-active" ""}}
          href="#csl-v3-owned"
          {{on "click" (fn this.activate "owned")}}
        >{{this.ownedLabel}}</a>
      {{/if}}

      {{#if this.viewer.is_admin}}
        <a
          class={{if (eq this.activeTab "administration") "is-active" ""}}
          href="#csl-v3-admin"
          {{on "click" (fn this.activate "administration")}}
        >{{this.administrationLabel}}</a>
      {{/if}}
    </nav>
  </template>
}
