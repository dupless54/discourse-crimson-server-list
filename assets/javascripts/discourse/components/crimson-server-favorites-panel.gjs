import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

export default class CrimsonServerFavoritesPanel extends Component {
  @service siteSettings;

  @tracked isOpen = false;
  @tracked isLoaded = false;
  @tracked isLoading = false;
  @tracked busyServerId = null;
  @tracked follows = [];
  @tracked errorMessage = "";

  get canRender() {
    return Boolean(
      this.siteSettings.crimson_server_list_follows_enabled &&
        this.args.viewer?.logged_in,
    );
  }

  get countLabel() {
    return i18n("crimson_server_list.favorites.count", {
      count: this.follows.length,
    });
  }

  @action
  async toggleOpen() {
    this.isOpen = !this.isOpen;
    this.errorMessage = "";

    if (this.isOpen && !this.isLoaded) {
      await this.loadFavorites();
    }
  }

  async loadFavorites() {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      const response = await ajax("/crimson-server-list/me/follows.json");
      this.follows = response.follows || [];
      this.isLoaded = true;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async toggleNotifications(follow) {
    if (this.busyServerId) {
      return;
    }

    this.busyServerId = follow.server_id;
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${follow.server_id}/follow.json`,
        {
          type: "PUT",
          data: { notifications_enabled: !follow.notifications_enabled },
        },
      );
      this.follows = this.follows.map((candidate) =>
        candidate.server_id === follow.server_id
          ? {
              ...candidate,
              notifications_enabled: Boolean(response.notifications_enabled),
            }
          : candidate,
      );
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyServerId = null;
    }
  }

  @action
  async removeFavorite(follow) {
    if (this.busyServerId) {
      return;
    }

    this.busyServerId = follow.server_id;
    this.errorMessage = "";

    try {
      await ajax(
        `/crimson-server-list/servers/${follow.server_id}/follow.json`,
        { type: "DELETE" },
      );
      this.follows = this.follows.filter(
        (candidate) => candidate.server_id !== follow.server_id,
      );
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyServerId = null;
    }
  }

  notificationAriaPressed(follow) {
    return follow.notifications_enabled ? "true" : "false";
  }

  notificationLabel(follow) {
    return i18n(
      follow.notifications_enabled
        ? "crimson_server_list.notifications.disable_back_online_short"
        : "crimson_server_list.notifications.enable_back_online_short",
    );
  }

  statusLabel(status) {
    const key = ["online", "offline", "maintenance"].includes(status)
      ? status
      : "unknown";
    return i18n(`crimson_server_list.favorites.status_${key}`);
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.favorites.generic_error")
    );
  }

  <template>
    {{#if this.canRender}}
      <section class="csl-panel csl-favorites-panel" aria-labelledby="csl-favorites-title">
        <header class="csl-favorites-panel__header">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.favorites.eyebrow"}}</p>
            <h2 id="csl-favorites-title">{{i18n "crimson_server_list.favorites.list_title"}}</h2>
            <p>{{i18n "crimson_server_list.favorites.list_description"}}</p>
          </div>

          <button
            class="csl-button csl-favorites-panel__toggle"
            type="button"
            aria-expanded={{this.isOpen}}
            {{on "click" this.toggleOpen}}
          >
            {{if this.isOpen (i18n "crimson_server_list.favorites.close") (i18n "crimson_server_list.favorites.open")}}
          </button>
        </header>

        {{#if this.isOpen}}
          {{#if this.errorMessage}}
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
          {{else if this.isLoading}}
            <p class="csl-empty csl-empty--compact" role="status">{{i18n "crimson_server_list.favorites.loading_list"}}</p>
          {{else}}
            <div class="csl-favorites-panel__summary">{{this.countLabel}}</div>

            {{#if this.follows.length}}
              <div class="csl-favorites-grid">
                {{#each this.follows as |follow|}}
                  <article class="csl-favorite-card csl-game--{{follow.server.game_slug}}">
                    <div class="csl-favorite-card__body">
                      <div class="csl-favorite-card__title-row">
                        <h3><a href={{follow.server.detail_url}}>{{follow.server.name}}</a></h3>
                        <CrimsonVerifiedBadge @server={{follow.server}} />
                      </div>
                      <p>{{follow.server.short_description}}</p>
                      <span class="csl-status csl-status--{{follow.server.status}}"><i></i>{{this.statusLabel follow.server.status}}</span>
                    </div>

                    <div class="csl-favorite-card__preference">
                      <span>{{i18n "crimson_server_list.notifications.preference_card"}}</span>
                      <button
                        class="csl-button csl-favorite-card__notification {{if follow.notifications_enabled "is-active" ""}}"
                        type="button"
                        disabled={{eq this.busyServerId follow.server_id}}
                        aria-pressed={{this.notificationAriaPressed follow}}
                        {{on "click" (fn this.toggleNotifications follow)}}
                      >
                        {{this.notificationLabel follow}}
                      </button>
                    </div>

                    <div class="csl-favorite-card__actions">
                      <a class="csl-button" href={{follow.server.detail_url}}>{{i18n "crimson_server_list.favorites.open_server"}}</a>
                      <button
                        class="csl-button csl-favorite-card__remove"
                        type="button"
                        disabled={{eq this.busyServerId follow.server_id}}
                        {{on "click" (fn this.removeFavorite follow)}}
                      >
                        {{if (eq this.busyServerId follow.server_id) (i18n "crimson_server_list.favorites.saving") (i18n "crimson_server_list.favorites.remove")}}
                      </button>
                    </div>
                  </article>
                {{/each}}
              </div>
            {{else}}
              <p class="csl-empty csl-empty--compact">{{i18n "crimson_server_list.favorites.empty"}}</p>
            {{/if}}
          {{/if}}
        {{/if}}
      </section>
    {{/if}}
  </template>
}
