import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CrimsonServerFavoriteAction extends Component {
  @service siteSettings;

  @tracked favorited = false;
  @tracked notificationsEnabled = false;
  @tracked isLoading = false;
  @tracked loadFailed = false;
  @tracked busyAction = "";
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.canRender && this.server.id) {
      void this.loadState();
    }
  }

  get server() {
    return this.args.model?.server || {};
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get canRender() {
    return Boolean(
      this.siteSettings.crimson_server_list_follows_enabled &&
        this.viewer.logged_in &&
        this.server.approved &&
        this.server.enabled,
    );
  }

  get isDisabled() {
    return this.isLoading || this.loadFailed || Boolean(this.busyAction);
  }

  get buttonLabel() {
    return i18n(
      this.favorited
        ? "crimson_server_list.favorites.remove"
        : "crimson_server_list.favorites.add",
    );
  }

  get notificationLabel() {
    return i18n(
      this.notificationsEnabled
        ? "crimson_server_list.notifications.disable_back_online"
        : "crimson_server_list.notifications.enable_back_online",
    );
  }

  @action
  async loadState() {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.loadFailed = false;
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/follow.json`,
      );
      this.favorited = Boolean(response.favorited);
      this.notificationsEnabled = Boolean(response.notifications_enabled);
    } catch (error) {
      this.loadFailed = true;
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async toggleFavorite() {
    if (this.isDisabled) {
      return;
    }

    this.busyAction = "favorite";
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/follow.json`,
        { type: this.favorited ? "DELETE" : "PUT" },
      );
      this.favorited = Boolean(response.favorited);
      this.notificationsEnabled = Boolean(response.notifications_enabled);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async toggleNotifications() {
    if (this.isDisabled || !this.favorited) {
      return;
    }

    this.busyAction = "notifications";
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/follow.json`,
        {
          type: "PUT",
          data: { notifications_enabled: !this.notificationsEnabled },
        },
      );
      this.favorited = Boolean(response.favorited);
      this.notificationsEnabled = Boolean(response.notifications_enabled);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
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
      <section class="csl-panel csl-favorite-action" aria-labelledby="csl-favorite-action-title">
        <div class="csl-favorite-action__copy">
          <p class="csl-eyebrow">{{i18n "crimson_server_list.favorites.eyebrow"}}</p>
          <h2 id="csl-favorite-action-title">{{i18n "crimson_server_list.favorites.detail_title"}}</h2>
          <p>{{i18n "crimson_server_list.favorites.detail_description"}}</p>
        </div>

        <div class="csl-favorite-action__controls">
          <DButton
            @action={{this.toggleFavorite}}
            @translatedLabel={{if this.isLoading (i18n "crimson_server_list.favorites.loading_state") this.buttonLabel}}
            @disabled={{this.isDisabled}}
            @isLoading={{eq this.busyAction "favorite"}}
            @ariaPressed={{this.favorited}}
            class="csl-button csl-favorite-action__button {{if this.favorited "is-active" ""}}"
          />

          {{#if this.favorited}}
            <div class="csl-notification-preference">
              <div class="csl-notification-preference__copy">
                <strong>{{i18n "crimson_server_list.notifications.preference_title"}}</strong>
                <span>{{i18n "crimson_server_list.notifications.preference_description"}}</span>
              </div>
              <DButton
                @action={{this.toggleNotifications}}
                @translatedLabel={{this.notificationLabel}}
                @disabled={{this.isDisabled}}
                @isLoading={{eq this.busyAction "notifications"}}
                @ariaPressed={{this.notificationsEnabled}}
                class="csl-button csl-notification-preference__button {{if this.notificationsEnabled "is-active" ""}}"
              />
            </div>
          {{/if}}
        </div>

        {{#if this.errorMessage}}
          <div class="csl-favorite-action__error csl-v3-panel-error">
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
            {{#if this.loadFailed}}
              <DButton
                @action={{this.loadState}}
                @label="crimson_server_list.owner_panel.retry"
                class="csl-button"
              />
            {{/if}}
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
