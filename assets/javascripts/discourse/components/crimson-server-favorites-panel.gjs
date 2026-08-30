import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

export default class CrimsonServerFavoritesPanel extends Component {
  @service siteSettings;

  @tracked isLoaded = false;
  @tracked isLoading = false;
  @tracked busyKey = "";
  @tracked follows = [];
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.canRender) {
      scheduleOnce("afterRender", this, this.loadFavorites);
    }
  }

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

  get mutationBusy() {
    return Boolean(this.busyKey);
  }

  @action
  async loadFavorites() {
    if (this.isLoading) {
      return;
    }

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
    if (this.mutationBusy) {
      return;
    }

    this.busyKey = `notification-${follow.server_id}`;
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
      this.busyKey = "";
    }
  }

  @action
  async removeFavorite(follow) {
    if (this.mutationBusy) {
      return;
    }

    this.busyKey = `remove-${follow.server_id}`;
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
      this.busyKey = "";
    }
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
        <header class="csl-favorites-panel__header csl-v3-panel-heading">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.favorites.eyebrow"}}</p>
            <h2 id="csl-favorites-title">{{i18n "crimson_server_list.favorites.list_title"}}</h2>
            <p>{{i18n "crimson_server_list.favorites.list_description"}}</p>
          </div>
          {{#if this.isLoaded}}
            <span class="csl-v3-panel-count">{{this.countLabel}}</span>
          {{/if}}
        </header>

        {{#if this.errorMessage}}
          <div class="csl-v3-panel-error">
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
            {{#unless this.isLoaded}}
              <DButton
                @action={{this.loadFavorites}}
                @label="crimson_server_list.owner_panel.retry"
                class="csl-button"
              />
            {{/unless}}
          </div>
        {{else if this.isLoading}}
          <div class="csl-v3-tab-loading" role="status">
            <span class="csl-v3-loading-dot" aria-hidden="true"></span>
            {{i18n "crimson_server_list.favorites.loading_list"}}
          </div>
        {{else if this.follows.length}}
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
                  <DButton
                    @action={{fn this.toggleNotifications follow}}
                    @translatedLabel={{this.notificationLabel follow}}
                    @disabled={{this.mutationBusy}}
                    @isLoading={{eq this.busyKey (concat "notification-" follow.server_id)}}
                    @ariaPressed={{follow.notifications_enabled}}
                    class="csl-button csl-favorite-card__notification {{if follow.notifications_enabled "is-active" ""}}"
                  />
                </div>

                <div class="csl-favorite-card__actions">
                  <a class="csl-button csl-button--primary" href={{follow.server.detail_url}}>{{i18n "crimson_server_list.favorites.open_server"}}</a>
                  <DButton
                    @action={{fn this.removeFavorite follow}}
                    @label="crimson_server_list.favorites.remove"
                    @disabled={{this.mutationBusy}}
                    @isLoading={{eq this.busyKey (concat "remove-" follow.server_id)}}
                    class="csl-button csl-favorite-card__remove"
                  />
                </div>
              </article>
            {{/each}}
          </div>
        {{else}}
          <div class="csl-empty csl-empty--compact csl-v3-tab-empty">
            <p>{{i18n "crimson_server_list.favorites.empty"}}</p>
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
