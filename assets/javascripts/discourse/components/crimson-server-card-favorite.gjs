import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class CrimsonServerCardFavorite extends Component {
  @service("crimson-server-favorites-state") favoritesState;

  @tracked loadFailed = false;
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.canRender) {
      schedule("afterRender", () => void this.loadState());
    }
  }

  get server() {
    return this.args.server || {};
  }

  get viewer() {
    return this.args.viewer || {};
  }

  get canRender() {
    return Boolean(this.viewer.logged_in && this.favoritesState.enabled);
  }

  get isFavorited() {
    return this.favoritesState.isFavorite(this.server.id);
  }

  get isBusy() {
    return (
      !this.favoritesState.isLoaded ||
      this.favoritesState.isBusy(this.server.id)
    );
  }

  get label() {
    return i18n(
      this.isFavorited
        ? "crimson_server_list.favorites.remove"
        : "crimson_server_list.favorites.add",
    );
  }

  get retryLabel() {
    return i18n("crimson_server_list.favorites.retry_loading");
  }

  async loadState() {
    this.loadFailed = false;
    this.errorMessage = "";

    try {
      await this.favoritesState.ensureLoaded();
    } catch (error) {
      this.loadFailed = true;
      this.errorMessage = this.errorText(error);
    }
  }

  @action
  async retryLoadState() {
    await this.loadState();
  }

  @action
  async toggleFavorite() {
    if (this.isBusy) {
      return;
    }

    this.errorMessage = "";

    try {
      await this.favoritesState.toggle(this.server.id);
    } catch (error) {
      this.errorMessage = this.errorText(error);
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
      {{#if this.loadFailed}}
        <button
          class="csl-card-favorite csl-card-favorite--retry"
          type="button"
          data-server-id={{this.server.id}}
          aria-label={{this.retryLabel}}
          title={{this.retryLabel}}
          {{on "click" this.retryLoadState}}
        >
          {{dIcon "star"}}
        </button>
      {{else}}
        <button
          class="csl-card-favorite {{if this.isFavorited "is-active" ""}}"
          type="button"
          data-server-id={{this.server.id}}
          disabled={{this.isBusy}}
          aria-label={{this.label}}
          title={{this.label}}
          aria-pressed={{if this.isFavorited "true" "false"}}
          {{on "click" this.toggleFavorite}}
        >
          {{dIcon "star"}}
        </button>
      {{/if}}

      {{#if this.errorMessage}}
        <span class="sr-only" role="alert">{{this.errorMessage}}</span>
      {{/if}}
    {{/if}}
  </template>
}
