import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CrimsonServerVerificationPanel extends Component {
  @tracked verification = null;
  @tracked challenge = null;
  @tracked isLoading = true;
  @tracked loadFailed = false;
  @tracked busyAction = "";
  @tracked message = "";
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (typeof window !== "undefined" && this.args.viewer?.can_edit) {
      void this.loadVerification();
    } else {
      this.isLoading = false;
    }
  }

  get verificationEnabled() {
    return Boolean(this.args.viewer?.verification_enabled);
  }

  get isVerified() {
    return Boolean(this.args.server?.verified || this.verification?.verified);
  }

  get canCheck() {
    return Boolean(this.verification?.pending && !this.busyAction);
  }

  get mutationBusy() {
    return Boolean(this.busyAction);
  }

  @action
  async loadVerification() {
    if (this.isLoading && this.verification) {
      return;
    }

    this.isLoading = true;
    this.loadFailed = false;
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.args.server.id}/verification.json`,
      );
      this.verification = response.verification;
      this.loadFailed = false;
      this.syncPublicState(response.verification);
    } catch (error) {
      this.loadFailed = true;
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async startVerification() {
    if (this.mutationBusy || !this.verificationEnabled) {
      return;
    }

    this.busyAction = "start";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.args.server.id}/verification.json`,
        { type: "POST" },
      );
      this.verification = response.verification;
      this.challenge = response.verification.challenge || null;
      this.message = response.message;
      this.syncPublicState(response.verification);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async checkVerification() {
    if (!this.canCheck || !this.verificationEnabled) {
      return;
    }

    this.busyAction = "check";
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.args.server.id}/verification/check.json`,
        { type: "POST" },
      );
      this.verification = response.verification;
      this.challenge = null;
      this.message = response.message;
      this.syncPublicState(response.verification);
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyAction = "";
    }
  }

  @action
  async copyChallengeValue() {
    if (!this.challenge?.record_value || this.mutationBusy) {
      return;
    }

    this.busyAction = "copy";
    this.clearMessages();

    try {
      await navigator.clipboard.writeText(this.challenge.record_value);
      this.message = i18n("crimson_server_list.verification.copied");
    } catch {
      this.errorMessage = i18n("crimson_server_list.server_form.generic_error");
    } finally {
      this.busyAction = "";
    }
  }

  syncPublicState(verification) {
    this.args.onStateChange?.(verification);
  }

  clearMessages() {
    this.message = "";
    this.errorMessage = "";
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.server_form.generic_error")
    );
  }

  <template>
    <section class="csl-panel csl-verification-panel" aria-labelledby="csl-verification-title">
      <header>
        <div>
          <p class="csl-eyebrow">{{i18n "crimson_server_list.verification.eyebrow"}}</p>
          <h2 id="csl-verification-title">{{i18n "crimson_server_list.verification.title"}}</h2>
        </div>
      </header>

      {{#if this.message}}
        <p class="csl-notice csl-notice--success" role="status">{{this.message}}</p>
      {{/if}}
      {{#if this.errorMessage}}
        <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
      {{/if}}

      {{#unless this.verificationEnabled}}
        <div class="csl-verification-panel__status">
          <p>{{i18n "crimson_server_list.verification.unavailable"}}</p>
        </div>
      {{else if this.isLoading}}
        <div class="csl-v3-tab-loading" role="status">
          <span class="csl-v3-loading-dot" aria-hidden="true"></span>
          {{i18n "crimson_server_list.verification.loading"}}
        </div>
      {{else if this.loadFailed}}
        <div class="csl-verification-panel__status csl-v3-panel-error">
          <DButton
            @action={{this.loadVerification}}
            @label="crimson_server_list.owner_panel.retry"
            class="csl-button"
          />
        </div>
      {{else if this.isVerified}}
        <div class="csl-verification-panel__status">
          <strong>{{i18n "crimson_server_list.verification.verified_title"}}</strong>
          <p>{{i18n "crimson_server_list.verification.verified_description"}}</p>
        </div>
      {{else if this.verification.eligible}}
        <div class="csl-verification-panel__status">
          <p>{{i18n "crimson_server_list.verification.intro"}}</p>
          {{#if this.verification.pending}}
            <p>{{i18n "crimson_server_list.verification.pending"}}</p>
          {{/if}}
        </div>

        {{#if this.verification.pending}}
          <div class="csl-verification-records">
            <div class="csl-verification-record">
              <span>{{i18n "crimson_server_list.verification.record_type"}}</span>
              <code>TXT</code>
            </div>
            <div class="csl-verification-record">
              <span>{{i18n "crimson_server_list.verification.expires"}}</span>
              <code>{{this.verification.expires_at}}</code>
            </div>
            <div class="csl-verification-record csl-verification-record--wide">
              <span>{{i18n "crimson_server_list.verification.record_name"}}</span>
              <code>{{this.verification.record_name}}</code>
            </div>
            {{#if this.challenge.record_value}}
              <div class="csl-verification-record csl-verification-record--wide">
                <span>{{i18n "crimson_server_list.verification.record_value"}}</span>
                <code>{{this.challenge.record_value}}</code>
              </div>
            {{/if}}
          </div>

          {{#unless this.challenge.record_value}}
            <p class="csl-verification-help">{{i18n "crimson_server_list.verification.secret_lost"}}</p>
          {{/unless}}

          <div class="csl-verification-panel__actions">
            {{#if this.challenge.record_value}}
              <DButton
                @action={{this.copyChallengeValue}}
                @label="crimson_server_list.verification.copy"
                @disabled={{this.mutationBusy}}
                @isLoading={{eq this.busyAction "copy"}}
                class="csl-button"
              />
            {{/if}}
            <DButton
              @action={{this.checkVerification}}
              @translatedLabel={{if (eq this.busyAction "check") (i18n "crimson_server_list.verification.checking") (i18n "crimson_server_list.verification.check")}}
              @disabled={{this.mutationBusy}}
              @isLoading={{eq this.busyAction "check"}}
              class="csl-button csl-button--primary"
            />
            <DButton
              @action={{this.startVerification}}
              @label="crimson_server_list.verification.restart"
              @disabled={{this.mutationBusy}}
              @isLoading={{eq this.busyAction "start"}}
              class="csl-button"
            />
          </div>
        {{else}}
          <div class="csl-verification-panel__actions">
            <DButton
              @action={{this.startVerification}}
              @label="crimson_server_list.verification.start"
              @disabled={{this.mutationBusy}}
              @isLoading={{eq this.busyAction "start"}}
              class="csl-button csl-button--primary"
            />
          </div>
        {{/if}}
      {{else}}
        <div class="csl-verification-panel__status">
          <p>{{i18n "crimson_server_list.verification.ineligible"}}</p>
        </div>
      {{/unless}}
    </section>
  </template>
}
