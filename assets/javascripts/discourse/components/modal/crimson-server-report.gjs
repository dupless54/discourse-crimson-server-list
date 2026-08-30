import Component from "@glimmer/component";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class CrimsonServerReportModal extends Component {
  @tracked isSubmitting = false;
  @tracked reason = "";
  @tracked errorMessage = "";

  get server() {
    return this.args.model?.server || {};
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
  updateReason(event) {
    this.reason = event.target.value;
  }

  @action
  async submit(_actionParam, event) {
    if (this.isSubmitting || !this.reason) {
      return;
    }

    const submitter = event?.currentTarget || event?.target;
    const form = submitter?.form || submitter;
    if (!(form instanceof HTMLFormElement)) {
      this.errorMessage = i18n("crimson_server_list.reporting.generic_error");
      return;
    }

    const formData = new FormData(form);
    this.isSubmitting = true;
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
      this.args.model?.onSubmitted?.(response);
      this.args.closeModal(response);
    } catch (error) {
      this.errorMessage =
        error?.jqXHR?.responseJSON?.errors?.join(" ") ||
        error?.responseJSON?.errors?.join(" ") ||
        i18n("crimson_server_list.reporting.generic_error");
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <DModal
      class="csl-server-report-modal"
      @title={{i18n "crimson_server_list.reporting.title"}}
      @closeModal={{@closeModal}}
      @tagName="form"
    >
      <:body>
        <p class="csl-server-report-modal__intro">
          {{i18n "crimson_server_list.reporting.description"}}
        </p>

        {{#if this.errorMessage}}
          <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
        {{/if}}

        <div class="csl-modal-form">
          <label>
            <span>{{i18n "crimson_server_list.reporting.reason"}}</span>
            <select name="reason" required value={{this.reason}} {{on "change" this.updateReason}}>
              <option value="" disabled>{{i18n "crimson_server_list.reporting.choose_reason"}}</option>
              {{#each this.reasons as |reason|}}
                <option value={{reason.value}} selected={{eq reason.value this.reason}}>{{reason.label}}</option>
              {{/each}}
            </select>
          </label>

          <label>
            <span>{{i18n "crimson_server_list.reporting.details"}}</span>
            <textarea
              name="details"
              maxlength="1000"
              rows="5"
              required={{this.detailsRequired}}
              placeholder={{i18n "crimson_server_list.reporting.details_placeholder"}}
            ></textarea>
            <small>{{i18n "crimson_server_list.reporting.privacy_note"}}</small>
          </label>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{@closeModal}}
          @label="crimson_server_list.reporting.cancel"
          @disabled={{this.isSubmitting}}
        />
        <DButton
          @action={{this.submit}}
          @forwardEvent={{true}}
          @translatedLabel={{if this.isSubmitting (i18n "crimson_server_list.reporting.submitting") (i18n "crimson_server_list.reporting.submit")}}
          @type="submit"
          @isLoading={{this.isSubmitting}}
          class="btn-danger"
        />
      </:footer>
    </DModal>
  </template>
}
