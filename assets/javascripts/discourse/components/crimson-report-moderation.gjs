import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class CrimsonReportModeration extends Component {
  @tracked isOpen = false;
  @tracked isLoading = false;
  @tracked hasLoaded = false;
  @tracked reports = [];
  @tracked busyReportId = null;
  @tracked message = "";
  @tracked errorMessage = "";

  get isAdmin() {
    return Boolean(this.args.viewer?.is_admin);
  }

  @action
  async toggle() {
    this.isOpen = !this.isOpen;
    this.errorMessage = "";

    if (this.isOpen && !this.hasLoaded) {
      await this.loadReports();
    }
  }

  @action
  async reload() {
    await this.loadReports();
  }

  @action
  async resolve(report) {
    await this.moderate(report, "resolved");
  }

  @action
  async dismiss(report) {
    await this.moderate(report, "dismissed");
  }

  async loadReports() {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.message = "";
    this.errorMessage = "";

    try {
      const response = await ajax("/crimson-server-list/admin/reports.json");
      this.reports = response.reports || [];
      this.hasLoaded = true;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  async moderate(report, status) {
    if (this.busyReportId) {
      return;
    }

    this.busyReportId = report.id;
    this.message = "";
    this.errorMessage = "";

    try {
      const response = await ajax(
        `/crimson-server-list/admin/reports/${report.id}.json`,
        { type: "PUT", data: { status } },
      );
      this.reports = this.reports.filter((candidate) => candidate.id !== report.id);
      this.message = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyReportId = null;
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
    {{#if this.isAdmin}}
      <section class="csl-panel csl-report-moderation" aria-labelledby="csl-report-moderation-title">
        <header>
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.reporting.admin_eyebrow"}}</p>
            <h2 id="csl-report-moderation-title">{{i18n "crimson_server_list.reporting.admin_title"}}</h2>
          </div>
          {{#if this.hasLoaded}}
            <p>{{i18n "crimson_server_list.reporting.pending_count" count=this.reports.length}}</p>
          {{/if}}
        </header>

        <div class="csl-form__actions">
          <button class="csl-button" type="button" aria-expanded={{this.isOpen}} {{on "click" this.toggle}}>
            {{if this.isOpen
              (i18n "crimson_server_list.reporting.admin_close")
              (i18n "crimson_server_list.reporting.admin_open")}}
          </button>
          {{#if this.isOpen}}
            <button class="csl-button" type="button" disabled={{this.isLoading}} {{on "click" this.reload}}>
              {{i18n "crimson_server_list.reporting.reload"}}
            </button>
          {{/if}}
        </div>

        {{#if this.message}}
          <p class="csl-notice csl-notice--success" role="status">{{this.message}}</p>
        {{/if}}
        {{#if this.errorMessage}}
          <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
        {{/if}}

        {{#if this.isOpen}}
          {{#if this.isLoading}}
            <p class="csl-empty csl-empty--compact">{{i18n "crimson_server_list.reporting.loading"}}</p>
          {{else}}
            {{#each this.reports as |report|}}
              <article class="csl-pending-row csl-report-row">
                <div>
                  <strong><a href={{report.server.detail_url}}>{{report.server.name}}</a></strong>
                  <span>
                    {{i18n "crimson_server_list.reporting.reported_by" username=report.reporter.username}}
                    · {{i18n (concat "crimson_server_list.reporting.reason_" report.reason)}}
                  </span>
                  {{#if report.details}}<p>{{report.details}}</p>{{/if}}
                  <small>{{report.created_at}}</small>
                </div>
                <div class="csl-pending-row__actions">
                  <button
                    class="csl-button"
                    type="button"
                    disabled={{this.busyReportId}}
                    {{on "click" (fn this.dismiss report)}}
                  >
                    {{i18n "crimson_server_list.reporting.dismiss"}}
                  </button>
                  <button
                    class="csl-button csl-button--primary"
                    type="button"
                    disabled={{this.busyReportId}}
                    {{on "click" (fn this.resolve report)}}
                  >
                    {{i18n "crimson_server_list.reporting.resolve"}}
                  </button>
                </div>
              </article>
            {{else}}
              <p class="csl-empty csl-empty--compact">{{i18n "crimson_server_list.reporting.empty"}}</p>
            {{/each}}
          {{/if}}
        {{/if}}
      </section>
    {{/if}}
  </template>
}
