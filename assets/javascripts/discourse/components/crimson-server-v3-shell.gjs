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
  @tracked visitedTabs = new Set(["discover"]);

  constructor(owner, args) {
    super(owner, args);
    const initialTab = this.tabFromLocation();
    this.activeTab = initialTab;
    this.visitedTabs = new Set(["discover", initialTab]);
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get hasVisitedFavorites() {
    return this.visitedTabs.has("favorites");
  }

  get hasVisitedOwned() {
    return this.visitedTabs.has("owned");
  }

  get hasVisitedAdministration() {
    return this.visitedTabs.has("administration");
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

  syncLocation(tab) {
    if (typeof window === "undefined") {
      return;
    }

    const hash = TAB_HASHES[tab] || TAB_HASHES.discover;
    const nextUrl = `${window.location.pathname}${window.location.search}${hash}`;
    window.history.replaceState(window.history.state, "", nextUrl);
  }

  @action
  activateTab(tab) {
    if (!this.isAllowed(tab)) {
      return;
    }

    this.activeTab = tab;
    this.visitedTabs = new Set([...this.visitedTabs, tab]);
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

      <section
        id="csl-v3-discover"
        class="csl-v3-route-section csl-v3-route-section--discover"
        aria-labelledby="csl-v3-tab-discover"
        hidden={{if (eq this.activeTab "discover") false true}}
      >
        <CrimsonServerList
          @model={{@model}}
          @onOpenFavorites={{this.openFavorites}}
        />
        <CrimsonServerFeaturedStrip @servers={{@model.servers}} />
        <CrimsonServerDiscoveryPanel @model={{@model}} />
      </section>

      {{#if this.viewer.logged_in}}
        {{#if this.hasVisitedFavorites}}
          <section
            id="csl-v3-favorites"
            class="csl-v3-route-section csl-v3-route-section--secondary"
            aria-labelledby="csl-v3-tab-favorites"
            hidden={{if (eq this.activeTab "favorites") false true}}
          >
            <CrimsonServerFavoritesPanel @viewer={{this.viewer}} />
          </section>
        {{/if}}

        {{#if this.hasVisitedOwned}}
          <section
            id="csl-v3-owned"
            class="csl-v3-route-section csl-v3-route-section--secondary"
            aria-labelledby="csl-v3-tab-owned"
            hidden={{if (eq this.activeTab "owned") false true}}
          >
            <CrimsonServerOwnerPanel @viewer={{this.viewer}} />
          </section>
        {{/if}}
      {{/if}}

      {{#if this.viewer.is_admin}}
        {{#if this.hasVisitedAdministration}}
          <section
            id="csl-v3-admin"
            class="csl-v3-route-section csl-v3-route-section--secondary csl-v3-admin-stack"
            aria-labelledby="csl-v3-tab-administration"
            hidden={{if (eq this.activeTab "administration") false true}}
          >
            <CrimsonServerApprovalPanel @model={{@model}} />
            <CrimsonReportModeration @viewer={{this.viewer}} />
          </section>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
