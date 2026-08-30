import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { cancel, later, scheduleOnce } from "@ember/runloop";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import CrimsonServerCardFavorite from "./crimson-server-card-favorite";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

const DEFAULT_PER_PAGE = 24;
const SEARCH_DELAY_MS = 300;

export default class CrimsonServerDiscoveryPanel extends Component {
  @tracked servers = this.args.model?.servers || [];
  @tracked pagination = {
    page: 1,
    per_page: DEFAULT_PER_PAGE,
    total: Number(this.args.model?.stats?.server_count || this.servers.length),
    total_pages: 0,
    has_more: false,
  };
  @tracked selectedGame = "all";
  @tracked selectedTag = "";
  @tracked searchQuery = "";
  @tracked sortMode = "top";
  @tracked isLoading = false;
  @tracked isLoadingMore = false;
  @tracked busyServerId = null;
  @tracked announcement = "";
  @tracked errorMessage = "";

  requestSerial = 0;
  searchTimer = null;

  constructor(owner, args) {
    super(owner, args);

    if (typeof window === "undefined") {
      return;
    }

    const filters = new URLSearchParams(window.location.search);
    const game = filters.get("game");
    const tag = filters.get("tag");

    if (this.games.some((candidate) => candidate.slug === game)) {
      this.selectedGame = game;
    }

    if (this.tags.some((candidate) => candidate.slug === tag)) {
      this.selectedTag = tag;
    }

    scheduleOnce("afterRender", this, this.hideLegacyCatalogue);
    void this.loadDiscovery();
  }

  willDestroy() {
    if (this.searchTimer) {
      cancel(this.searchTimer);
      this.searchTimer = null;
    }

    super.willDestroy(...arguments);
  }

  hideLegacyCatalogue() {
    if (typeof document === "undefined") {
      return;
    }

    const legacyPage = document.querySelector(
      ".csl-route-wrap--paginated-discovery > .csl-page",
    );
    if (!legacyPage) {
      return;
    }

    for (const element of legacyPage.children) {
      if (
        element.matches(".csl-discovery, .csl-server-list, .csl-footnote")
      ) {
        element.hidden = true;
      }
    }
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get games() {
    return this.args.model?.games || [];
  }

  get tags() {
    return this.args.model?.tags || [];
  }

  get stats() {
    return this.args.model?.stats || {};
  }

  get rankedServers() {
    return this.servers.map((server, index) => ({ ...server, rank: index + 1 }));
  }

  get gameFilters() {
    return this.games.map((game) => ({
      ...game,
      filter_url: this.filterUrl(game.slug, this.selectedTag),
    }));
  }

  get tagFilters() {
    return this.tags.map((tag) => ({
      ...tag,
      filter_url: this.filterUrl(this.selectedGame, tag.slug),
    }));
  }

  get allGamesUrl() {
    return this.filterUrl("all", this.selectedTag);
  }

  get allTagsUrl() {
    return this.filterUrl(this.selectedGame, "");
  }

  get resultCount() {
    return Number(this.pagination?.total || 0);
  }

  get canLoadMore() {
    return Boolean(
      this.pagination?.has_more && !this.isLoading && !this.isLoadingMore,
    );
  }

  @action
  async selectGame(slug, event) {
    if (event?.metaKey || event?.ctrlKey || event?.shiftKey || event?.altKey) {
      return;
    }

    event?.preventDefault();
    this.selectedGame = slug;
    this.syncFilterUrl();
    await this.loadDiscovery();
  }

  @action
  async selectTag(slug, event) {
    if (event?.metaKey || event?.ctrlKey || event?.shiftKey || event?.altKey) {
      return;
    }

    event?.preventDefault();
    this.selectedTag = slug;
    this.syncFilterUrl();
    await this.loadDiscovery();
  }

  @action
  updateSearch(event) {
    this.searchQuery = event.currentTarget.value;

    if (this.searchTimer) {
      cancel(this.searchTimer);
    }

    this.searchTimer = later(this, () => {
      this.searchTimer = null;
      void this.loadDiscovery();
    }, SEARCH_DELAY_MS);
  }

  @action
  async updateSort(event) {
    this.sortMode = event.currentTarget.value;
    await this.loadDiscovery();
  }

  @action
  async loadMore() {
    if (!this.canLoadMore) {
      return;
    }

    await this.loadDiscovery({ append: true });
  }

  @action
  async retry() {
    await this.loadDiscovery();
  }

  @action
  async vote(server) {
    if (server.voted_today || this.busyServerId) {
      return;
    }

    this.busyServerId = server.id;
    this.announcement = "";
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${server.id}/vote.json`,
        { type: "POST" },
      );

      this.servers = this.servers.map((candidate) =>
        candidate.id === server.id
          ? {
              ...candidate,
              vote_count: response.vote_count,
              voted_today: true,
            }
          : candidate,
      );
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyServerId = null;
    }
  }

  async loadDiscovery({ append = false } = {}) {
    const requestId = ++this.requestSerial;
    const page = append ? Number(this.pagination?.page || 1) + 1 : 1;

    if (append) {
      this.isLoadingMore = true;
    } else {
      this.isLoading = true;
    }
    this.errorMessage = "";

    try {
      const response = await ajax(this.discoveryUrl(page));
      if (requestId !== this.requestSerial) {
        return;
      }

      const incoming = response.servers || [];
      this.servers = append
        ? this.appendUnique(this.servers, incoming)
        : incoming;
      this.pagination = response.pagination || {
        page,
        per_page: DEFAULT_PER_PAGE,
        total: this.servers.length,
        total_pages: 1,
        has_more: false,
      };
    } catch (error) {
      if (requestId === this.requestSerial) {
        this.errorMessage = this.errorText(error);
      }
    } finally {
      if (requestId === this.requestSerial) {
        this.isLoading = false;
        this.isLoadingMore = false;
      }
    }
  }

  discoveryUrl(page) {
    const params = new URLSearchParams();
    if (this.selectedGame !== "all") {
      params.set("game", this.selectedGame);
    }
    if (this.selectedTag) {
      params.set("tag", this.selectedTag);
    }

    const query = this.searchQuery.trim();
    if (query) {
      params.set("q", query);
    }

    params.set("sort", this.sortMode);
    params.set("page", String(page));
    params.set("per_page", String(DEFAULT_PER_PAGE));
    return `/crimson-server-list/discovery.json?${params.toString()}`;
  }

  appendUnique(current, incoming) {
    const knownIds = new Set(current.map((server) => server.id));
    return [
      ...current,
      ...incoming.filter((server) => !knownIds.has(server.id)),
    ];
  }

  filterUrl(gameSlug, tagSlug) {
    const filters = new URLSearchParams();
    if (gameSlug && gameSlug !== "all") {
      filters.set("game", gameSlug);
    }
    if (tagSlug) {
      filters.set("tag", tagSlug);
    }

    const query = filters.toString();
    return query ? `/servers?${query}` : "/servers";
  }

  syncFilterUrl() {
    if (typeof window === "undefined") {
      return;
    }

    const url = this.filterUrl(this.selectedGame, this.selectedTag);
    window.history.replaceState(window.history.state, "", url);
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      "Sunucu listesi güncellenemedi. Lütfen yeniden dene."
    );
  }

  <template>
    <section class="csl-discovery-shell" aria-label="Sunucu keşfi">
      <section class="csl-discovery" aria-label="Sunucu filtreleri">
        <div class="csl-game-filter" role="list" aria-label="Oyunlar">
          <a href={{this.allGamesUrl}} class={{if (eq this.selectedGame "all") "is-active" ""}} {{on "click" (fn this.selectGame "all")}}>
            <span class="csl-game-filter__all">∞</span>
            <strong>Tümü</strong>
            <small>{{this.stats.server_count}}</small>
          </a>
          {{#each this.gameFilters as |game|}}
            <a href={{game.filter_url}} class="csl-game--{{game.slug}} {{if (eq this.selectedGame game.slug) "is-active" ""}}" {{on "click" (fn this.selectGame game.slug)}}>
              <span>{{game.icon}}</span>
              <strong>{{game.name}}</strong>
              <small>{{game.server_count}}</small>
            </a>
          {{/each}}
        </div>

        {{#if this.tags.length}}
          <div class="csl-tag-filter" role="list" aria-label="Sunucu etiketleri">
            <strong>Etiketler</strong>
            <a href={{this.allTagsUrl}} class={{if this.selectedTag "" "is-active"}} {{on "click" (fn this.selectTag "")}}>Tümü</a>
            {{#each this.tagFilters as |tag|}}
              <a href={{tag.filter_url}} class={{if (eq this.selectedTag tag.slug) "is-active" ""}} {{on "click" (fn this.selectTag tag.slug)}}>
                #{{tag.name}} <small>{{tag.server_count}}</small>
              </a>
            {{/each}}
          </div>
        {{/if}}

        <div class="csl-toolbar">
          <label class="csl-search">
            <span class="sr-only">Sunucu ara</span>
            <input type="search" value={{this.searchQuery}} placeholder="Sunucu adı, oyun veya etiket ara…" {{on "input" this.updateSearch}} />
          </label>
          <label class="csl-sort">
            <span>Sırala</span>
            <select value={{this.sortMode}} {{on "change" this.updateSort}}>
              <option value="top">En yüksek oy</option>
              <option value="online">Çevrimiçi</option>
              <option value="players">Oyuncu sayısı</option>
              <option value="rating">En iyi değerlendirme</option>
              <option value="new">En yeni</option>
            </select>
          </label>
        </div>
      </section>

      <div class="csl-discovery-status" aria-live="polite">
        <span>{{this.resultCount}} sunucu bulundu</span>
        {{#if this.isLoading}}<span>Sonuçlar güncelleniyor…</span>{{/if}}
      </div>

      {{#if this.announcement}}
        <p class="csl-notice csl-notice--success" role="status">{{this.announcement}}</p>
      {{/if}}
      {{#if this.errorMessage}}
        <div class="csl-notice csl-notice--error csl-discovery-error" role="alert">
          <span>{{this.errorMessage}}</span>
          <button class="csl-button" type="button" {{on "click" this.retry}}>Yeniden dene</button>
        </div>
      {{/if}}

      <section class="csl-server-list" aria-live="polite" aria-busy={{if this.isLoading "true" "false"}}>
        {{#each this.rankedServers as |server|}}
          <article class="csl-server-card csl-game--{{server.game_slug}}">
            <div class="csl-rank" aria-label="Sıra {{server.rank}}">
              <span>#</span>{{server.rank}}
            </div>

            <div class="csl-server-card__visual">
              {{#if server.banner_url}}
                {{#if server.website_url}}
                  <a
                    class="csl-ad-banner"
                    href={{server.website_url}}
                    target="_blank"
                    rel="noopener noreferrer nofollow ugc sponsored"
                    aria-label="{{server.name}} web sitesini aç"
                  ><img src={{server.banner_url}} alt="{{server.name}} reklam bannerı" loading="lazy" /></a>
                {{else}}
                  <div class="csl-ad-banner"><img src={{server.banner_url}} alt="{{server.name}} reklam bannerı" loading="lazy" /></div>
                {{/if}}
              {{else}}
                <a class="csl-server-card__fallback" href={{server.detail_url}} aria-label="{{server.name}} tanıtımını aç">
                  <span aria-hidden="true">{{server.game.icon}}</span>
                  <small>{{server.game.name}}</small>
                </a>
              {{/if}}
            </div>

            <div class="csl-server-card__body">
              <header>
                <div>
                  <div class="csl-server-card__title-row">
                    <h2><a href={{server.detail_url}}>{{server.name}}</a></h2>
                    <CrimsonVerifiedBadge @server={{server}} />
                    <CrimsonServerCardFavorite @server={{server}} @viewer={{this.viewer}} />
                  </div>
                  <p>{{server.short_description}}</p>
                </div>
                {{#if server.featured}}<span class="csl-featured">ÖNE ÇIKAN</span>{{/if}}
              </header>

              <div class="csl-meta">
                <span class="csl-status csl-status--{{server.status}}"><i></i>{{server.status_label}}</span>
                <a class="csl-category-chip csl-game--{{server.game_slug}}" href={{server.game.category_url}} {{on "click" (fn this.selectGame server.game_slug)}}>{{server.game.icon}} {{server.game.name}}</a>
                {{#if server.language}}<span>{{server.language}}</span>{{/if}}
                {{#if server.version}}<span>{{server.version}}</span>{{/if}}
                {{#if server.mode}}<span>{{server.mode}}</span>{{/if}}
              </div>

              {{#if server.tag_rows.length}}
                <div class="csl-server-tags" aria-label="Sunucu etiketleri">
                  {{#each server.tag_rows as |tag|}}
                    <a href={{tag.url}} {{on "click" (fn this.selectTag tag.slug)}}>#{{tag.name}}</a>
                  {{/each}}
                </div>
              {{/if}}

              <a class="csl-description-link" href={{server.detail_url}}>Tanıtımı, yorumları ve puanları aç →</a>

              <footer>
                {{#if server.owner}}
                  <div class="csl-owner">
                    {{#if server.owner.avatar_url}}
                      <a
                        class="csl-avatar-link duc-avatar-frame-target trigger-user-card"
                        data-user-card={{server.owner.username}}
                        href={{server.owner.profile_url}}
                        aria-label="@{{server.owner.username}} kullanıcı kartını aç"
                      >
                        <img class="avatar" src={{server.owner.avatar_url}} alt="" loading="lazy" />
                      </a>
                    {{/if}}
                    <a
                      class="csl-owner__identity trigger-user-card"
                      data-user-card={{server.owner.username}}
                      href={{server.owner.profile_url}}
                    >@{{server.owner.username}} tarafından eklendi</a>
                  </div>
                {{/if}}
                <nav class="csl-server-card__actions" aria-label="Sunucu bağlantıları">
                  <a class="csl-card-action--detail" href={{server.detail_url}}>
                    {{dIcon "circle-info"}}
                    <span>Detayı Aç</span>
                  </a>
                  {{#if server.website_url}}
                    <a href={{server.website_url}} target="_blank" rel="noopener noreferrer nofollow ugc">
                      {{dIcon "globe"}}
                      <span>Web</span>
                    </a>
                  {{/if}}
                  {{#if server.discord_url}}
                    <a href={{server.discord_url}} target="_blank" rel="noopener noreferrer nofollow ugc">
                      {{dIcon "fab-discord"}}
                      <span>Discord</span>
                    </a>
                  {{/if}}
                </nav>
              </footer>
            </div>

            <aside class="csl-server-card__score">
              <div class="csl-players">
                {{#if server.supports_player_count}}
                  <strong>{{server.players_online}}</strong>
                  <span>{{#if server.players_max}}/ {{server.players_max}} oyuncu{{else}}canlı oyuncu{{/if}}</span>
                {{else}}
                  <strong>{{if (eq server.status "online") "Açık" "—"}}</strong>
                  <span>erişim durumu</span>
                {{/if}}
              </div>
              <div class="csl-votes">
                <strong>{{server.vote_count}}</strong>
                <span>oy</span>
              </div>
              <div class="csl-rating">
                <strong>★ {{server.average_rating}}</strong>
                <span>{{server.review_count}} değerlendirme</span>
              </div>
              {{#if this.viewer.can_vote}}
                <button
                  class="csl-vote-button {{if server.voted_today "is-voted" ""}}"
                  type="button"
                  disabled={{server.voted_today}}
                  aria-pressed={{if server.voted_today "true" "false"}}
                  {{on "click" (fn this.vote server)}}
                >
                  {{dIcon "thumbs-up"}}
                  <span>{{if server.voted_today "Bugün oylandı" "Oy ver"}}</span>
                </button>
              {{else if this.viewer.logged_in}}
                <span class="csl-vote-button is-disabled">Oylama kapalı</span>
              {{else}}
                <a class="csl-vote-button" href="/login?return_path=%2Fservers">
                  {{dIcon "thumbs-up"}}
                  <span>Oy vermek için giriş yap</span>
                </a>
              {{/if}}
            </aside>
          </article>
        {{else}}
          {{#unless this.isLoading}}
            <div class="csl-empty">
              <span aria-hidden="true">⌁</span>
              <h2>Eşleşen sunucu bulunamadı</h2>
              <p>Arama metnini, oyun kategorisini veya etiket filtresini değiştirmeyi dene.</p>
            </div>
          {{/unless}}
        {{/each}}
      </section>

      {{#if this.pagination.has_more}}
        <div class="csl-form__actions csl-discovery-load-more">
          <button class="csl-button csl-button--primary" type="button" disabled={{this.isLoadingMore}} {{on "click" this.loadMore}}>
            {{if this.isLoadingMore "Daha fazla sunucu yükleniyor…" "Daha fazla sunucu göster"}}
          </button>
        </div>
      {{/if}}

      <p class="csl-footnote">
        Canlı durum sorguları sayfa isteklerinden bağımsız Sidekiq işleriyle,
        yalnızca izin verilen genel internet adresi ve portlara uygulanır.
      </p>
    </section>
  </template>
}
