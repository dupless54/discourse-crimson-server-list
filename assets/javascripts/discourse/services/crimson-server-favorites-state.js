import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class CrimsonServerFavoritesState extends Service {
  @service siteSettings;

  @tracked favoriteServerIds = [];
  @tracked busyServerIds = [];
  @tracked isLoaded = false;

  loadPromise = null;

  get enabled() {
    return Boolean(this.siteSettings.crimson_server_list_follows_enabled);
  }

  isFavorite(serverId) {
    return this.favoriteServerIds.includes(Number(serverId));
  }

  isBusy(serverId) {
    return this.busyServerIds.includes(Number(serverId));
  }

  async ensureLoaded() {
    if (!this.enabled || this.isLoaded) {
      return;
    }

    if (this.loadPromise) {
      return this.loadPromise;
    }

    this.loadPromise = this.loadFavorites();

    try {
      await this.loadPromise;
    } finally {
      this.loadPromise = null;
    }
  }

  async toggle(serverId) {
    const normalizedId = Number(serverId);
    if (!this.enabled || this.isBusy(normalizedId)) {
      return;
    }

    await this.ensureLoaded();

    const wasFavorite = this.isFavorite(normalizedId);
    this.busyServerIds = [...this.busyServerIds, normalizedId];

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${normalizedId}/follow.json`,
        { type: wasFavorite ? "DELETE" : "PUT" },
      );

      if (response.favorited) {
        this.favoriteServerIds = Array.from(
          new Set([...this.favoriteServerIds, normalizedId]),
        );
      } else {
        this.favoriteServerIds = this.favoriteServerIds.filter(
          (candidate) => candidate !== normalizedId,
        );
      }

      return response;
    } finally {
      this.busyServerIds = this.busyServerIds.filter(
        (candidate) => candidate !== normalizedId,
      );
    }
  }

  async loadFavorites() {
    const response = await ajax("/crimson-server-list/me/follows.json");
    this.favoriteServerIds = (response.follows || []).map((follow) =>
      Number(follow.server_id),
    );
    this.isLoaded = true;
  }
}
