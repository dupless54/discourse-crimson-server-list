import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

export default class CrimsonServerFeaturedStrip extends Component {
  get featuredServers() {
    return (this.args.servers || [])
      .filter((server) => server.featured)
      .slice(0, 2);
  }

  get eyebrowLabel() {
    return i18n("crimson_server_list.v3.featured_eyebrow");
  }

  get titleLabel() {
    return i18n("crimson_server_list.v3.featured_title");
  }

  get openLabel() {
    return i18n("crimson_server_list.v3.featured_open");
  }

  get onlineLabel() {
    return i18n("crimson_server_list.v3.featured_online");
  }

  get offlineLabel() {
    return i18n("crimson_server_list.v3.featured_offline");
  }

  get playersLabel() {
    return i18n("crimson_server_list.v3.featured_players");
  }

  get reviewsLabel() {
    return i18n("crimson_server_list.v3.featured_reviews");
  }

  <template>
    {{#if this.featuredServers.length}}
      <section class="csl-v3-featured" aria-labelledby="csl-v3-featured-title">
        <header class="csl-v3-featured__header">
          <div>
            <p class="csl-eyebrow">{{this.eyebrowLabel}}</p>
            <h2 id="csl-v3-featured-title">{{this.titleLabel}}</h2>
          </div>
        </header>

        <div class="csl-v3-featured__grid">
          {{#each this.featuredServers as |server|}}
            <article class="csl-v3-featured-card csl-game--{{server.game_slug}}">
              <a
                class="csl-v3-featured-card__visual"
                href={{server.detail_url}}
                aria-label="{{this.openLabel}}: {{server.name}}"
              >
                {{#if server.banner_url}}
                  <img src={{server.banner_url}} alt="" loading="lazy" />
                {{else}}
                  <span aria-hidden="true">{{server.game.icon}}</span>
                {{/if}}
              </a>

              <div class="csl-v3-featured-card__body">
                <div class="csl-v3-featured-card__title-row">
                  <h3><a href={{server.detail_url}}>{{server.name}}</a></h3>
                  <CrimsonVerifiedBadge @server={{server}} />
                </div>
                <p>{{server.short_description}}</p>

                <div class="csl-v3-featured-card__meta">
                  <span class="csl-status csl-status--{{server.status}}">
                    <i></i>
                    {{if (eq server.status "online") this.onlineLabel this.offlineLabel}}
                  </span>
                  <span class="csl-v3-featured-card__game">{{server.game.icon}} {{server.game.name}}</span>
                  {{#if server.supports_player_count}}
                    <span>
                      {{server.players_online}}{{#if server.players_max}}/{{server.players_max}}{{/if}}
                      {{this.playersLabel}}
                    </span>
                  {{/if}}
                  <span>★ {{server.average_rating}} · {{server.review_count}} {{this.reviewsLabel}}</span>
                </div>
              </div>

              <a class="csl-v3-featured-card__open" href={{server.detail_url}}>{{this.openLabel}} →</a>
            </article>
          {{/each}}
        </div>
      </section>
    {{/if}}
  </template>
}
