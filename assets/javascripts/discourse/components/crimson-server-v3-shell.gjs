import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { eq } from "discourse/truth-helpers";
import CrimsonReportModeration from "./crimson-report-moderation";
import CrimsonServerApprovalPanel from "./crimson-server-approval-panel";
import CrimsonServerDiscoveryPanel from "./crimson-server-discovery-panel";
import CrimsonServerFeaturedStrip from "./crimson-server-featured-strip";
import CrimsonServerFavoritesPanel from "./crimson-server-favorites-panel";
import CrimsonServerList from "./crimson-server-list";
import CrimsonServerOwnerPanel from "./crimson-server-owner-panel";
import CrimsonServerV3Nav from "./crimson-server-v3-nav";

const TAB_HASHES = {
  discover: "#discover",
  favorites: "#favorites",
  owned: "#owned",
  administration: "#administration",
};

const HASH_TABS = {
  "#discover": "discover",
  "#csl-v3-discover": "discover",
  "#favorites": "favorites",
  "#csl-v3-favorites": "favorites",
  "#owned": "owned",
  "#csl-v3-owned": "owned",
  "#administration": "administration",
  "#csl-v3-admin": "administration",
};

export default class CrimsonServerV3Shell extends Component {
  @tracked activeTab = "discover";

  constructor(owner, args) {
    super(owner, args);
    this.activeTab = this.tabFromLocation();

    if (typeof window !== "undefined") {
      window.addEventListener("popstate", this.handleLocationChange);
      window.addEventListener("hashchange", this.handleLocationChange);
    }
  }

  willDestroy() {
    if (typeof window !== "undefined") {
      window.removeEventListener("popstate", this.handleLocationChange);
      window.removeEventListener("hashchange", this.handleLocationChange);
    }

    super.willDestroy(...arguments);
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  isAllowed(tab) {
    if (tab === "discover") {
      return true;
    }

    if (tab === "favorites" || tab === "owned") {
      return Boolean(this.viewer.logged_in);
    }

    if (tab === "administration") {
      return Boolean(this.viewer.is_admin);
    }

    return false;
  }

  tabFromLocation() {
    if (typeof window === "undefined") {
      return "discover";
    }

    const requested = HASH_TABS[window.location.hash];
    return requested && this.isAllowed(requested) ? requested : "discover";
  }

  syncLocation(tab, { replace = false } = {}) {
    if (typeof window === "undefined") {
      return;
    }

    const hash = TAB_HASHES[tab] || TAB_HASHES.discover;
    const nextUrl = `${window.location.pathname}${window.location.search}${hash}`;
    const method = replace ? "replaceState" : "pushState";
    window.history[method](window.history.state, "", nextUrl);
  }

  @action
  handleLocationChange() {
    const nextTab = this.tabFromLocation();
    if (nextTab !== this.activeTab) {
      this.activeTab = nextTab;
    }
  }

  @action
  activateTab(tab) {
    if (!this.isAllowed(tab) || this.activeTab === tab) {
      return;
    }

    this.activeTab = tab;
    this.syncLocation(tab);
  }

  @action
  openFavorites() {
    this.activateTab("favorites");
  }

  <template>
    <div class="csl-v3-shell">
      <CrimsonServerV3Nav
        @viewer={{this.viewer}}
        @activeTab={{this.activeTab}}
        @onActivate={{this.activateTab}}
      />

      {{#if (eq this.activeTab "discover")}}
        <section
          id="csl-v3-discover"
          class="csl-v3-route-section csl-v3-route-section--discover is-active"
          aria-labelledby="csl-v3-tab-discover"
        >
          <CrimsonServerList
            @model={{@model}}
            @onOpenFavorites={{this.openFavorites}}
          />
          <CrimsonServerFeaturedStrip @servers={{@model.servers}} />
          <CrimsonServerDiscoveryPanel @model={{@model}} />
        </section>
      {{/if}}

      {{#if (eq this.activeTab "favorites")}}
        {{#if this.viewer.logged_in}}
          <section
            id="csl-v3-favorites"
            class="csl-v3-route-section csl-v3-route-section--secondary is-active"
            aria-labelledby="csl-v3-tab-favorites"
          >
            <CrimsonServerFavoritesPanel @viewer={{this.viewer}} />
          </section>
        {{/if}}
      {{/if}}

      {{#if (eq this.activeTab "owned")}}
        {{#if this.viewer.logged_in}}
          <section
            id="csl-v3-owned"
            class="csl-v3-route-section csl-v3-route-section--secondary is-active"
            aria-labelledby="csl-v3-tab-owned"
          >
            <CrimsonServerOwnerPanel @viewer={{this.viewer}} />
          </section>
        {{/if}}
      {{/if}}

      {{#if (eq this.activeTab "administration")}}
        {{#if this.viewer.is_admin}}
          <section
            id="csl-v3-admin"
            class="csl-v3-route-section csl-v3-route-section--secondary csl-v3-admin-stack is-active"
            aria-labelledby="csl-v3-tab-administration"
          >
            <CrimsonServerApprovalPanel @model={{@model}} />
            <CrimsonReportModeration @viewer={{this.viewer}} />
          </section>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
