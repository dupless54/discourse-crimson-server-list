import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class CrimsonServerCardFavorite extends Component {
  @service("crimson-server-favorites-state") favoritesState;

  @tracked loadFailed = false;
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.canRender) {
      void this.loadState();
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

  async loadState() {
    try {
      await this.favoritesState.ensureLoaded();
    } catch {
      this.loadFailed = true;
    }
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
      this.errorMessage =
        error?.jqXHR?.responseJSON?.errors?.join(" ") ||
        error?.responseJSON?.errors?.join(" ") ||
        i18n("crimson_server_list.favorites.generic_error");
    }
  }

  <template>
    {{#if this.canRender}}
      {{#unless this.loadFailed}}
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
        {{#if this.errorMessage}}
          <span class="sr-only" role="alert">{{this.errorMessage}}</span>
        {{/if}}
      {{/unless}}
    {{/if}}
  </template>
}
