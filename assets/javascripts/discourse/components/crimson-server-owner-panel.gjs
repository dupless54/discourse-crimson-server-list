import Component from "@glimmer/component";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

const PAGE_SIZE = 12;

export default class CrimsonServerOwnerPanel extends Component {
  @tracked isLoaded = false;
  @tracked isLoading = false;
  @tracked isLoadingMore = false;
  @tracked servers = [];
  @tracked stats = null;
  @tracked pagination = null;
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.canRender) {
      scheduleOnce("afterRender", this, this.loadInitial);
    }
  }

  get canRender() {
    return Boolean(this.args.viewer?.logged_in);
  }

  get showingLabel() {
    return i18n("crimson_server_list.owner_panel.showing", {
      shown: this.servers.length,
      total: this.pagination?.total || 0,
    });
  }

  @action
  async loadInitial() {
    if (this.isLoaded || this.isLoading) {
      return;
    }

    await this.loadServers({ page: 1, append: false });
  }

  @action
  async retryLoad() {
    this.isLoaded = false;
    await this.loadServers({ page: 1, append: false });
  }

  @action
  async loadMore() {
    if (this.isLoadingMore || !this.pagination?.has_more) {
      return;
    }

    await this.loadServers({
      page: (this.pagination?.page || 1) + 1,
      append: true,
    });
  }

  async loadServers({ page, append }) {
    if (append) {
      this.isLoadingMore = true;
    } else {
      this.isLoading = true;
    }
    this.errorMessage = "";

    try {
      const response = await ajax("/crimson-server-list/me/servers.json", {
        data: { page, per_page: PAGE_SIZE },
      });
      const incoming = response.servers || [];

      if (append) {
        const byId = new Map(this.servers.map((server) => [server.id, server]));
        for (const server of incoming) {
          byId.set(server.id, server);
        }
        this.servers = [...byId.values()];
      } else {
        this.servers = incoming;
      }

      this.stats = response.stats || this.stats;
      this.pagination = response.pagination || this.pagination;
      this.isLoaded = true;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  publicationLabel(state) {
    const key = ["published", "pending", "disabled"].includes(state)
      ? state
      : "pending";
    return i18n(`crimson_server_list.owner_panel.publication_${key}`);
  }

  statusLabel(status) {
    const key = ["online", "offline", "maintenance"].includes(status)
      ? status
      : "unknown";
    return i18n(`crimson_server_list.owner_panel.status_${key}`);
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.owner_panel.generic_error")
    );
  }

  <template>
    {{#if this.canRender}}
      <section class="csl-panel csl-owner-panel" aria-labelledby="csl-owner-panel-title">
        <header class="csl-owner-panel__header csl-v3-panel-heading">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.owner_panel.eyebrow"}}</p>
            <h2 id="csl-owner-panel-title">{{i18n "crimson_server_list.owner_panel.title"}}</h2>
            <p>{{i18n "crimson_server_list.owner_panel.description"}}</p>
          </div>
          {{#if this.isLoaded}}
            <span class="csl-v3-panel-count">{{this.showingLabel}}</span>
          {{/if}}
        </header>

        {{#if this.errorMessage}}
          <div class="csl-owner-panel__error csl-v3-panel-error">
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
            <button class="csl-button" type="button" {{on "click" this.retryLoad}}>
              {{i18n "crimson_server_list.owner_panel.retry"}}
            </button>
          </div>
        {{else if this.isLoading}}
          <div class="csl-v3-tab-loading" role="status">
            <span class="csl-v3-loading-dot" aria-hidden="true"></span>
            {{i18n "crimson_server_list.owner_panel.loading"}}
          </div>
        {{else}}
          {{#if this.stats}}
            <div class="csl-owner-panel__stats" aria-label={{i18n "crimson_server_list.owner_panel.stats_label"}}>
              <div><strong>{{this.stats.total}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_total"}}</span></div>
              <div><strong>{{this.stats.published}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_published"}}</span></div>
              <div><strong>{{this.stats.pending}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_pending"}}</span></div>
              <div><strong>{{this.stats.disabled}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_disabled"}}</span></div>
              <div><strong>{{this.stats.online}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_online"}}</span></div>
              <div><strong>{{this.stats.verified}}</strong><span>{{i18n "crimson_server_list.owner_panel.stat_verified"}}</span></div>
            </div>
          {{/if}}

          {{#if this.servers.length}}
            <div class="csl-owner-grid">
              {{#each this.servers as |server|}}
                <article class="csl-owner-card csl-game--{{server.game_slug}}">
                  <div class="csl-owner-card__topline">
                    <span class="csl-owner-card__game">{{server.game.icon}} {{server.game.name}}</span>
                    <span class="csl-owner-card__publication csl-owner-card__publication--{{server.management.publication_state}}">
                      {{this.publicationLabel server.management.publication_state}}
                    </span>
                  </div>

                  <div class="csl-owner-card__title-row">
                    <h3><a href={{server.detail_url}}>{{server.name}}</a></h3>
                    <CrimsonVerifiedBadge @server={{server}} />
                  </div>

                  <p class="csl-owner-card__description">{{server.short_description}}</p>

                  <div class="csl-owner-card__meta">
                    <span class="csl-status csl-status--{{server.status}}"><i></i>{{this.statusLabel server.status}}</span>
                    {{#if server.address}}<span class="csl-owner-card__address">{{server.address}}</span>{{/if}}
                  </div>

                  <dl class="csl-owner-card__metrics">
                    <div><dt>{{i18n "crimson_server_list.owner_panel.votes"}}</dt><dd>{{server.vote_count}}</dd></div>
                    <div><dt>{{i18n "crimson_server_list.owner_panel.views"}}</dt><dd>{{server.view_count}}</dd></div>
                    <div><dt>{{i18n "crimson_server_list.owner_panel.reviews"}}</dt><dd>{{server.review_count}}</dd></div>
                  </dl>

                  {{#if server.management.edit_requires_approval}}
                    <p class="csl-owner-card__note">{{i18n "crimson_server_list.owner_panel.edit_approval_note"}}</p>
                  {{/if}}

                  <div class="csl-owner-card__actions">
                    <a class="csl-button csl-button--primary" href={{server.detail_url}}>{{i18n "crimson_server_list.owner_panel.manage"}}</a>
                  </div>
                </article>
              {{/each}}
            </div>

            {{#if this.pagination.has_more}}
              <div class="csl-owner-panel__more">
                <button class="csl-button" type="button" disabled={{this.isLoadingMore}} {{on "click" this.loadMore}}>
                  {{if this.isLoadingMore (i18n "crimson_server_list.owner_panel.loading_more") (i18n "crimson_server_list.owner_panel.load_more")}}
                </button>
              </div>
            {{/if}}
          {{else}}
            <div class="csl-empty csl-empty--compact csl-v3-tab-empty">
              <p>{{i18n "crimson_server_list.owner_panel.empty"}}</p>
            </div>
          {{/if}}
        {{/if}}
      </section>
    {{/if}}
  </template>
}
