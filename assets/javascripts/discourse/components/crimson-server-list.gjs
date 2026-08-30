import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CrimsonServerFormModal from "./modal/crimson-server-form";

export default class CrimsonServerList extends Component {
  @service modal;

  @tracked stats = { ...(this.args.model?.stats || {}) };

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get games() {
    return this.args.model?.games || [];
  }

  @action
  openSubmit() {
    this.modal.show(CrimsonServerFormModal, {
      model: {
        mode: "create",
        games: this.games,
        onSubmitted: this.handleSubmitted,
      },
    });
  }

  @action
  handleSubmitted(response) {
    if (response?.pending || !response?.server) {
      return;
    }

    const existingServers = this.args.model?.servers || [];
    const gameWasEmpty = !existingServers.some(
      (server) => server.game_slug === response.server.game_slug,
    );

    this.stats = {
      ...this.stats,
      server_count: Number(this.stats.server_count || 0) + 1,
      game_count: Number(this.stats.game_count || 0) + (gameWasEmpty ? 1 : 0),
    };
  }

  <template>
    <main class="csl-page csl-v3-overview">
      <section class="csl-hero" aria-labelledby="csl-title">
        <div class="csl-hero__copy">
          <div class="csl-v3-hero-kicker">
            <span class="csl-v3-hero-kicker__dot" aria-hidden="true"></span>
            {{i18n "crimson_server_list.v3.hero_eyebrow"}}
          </div>
          <h1 id="csl-title">{{i18n "crimson_server_list.v3.hero_title"}}</h1>
          <p>{{i18n "crimson_server_list.v3.hero_description"}}</p>

          <div class="csl-v3-hero-pills" aria-label={{i18n "crimson_server_list.v3.hero_highlights_label"}}>
            <span>{{dIcon "shield-halved"}} {{i18n "crimson_server_list.v3.hero_safe"}}</span>
            <span>{{dIcon "arrows-rotate"}} {{i18n "crimson_server_list.v3.hero_live"}}</span>
            <span>{{dIcon "comments"}} {{i18n "crimson_server_list.v3.hero_community"}}</span>
          </div>
        </div>

        <div class="csl-hero__actions">
          {{#if this.viewer.can_submit}}
            <button class="csl-button csl-button--primary csl-v3-hero-primary" type="button" {{on "click" this.openSubmit}}>
              {{dIcon "plus"}}
              <span>{{i18n "crimson_server_list.v3.add_server"}}</span>
            </button>
          {{else if this.viewer.logged_in}}
            <span class="csl-button csl-button--disabled">{{i18n "crimson_server_list.v3.submissions_closed"}}</span>
          {{else}}
            <a class="csl-button csl-button--primary csl-v3-hero-primary" href="/login?return_path=%2Fservers">
              {{dIcon "plus"}}
              <span>{{i18n "crimson_server_list.v3.login_to_add"}}</span>
            </a>
          {{/if}}

          {{#if this.viewer.logged_in}}
            <button class="csl-button csl-v3-hero-secondary" type="button" {{on "click" @onOpenFavorites}}>
              {{dIcon "far-star"}}
              <span>{{i18n "crimson_server_list.v3.favorites"}}</span>
            </button>
          {{/if}}
        </div>
      </section>

      <section class="csl-stats csl-v3-stats" aria-label={{i18n "crimson_server_list.v3.stats_label"}}>
        <article>
          <span class="csl-v3-stat-icon" aria-hidden="true">{{dIcon "server"}}</span>
          <div><strong>{{this.stats.server_count}}</strong><span>{{i18n "crimson_server_list.v3.stat_servers"}}</span></div>
        </article>
        <article>
          <span class="csl-v3-stat-icon" aria-hidden="true">{{dIcon "signal"}}</span>
          <div><strong>{{this.stats.online_count}}</strong><span>{{i18n "crimson_server_list.v3.stat_online"}}</span></div>
        </article>
        <article>
          <span class="csl-v3-stat-icon" aria-hidden="true">{{dIcon "thumbs-up"}}</span>
          <div><strong>{{this.stats.vote_count}}</strong><span>{{i18n "crimson_server_list.v3.stat_votes"}}</span></div>
        </article>
        <article>
          <span class="csl-v3-stat-icon" aria-hidden="true">{{dIcon "gamepad"}}</span>
          <div><strong>{{this.stats.game_count}}</strong><span>{{i18n "crimson_server_list.v3.stat_games"}}</span></div>
        </article>
      </section>
    </main>
  </template>
}
