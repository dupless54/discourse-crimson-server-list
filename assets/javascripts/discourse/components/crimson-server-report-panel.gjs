import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CrimsonServerReportPanel extends Component {
  @service siteSettings;

  @tracked isOpen = false;
  @tracked isSubmitting = false;
  @tracked submitted = false;
  @tracked reason = "";
  @tracked message = "";
  @tracked errorMessage = "";

  get server() {
    return this.args.model?.server || {};
  }

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get canReport() {
    return Boolean(
      this.siteSettings.crimson_server_list_reports_enabled &&
        this.viewer.logged_in &&
        !this.viewer.can_edit &&
        this.server.id,
    );
  }

  get reasons() {
    return ["spam", "misleading", "impersonation", "unsafe", "unreachable", "other"].map(
      (value) => ({
        value,
        label: i18n(`crimson_server_list.reporting.reason_${value}`),
      }),
    );
  }

  get detailsRequired() {
    return this.reason === "other";
  }

  @action
  toggle() {
    this.isOpen = !this.isOpen;
    this.errorMessage = "";
  }

  @action
  updateReason(event) {
    this.reason = event.target.value;
  }

  @action
  async submit(event) {
    event.preventDefault();

    if (this.isSubmitting || !this.reason) {
      return;
    }

    const form = event.currentTarget;
    const formData = new FormData(form);

    this.isSubmitting = true;
    this.message = "";
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${this.server.id}/report.json`,
        {
          type: "POST",
          data: {
            reason: this.reason,
            details: formData.get("details")?.toString() || "",
          },
        },
      );

      this.submitted = true;
      this.isOpen = false;
      this.message = response.message;
      form.reset();
      this.reason = "";
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.reporting.generic_error")
    );
  }

  <template>
    {{#if this.canReport}}
      <section class="csl-panel csl-report-panel" aria-labelledby="csl-report-title">
        <header>
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.reporting.eyebrow"}}</p>
            <h2 id="csl-report-title">{{i18n "crimson_server_list.reporting.title"}}</h2>
          </div>
          <p>{{i18n "crimson_server_list.reporting.description"}}</p>
        </header>

        {{#if this.message}}
          <p class="csl-notice csl-notice--success" role="status">{{this.message}}</p>
        {{/if}}
        {{#if this.errorMessage}}
          <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
        {{/if}}

        {{#unless this.submitted}}
          <button
            class="csl-button"
            type="button"
            aria-expanded={{this.isOpen}}
            {{on "click" this.toggle}}
          >
            {{if this.isOpen
              (i18n "crimson_server_list.reporting.close")
              (i18n "crimson_server_list.reporting.open")}}
          </button>

          {{#if this.isOpen}}
            <form class="csl-form csl-report-form" {{on "submit" this.submit}}>
              <label class="csl-form__wide">
                <span>{{i18n "crimson_server_list.reporting.reason"}}</span>
                <select name="reason" required value={{this.reason}} {{on "change" this.updateReason}}>
                  <option value="" disabled>{{i18n "crimson_server_list.reporting.choose_reason"}}</option>
                  {{#each this.reasons as |reason|}}
                    <option value={{reason.value}} selected={{eq reason.value this.reason}}>{{reason.label}}</option>
                  {{/each}}
                </select>
              </label>

              <label class="csl-form__wide">
                <span>{{i18n "crimson_server_list.reporting.details"}}</span>
                <textarea
                  name="details"
                  maxlength="1000"
                  rows="4"
                  required={{this.detailsRequired}}
                  placeholder={{i18n "crimson_server_list.reporting.details_placeholder"}}
                ></textarea>
                <small>{{i18n "crimson_server_list.reporting.privacy_note"}}</small>
              </label>

              <div class="csl-form__actions csl-form__wide">
                <button class="csl-button" type="button" {{on "click" this.toggle}}>
                  {{i18n "crimson_server_list.reporting.cancel"}}
                </button>
                <button
                  class="csl-button csl-button--danger"
                  type="submit"
                  disabled={{this.isSubmitting}}
                >
                  {{if this.isSubmitting
                    (i18n "crimson_server_list.reporting.submitting")
                    (i18n "crimson_server_list.reporting.submit")}}
                </button>
              </div>
            </form>
          {{/if}}
        {{/unless}}
      </section>
    {{/if}}
  </template>
}
