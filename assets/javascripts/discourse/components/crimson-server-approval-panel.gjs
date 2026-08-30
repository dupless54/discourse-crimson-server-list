import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { and, eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CrimsonServerApprovalPanel extends Component {
  @tracked pendingServers = [];
  @tracked pendingClaims = [];
  @tracked isLoading = false;
  @tracked hasLoaded = false;
  @tracked busyServerId = null;
  @tracked busyClaimId = null;
  @tracked announcement = "";
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.viewer.is_admin) {
      scheduleOnce("afterRender", this, this.loadQueues);
    }
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get pendingCount() {
    return this.pendingServers.length + this.pendingClaims.length;
  }

  get serverMutationBusy() {
    return Boolean(this.busyServerId);
  }

  get claimMutationBusy() {
    return Boolean(this.busyClaimId);
  }

  clearMessages() {
    this.announcement = "";
    this.errorMessage = "";
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.v3_admin.generic_error")
    );
  }

  @action
  async loadQueues() {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.clearMessages();

    try {
      const response = await ajax("/crimson-server-list/bootstrap.json");
      this.pendingServers = response.pending_servers || [];
      this.pendingClaims = response.pending_claims || [];
      this.hasLoaded = true;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async approveServer(server) {
    await this.moderateServer(server, { approved: true, enabled: true }, true);
  }

  @action
  async rejectServer(server) {
    await this.moderateServer(server, { approved: false, enabled: false }, false);
  }

  async moderateServer(server, data, publish) {
    if (this.serverMutationBusy) {
      return;
    }

    this.busyServerId = server.id;
    this.clearMessages();

    try {
      await ajax(`/crimson-server-list/admin/servers/${server.id}.json`, {
        type: "PUT",
        data,
      });
      this.pendingServers = this.pendingServers.filter(
        (candidate) => candidate.id !== server.id,
      );
      this.announcement = i18n(
        publish
          ? "crimson_server_list.v3_admin.server_published"
          : "crimson_server_list.v3_admin.server_rejected",
        { name: server.name },
      );
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyServerId = null;
    }
  }

  @action
  async approveClaim(claim) {
    await this.moderateClaim(claim, "approved");
  }

  @action
  async rejectClaim(claim) {
    await this.moderateClaim(claim, "rejected");
  }

  async moderateClaim(claim, status) {
    if (this.claimMutationBusy) {
      return;
    }

    this.busyClaimId = claim.id;
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/admin/claims/${claim.id}.json`,
        { type: "PUT", data: { status } },
      );
      this.pendingClaims = this.pendingClaims.filter((candidate) =>
        status === "approved"
          ? candidate.server.id !== claim.server.id
          : candidate.id !== claim.id,
      );
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyClaimId = null;
    }
  }

  <template>
    {{#if this.viewer.is_admin}}
      <section class="csl-panel csl-v3-admin-panel" aria-labelledby="csl-v3-approval-title">
        <header class="csl-v3-panel-heading">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.v3_admin.eyebrow"}}</p>
            <h2 id="csl-v3-approval-title">{{i18n "crimson_server_list.v3_admin.approvals_title"}}</h2>
            <p>{{i18n "crimson_server_list.v3_admin.approvals_description"}}</p>
          </div>
          <div class="csl-v3-panel-heading__actions">
            {{#if this.hasLoaded}}
              <span class="csl-v3-panel-count">{{i18n "crimson_server_list.v3_admin.pending_total" count=this.pendingCount}}</span>
            {{/if}}
            <DButton
              @action={{this.loadQueues}}
              @label="crimson_server_list.reporting.reload"
              @isLoading={{this.isLoading}}
              class="csl-button csl-v3-admin-refresh"
            />
          </div>
        </header>

        {{#if this.announcement}}
          <p class="csl-notice csl-notice--success" role="status">{{this.announcement}}</p>
        {{/if}}
        {{#if this.errorMessage}}
          <div class="csl-v3-panel-error">
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
            {{#unless this.hasLoaded}}
              <DButton
                @action={{this.loadQueues}}
                @label="crimson_server_list.owner_panel.retry"
                class="csl-button"
              />
            {{/unless}}
          </div>
        {{/if}}

        {{#if (and this.isLoading (not this.hasLoaded))}}
          <div class="csl-v3-tab-loading" role="status">
            <span class="csl-v3-loading-dot" aria-hidden="true"></span>
            {{i18n "crimson_server_list.reporting.loading"}}
          </div>
        {{else if this.hasLoaded}}
          <div class="csl-v3-admin-columns">
            <section class="csl-v3-admin-group" aria-labelledby="csl-v3-server-approvals-title">
              <div class="csl-v3-admin-group__header">
                <div>
                  <h3 id="csl-v3-server-approvals-title">{{i18n "crimson_server_list.v3_admin.server_queue"}}</h3>
                  <p>{{i18n "crimson_server_list.v3_admin.server_queue_description"}}</p>
                </div>
                <strong>{{this.pendingServers.length}}</strong>
              </div>

              <div class="csl-v3-admin-list">
                {{#each this.pendingServers as |server|}}
                  <article class="csl-v3-admin-card csl-game--{{server.game_slug}}">
                    <div class="csl-v3-admin-card__icon" aria-hidden="true">{{server.game.icon}}</div>
                    <div class="csl-v3-admin-card__body">
                      <div class="csl-v3-admin-card__title">
                        <strong>{{server.name}}</strong>
                        <span>{{server.game.name}}</span>
                      </div>
                      <p>{{server.short_description}}</p>
                      <div class="csl-v3-admin-card__meta">
                        <span>{{server.address}}</span>
                        <span>@{{server.owner.username}}</span>
                      </div>
                    </div>
                    <div class="csl-v3-admin-card__actions">
                      <DButton
                        @action={{fn this.rejectServer server}}
                        @label="crimson_server_list.v3_admin.reject"
                        @disabled={{this.serverMutationBusy}}
                        @isLoading={{eq this.busyServerId server.id}}
                        class="csl-button"
                      />
                      <DButton
                        @action={{fn this.approveServer server}}
                        @label="crimson_server_list.v3_admin.publish"
                        @disabled={{this.serverMutationBusy}}
                        @isLoading={{eq this.busyServerId server.id}}
                        class="csl-button csl-button--primary"
                      />
                    </div>
                  </article>
                {{else}}
                  <div class="csl-empty csl-empty--compact">
                    <p>{{i18n "crimson_server_list.v3_admin.no_pending_servers"}}</p>
                  </div>
                {{/each}}
              </div>
            </section>

            <section class="csl-v3-admin-group" aria-labelledby="csl-v3-claim-approvals-title">
              <div class="csl-v3-admin-group__header">
                <div>
                  <h3 id="csl-v3-claim-approvals-title">{{i18n "crimson_server_list.v3_admin.claim_queue"}}</h3>
                  <p>{{i18n "crimson_server_list.v3_admin.claim_queue_description"}}</p>
                </div>
                <strong>{{this.pendingClaims.length}}</strong>
              </div>

              <div class="csl-v3-admin-list">
                {{#each this.pendingClaims as |claim|}}
                  <article class="csl-v3-admin-card csl-v3-admin-card--claim">
                    {{#if claim.requester.avatar_url}}
                      <a
                        class="csl-avatar-link duc-avatar-frame-target trigger-user-card"
                        data-user-card={{claim.requester.username}}
                        href={{claim.requester.profile_url}}
                      ><img class="avatar" src={{claim.requester.avatar_url}} alt="" loading="lazy" /></a>
                    {{/if}}
                    <div class="csl-v3-admin-card__body">
                      <div class="csl-v3-admin-card__title">
                        <strong>{{claim.server.name}}</strong>
                        <span>@{{claim.requester.username}}</span>
                      </div>
                      <p>{{i18n "crimson_server_list.v3_admin.claim_request" username=claim.requester.username}}</p>
                      <div class="csl-v3-admin-card__meta">
                        <span>{{i18n "crimson_server_list.v3_admin.current_owner" username=claim.server.current_owner_username}}</span>
                      </div>
                      {{#if claim.note}}<blockquote>{{claim.note}}</blockquote>{{/if}}
                    </div>
                    <div class="csl-v3-admin-card__actions">
                      <DButton
                        @action={{fn this.rejectClaim claim}}
                        @label="crimson_server_list.v3_admin.reject"
                        @disabled={{this.claimMutationBusy}}
                        @isLoading={{eq this.busyClaimId claim.id}}
                        class="csl-button"
                      />
                      <DButton
                        @action={{fn this.approveClaim claim}}
                        @label="crimson_server_list.v3_admin.transfer"
                        @disabled={{this.claimMutationBusy}}
                        @isLoading={{eq this.busyClaimId claim.id}}
                        class="csl-button csl-button--primary"
                      />
                    </div>
                  </article>
                {{else}}
                  <div class="csl-empty csl-empty--compact">
                    <p>{{i18n "crimson_server_list.v3_admin.no_pending_claims"}}</p>
                  </div>
                {{/each}}
              </div>
            </section>
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
