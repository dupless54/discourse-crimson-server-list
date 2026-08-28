import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class CrimsonServerFavoriteAction extends Component {
  @service siteSettings;

  @tracked favorited = false;
  @tracked isLoading = false;
  @tracked isBusy = false;
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

  get buttonLabel() {
    if (this.isBusy) {
      return i18n("crimson_server_list.favorites.saving");
    }

    return i18n(
      this.favorited
        ? "crimson_server_list.favorites.remove"
        : "crimson_server_list.favorites.add",
    );
  }

  async loadState() {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/follow.json`,
      );
      this.favorited = Boolean(response.favorited);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async toggleFavorite() {
    if (this.isBusy || this.isLoading) {
      return;
    }

    this.isBusy = true;
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/follow.json`,
        { type: this.favorited ? "DELETE" : "PUT" },
      );
      this.favorited = Boolean(response.favorited);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isBusy = false;
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

        <button
          class="csl-button csl-favorite-action__button {{if this.favorited "is-active" ""}}"
          type="button"
          disabled={{or this.isLoading this.isBusy}}
          aria-pressed={{this.favorited}}
          {{on "click" this.toggleFavorite}}
        >
          {{#if this.isLoading}}
            {{i18n "crimson_server_list.favorites.loading_state"}}
          {{else}}
            {{this.buttonLabel}}
          {{/if}}
        </button>

        {{#if this.errorMessage}}
          <p class="csl-notice csl-notice--error csl-favorite-action__error" role="alert">{{this.errorMessage}}</p>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
