import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CrimsonServerFormModal from "./modal/crimson-server-form";
import CrimsonServerVerificationPanel from "./crimson-server-verification-panel";
import CrimsonVerifiedBadge from "./crimson-verified-badge";

export default class CrimsonServerDetail extends Component {
  @service dialog;
  @service modal;

  @tracked server = this.args.model?.server || {};
  @tracked reviews = this.args.model?.reviews || [];
  @tracked busyAction = "";
  @tracked announcement = "";
  @tracked errorMessage = "";
  @tracked reviewRating = this.mineReview?.rating || 0;
  @tracked reviewBody = this.mineReview?.body || "";
  @tracked claimStatus = this.args.model?.viewer?.claim_status || "";

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get games() {
    return this.args.model?.games || [];
  }

  get mineReview() {
    return this.reviews.find((review) => review.mine);
  }

  get hasReviews() {
    return this.reviews.length > 0;
  }

  get gameDetailRows() {
    return (this.server.game_detail_rows || []).map((detail) => ({
      ...detail,
      label: i18n(
        `crimson_server_list.server_form.field_labels.${detail.key}`,
      ),
      unit:
        detail.key === "group_limit"
          ? i18n("crimson_server_list.server_form.field_units.people")
          : detail.unit,
    }));
  }

  get canRefresh() {
    return (
      this.viewer.can_edit &&
      this.viewer.live_query_enabled &&
      this.server.approved &&
      this.server.enabled &&
      this.server.monitoring_enabled
    );
  }

  get loginPath() {
    return `/login?return_path=${encodeURIComponent(this.server.detail_url)}`;
  }

  get starOptions() {
    const selected = Number(this.reviewRating || 0);
    return [1, 2, 3, 4, 5].map((value) => ({
      value,
      active: value <= selected,
    }));
  }

  get scoreLabel() {
    const average = Number(this.server.average_rating || 0).toFixed(1);
    return `${average} / 5`;
  }

  @action
  openEdit() {
    const previousSlug = this.server.slug;
    const previousHost = this.server.host;
    this.clearMessages();

    this.modal.show(CrimsonServerFormModal, {
      model: {
        mode: "edit",
        games: this.games,
        server: this.server,
        onSaved: (server, response) => {
          this.server = server;
          this.announcement = response.message;

          if (server.slug !== previousSlug) {
            window.location.assign(server.detail_url);
          } else if (server.host !== previousHost) {
            window.location.reload();
          }
        },
      },
    });
  }

  @action
  setRating(value) {
    this.reviewRating = value;
  }

  @action
  updateReviewBody(event) {
    this.reviewBody = event.currentTarget.value;
  }

  @action
  applyVerification(verification) {
    this.server = {
      ...this.server,
      verified: Boolean(verification?.verified),
      verified_at: verification?.verified_at || null,
      verification_method: verification?.verification_method || null,
    };
  }

  @action
  async copyAddress() {
    try {
      await navigator.clipboard.writeText(this.server.address);
      this.clearMessages();
      this.announcement = i18n("crimson_server_list.detail.copy_success", {
        address: this.server.address,
      });
    } catch {
      this.errorMessage = i18n("crimson_server_list.detail.copy_error");
    }
  }

  @action
  async vote() {
    if (this.server.voted_today || this.busyAction) {
      return;
    }

    this.busyAction = "vote";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/vote.json`,
        { type: "POST" },
      );
      this.server = {
        ...this.server,
        vote_count: response.vote_count,
        voted_today: true,
      };
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async refreshStatus() {
    if (this.busyAction) {
      return;
    }

    this.busyAction = "refresh";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/refresh.json`,
        { type: "POST" },
      );
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async requestOwnership() {
    if (this.busyAction || this.claimStatus === "pending") {
      return;
    }

    this.busyAction = "claim";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/claim.json`,
        { type: "POST" },
      );
      this.claimStatus = response.claim.status;
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async deleteServer() {
    if (this.busyAction) {
      return;
    }

    const confirmed = await this.dialog.deleteConfirm({
      title: i18n("crimson_server_list.detail.delete_title"),
      message: i18n("crimson_server_list.detail.delete_confirm", {
        name: this.server.name,
      }),
    });
    if (!confirmed) {
      return;
    }

    this.busyAction = "delete";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}.json`,
        { type: "DELETE" },
      );
      window.location.assign(response.redirect_url || "/servers");
    } catch (error) {
      this.errorMessage = this.errorText(error);
      this.busyAction = "";
    }
  }

  @action
  async saveReview(event) {
    event.preventDefault();
    if (this.busyAction) {
      return;
    }

    this.busyAction = "review";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/review.json`,
        {
          type: "PUT",
          data: {
            rating: this.reviewRating,
            body: this.reviewBody,
          },
        },
      );
      this.reviews = [
        response.review,
        ...this.reviews.filter((review) => !review.mine),
      ];
      this.server = { ...this.server, ...response.rating };
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async deleteReview() {
    if (!this.mineReview || this.busyAction) {
      return;
    }

    this.busyAction = "review";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/review.json`,
        { type: "DELETE" },
      );
      this.reviews = this.reviews.filter((review) => !review.mine);
      this.reviewRating = 0;
      this.reviewBody = "";
      this.server = { ...this.server, ...response.rating };
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  clearMessages() {
    this.announcement = "";
    this.errorMessage = "";
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.detail.generic_error")
    );
  }

  <template>
    <main class="csl-page csl-detail-page">
      <nav class="csl-detail-back" aria-label={{i18n "crimson_server_list.detail.back_label"}}>
        <a href="/servers">← {{i18n "crimson_server_list.detail.back_all"}}</a>
      </nav>

      <article class="csl-detail csl-game--{{this.server.game_slug}}">
        <section class="csl-detail-hero">
          <div class="csl-detail-hero__visual">
            <span aria-hidden="true">{{this.server.game.icon}}</span>
          </div>

          <div class="csl-detail-hero__shade"></div>
          <div class="csl-detail-hero__content">
            <a class="csl-eyebrow csl-category-link" href={{this.server.game.category_url}}>{{this.server.game.icon}} {{this.server.game.name}}</a>
            <div class="csl-title-row">
              <h1>{{this.server.name}}</h1>
              <CrimsonVerifiedBadge @server={{this.server}} />
            </div>
            <p>{{this.server.short_description}}</p>

            <div class="csl-meta">
              <span class="csl-status csl-status--{{this.server.status}}"><i></i>{{this.server.status_label}}</span>
              {{#unless this.server.approved}}<span>{{i18n "crimson_server_list.detail.pending_approval"}}</span>{{/unless}}
              {{#if this.server.language}}<span>{{this.server.language}}</span>{{/if}}
              {{#if this.server.version}}<span>{{this.server.version}}</span>{{/if}}
              {{#if this.server.mode}}<span>{{this.server.mode}}</span>{{/if}}
            </div>

            {{#if this.server.tag_rows.length}}
              <div class="csl-server-tags csl-server-tags--hero" aria-label={{i18n "crimson_server_list.detail.tags_label"}}>
                {{#each this.server.tag_rows as |tag|}}<a href={{tag.url}}>#{{tag.name}}</a>{{/each}}
              </div>
            {{/if}}

            {{#if this.server.banner_url}}
              {{#if this.server.website_url}}
                <a
                  class="csl-ad-banner csl-ad-banner--detail"
                  href={{this.server.website_url}}
                  target="_blank"
                  rel="noopener noreferrer nofollow ugc sponsored"
                  aria-label={{i18n "crimson_server_list.detail.website_label" name=this.server.name}}
                ><img src={{this.server.banner_url}} alt={{i18n "crimson_server_list.detail.banner_alt" name=this.server.name}} /></a>
              {{else}}
                <div class="csl-ad-banner csl-ad-banner--detail"><img src={{this.server.banner_url}} alt={{i18n "crimson_server_list.detail.banner_alt" name=this.server.name}} /></div>
              {{/if}}
            {{/if}}
          </div>
        </section>

        <section class="csl-detail-summary">
          <div class="csl-detail-summary__main">
            {{#if this.server.can_view_endpoint}}
              <div class="csl-address csl-address--detail">
                <code>{{this.server.address}}</code>
                <button type="button" {{on "click" this.copyAddress}}>{{i18n "crimson_server_list.detail.copy_address"}}</button>
              </div>
            {{/if}}

            <div class="csl-owner csl-owner--detail">
              {{#if this.server.owner}}
                <a
                  class="csl-avatar-link duc-avatar-frame-target trigger-user-card"
                  data-user-card={{this.server.owner.username}}
                  href={{this.server.owner.profile_url}}
                  aria-label={{i18n "crimson_server_list.detail.user_card_label" username=this.server.owner.username}}
                >
                  {{#if this.server.owner.avatar_url}}<img class="avatar" src={{this.server.owner.avatar_url}} alt="" />{{/if}}
                </a>
                <a
                  class="csl-owner__identity trigger-user-card"
                  data-user-card={{this.server.owner.username}}
                  href={{this.server.owner.profile_url}}
                ><span><strong>{{this.server.owner.name}}</strong><small>@{{this.server.owner.username}} · {{i18n "crimson_server_list.detail.owner_role"}}</small></span></a>
              {{/if}}
            </div>
          </div>

          <div class="csl-detail-metrics">
            <div>
              {{#if this.server.supports_player_count}}
                <strong>{{this.server.players_online}}<small>{{#if this.server.players_max}}/{{this.server.players_max}}{{else}}/?{{/if}}</small></strong>
                <span>{{i18n "crimson_server_list.detail.live_players"}}</span>
              {{else}}
                <strong>{{if (eq this.server.status "online") (i18n "crimson_server_list.detail.status_online") "—"}}</strong>
                <span>{{i18n "crimson_server_list.detail.reachability"}}</span>
              {{/if}}
            </div>
            <div><strong>{{this.server.vote_count}}</strong><span>{{i18n "crimson_server_list.detail.total_votes"}}</span></div>
            <div><strong>{{this.scoreLabel}}</strong><span>{{i18n "crimson_server_list.detail.review_count" count=this.server.review_count}}</span></div>
            <div><strong>{{this.server.view_count}}</strong><span>{{i18n "crimson_server_list.detail.views"}}</span></div>
          </div>

          <div class="csl-detail-actions">
            {{#if this.viewer.can_vote}}
              <button class="csl-vote-button {{if this.server.voted_today "is-voted" ""}}" type="button" disabled={{this.server.voted_today}} {{on "click" this.vote}}>
                {{if this.server.voted_today (i18n "crimson_server_list.detail.voted_today") (i18n "crimson_server_list.detail.vote")}}
              </button>
            {{else if this.viewer.logged_in}}
              <span class="csl-vote-button is-disabled">{{i18n "crimson_server_list.detail.voting_closed"}}</span>
            {{else}}
              <a class="csl-vote-button" href={{this.loginPath}}>{{i18n "crimson_server_list.detail.login_to_vote"}}</a>
            {{/if}}
            {{#if this.server.website_url}}<a class="csl-button" href={{this.server.website_url}} target="_blank" rel="noopener noreferrer nofollow ugc">{{i18n "crimson_server_list.detail.website"}}</a>{{/if}}
            {{#if this.server.discord_url}}<a class="csl-button" href={{this.server.discord_url}} target="_blank" rel="noopener noreferrer nofollow ugc">Discord</a>{{/if}}
            {{#if this.viewer.can_edit}}
              <button class="csl-button" type="button" {{on "click" this.openEdit}}>{{i18n "crimson_server_list.detail.edit"}}</button>
            {{/if}}
            {{#if this.canRefresh}}
              <button class="csl-button" type="button" disabled={{eq this.busyAction "refresh"}} {{on "click" this.refreshStatus}}>{{i18n "crimson_server_list.detail.refresh"}}</button>
            {{/if}}
            {{#if (eq this.claimStatus "pending")}}
              <span class="csl-button csl-button--disabled">{{i18n "crimson_server_list.detail.claim_pending"}}</span>
            {{else if this.viewer.can_claim}}
              <button class="csl-button" type="button" disabled={{eq this.busyAction "claim"}} {{on "click" this.requestOwnership}}>{{i18n "crimson_server_list.detail.claim"}}</button>
            {{else}}
              {{#unless this.viewer.logged_in}}<a class="csl-button" href={{this.loginPath}}>{{i18n "crimson_server_list.detail.claim"}}</a>{{/unless}}
            {{/if}}
            {{#if this.viewer.can_delete}}
              <button class="csl-button csl-button--danger" type="button" disabled={{eq this.busyAction "delete"}} {{on "click" this.deleteServer}}>{{i18n "crimson_server_list.detail.delete"}}</button>
            {{/if}}
          </div>
        </section>

        {{#if this.announcement}}<p class="csl-notice csl-notice--success" role="status">{{this.announcement}}</p>{{/if}}
        {{#if this.errorMessage}}<p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>{{/if}}

        {{#if this.viewer.can_edit}}
          <CrimsonServerVerificationPanel
            @server={{this.server}}
            @viewer={{this.viewer}}
            @onStateChange={{this.applyVerification}}
          />
        {{/if}}

        <div class="csl-detail-grid">
          <section class="csl-panel csl-about">
            <header><div><p class="csl-eyebrow">{{i18n "crimson_server_list.detail.about_eyebrow"}}</p><h2>{{i18n "crimson_server_list.detail.about_title"}}</h2></div></header>
            {{#if this.server.description}}
              <p>{{this.server.description}}</p>
            {{else}}
              <p class="csl-muted-copy">{{i18n "crimson_server_list.detail.no_description"}}</p>
            {{/if}}

            {{#if this.gameDetailRows.length}}
              <dl class="csl-game-details">
                {{#each this.gameDetailRows as |detail|}}
                  <div>
                    <dt>{{detail.label}}</dt>
                    <dd>{{detail.value}}{{#if detail.unit}} {{detail.unit}}{{/if}}</dd>
                  </div>
                {{/each}}
              </dl>
            {{/if}}

            <dl class="csl-technical">
              <div class="csl-technical__wide"><dt>{{i18n "crimson_server_list.detail.last_checked"}}</dt><dd>{{if this.server.last_checked_at this.server.last_checked_at (i18n "crimson_server_list.detail.never_checked")}}</dd></div>
              {{#if this.server.can_view_endpoint}}
                <div><dt>{{i18n "crimson_server_list.detail.query_adapter"}}</dt><dd>{{this.server.query_adapter}}</dd></div>
                <div><dt>{{i18n "crimson_server_list.detail.query_port"}}</dt><dd>{{if this.server.query_port this.server.query_port this.server.port}}</dd></div>
                <div><dt>{{i18n "crimson_server_list.detail.response_time"}}</dt><dd>{{#if this.server.last_response_ms}}{{this.server.last_response_ms}} ms{{else}}—{{/if}}</dd></div>
                {{#if this.server.last_query_error}}<div class="csl-technical__wide"><dt>{{i18n "crimson_server_list.detail.last_query_note"}}</dt><dd>{{this.server.last_query_error}}</dd></div>{{/if}}
              {{/if}}
            </dl>
          </section>

          <section class="csl-panel csl-review-composer" aria-labelledby="csl-review-title">
            <header><div><p class="csl-eyebrow">{{i18n "crimson_server_list.detail.community_eyebrow"}}</p><h2 id="csl-review-title">{{i18n "crimson_server_list.detail.review_title"}}</h2></div></header>
            {{#if this.viewer.can_review}}
              <form {{on "submit" this.saveReview}}>
                <div class="csl-star-picker" role="group" aria-label={{i18n "crimson_server_list.detail.star_group_label"}}>
                  {{#each this.starOptions as |star|}}
                    <button class={{if star.active "is-active" ""}} type="button" aria-label={{i18n "crimson_server_list.detail.star_label" count=star.value}} aria-pressed={{star.active}} {{on "click" (fn this.setRating star.value)}}>★</button>
                  {{/each}}
                </div>
                <textarea maxlength="2000" rows="5" value={{this.reviewBody}} placeholder={{i18n "crimson_server_list.detail.review_placeholder"}} {{on "input" this.updateReviewBody}}></textarea>
                <div class="csl-review-composer__actions">
                  {{#if this.mineReview}}<button class="csl-button" type="button" disabled={{eq this.busyAction "review"}} {{on "click" this.deleteReview}}>{{i18n "crimson_server_list.detail.delete_review"}}</button>{{/if}}
                  <button class="csl-button csl-button--primary" type="submit" disabled={{eq this.busyAction "review"}}>{{if this.mineReview (i18n "crimson_server_list.detail.update_review") (i18n "crimson_server_list.detail.publish_review")}}</button>
                </div>
              </form>
            {{else if this.viewer.logged_in}}
              <p class="csl-muted-copy">{{i18n "crimson_server_list.detail.reviews_closed"}}</p>
            {{else}}
              <a class="csl-button csl-button--primary" href={{this.loginPath}}>{{i18n "crimson_server_list.detail.login_to_review"}}</a>
            {{/if}}
          </section>
        </div>

        <section class="csl-panel csl-reviews" aria-labelledby="csl-reviews-title">
          <header>
            <div><p class="csl-eyebrow">{{i18n "crimson_server_list.detail.reviews_eyebrow" count=this.server.review_count}}</p><h2 id="csl-reviews-title">{{i18n "crimson_server_list.detail.reviews_title"}}</h2></div>
            <strong class="csl-rating-badge">★ {{this.scoreLabel}}</strong>
          </header>

          {{#if this.hasReviews}}
            <div class="csl-review-list">
              {{#each this.reviews as |review|}}
                <article class="csl-review">
                  <div class="csl-review__user">
                    <a
                      class="csl-avatar-link duc-avatar-frame-target trigger-user-card"
                      data-user-card={{review.user.username}}
                      href={{review.user.profile_url}}
                      aria-label={{i18n "crimson_server_list.detail.user_card_label" username=review.user.username}}
                    ><img class="avatar" src={{review.user.avatar_url}} alt="" loading="lazy" /></a>
                    <a
                      class="csl-review__identity trigger-user-card"
                      data-user-card={{review.user.username}}
                      href={{review.user.profile_url}}
                    ><span><strong>{{review.user.name}}</strong><small>@{{review.user.username}}</small></span></a>
                  </div>
                  <div class="csl-review__rating" aria-label={{i18n "crimson_server_list.detail.star_label" count=review.rating}}>★ {{review.rating}}/5</div>
                  <p>{{review.body}}</p>
                  {{#if review.mine}}<span class="csl-review__mine">{{i18n "crimson_server_list.detail.mine_review"}}</span>{{/if}}
                </article>
              {{/each}}
            </div>
          {{else}}
            <div class="csl-empty csl-empty--compact"><p>{{i18n "crimson_server_list.detail.no_reviews"}}</p></div>
          {{/if}}
        </section>
      </article>
    </main>
  </template>
}
