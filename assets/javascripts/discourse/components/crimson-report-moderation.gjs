import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CrimsonReportModeration extends Component {
  @tracked isLoading = false;
  @tracked hasLoaded = false;
  @tracked reports = [];
  @tracked busyReportId = null;
  @tracked message = "";
  @tracked errorMessage = "";

  constructor(owner, args) {
    super(owner, args);

    if (this.isAdmin) {
      scheduleOnce("afterRender", this, this.loadReports);
    }
  }

  get isAdmin() {
    return Boolean(this.args.viewer?.is_admin);
  }

  get moderationBusy() {
    return Boolean(this.busyReportId);
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

  @action
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
    if (this.moderationBusy) {
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
        <header class="csl-v3-panel-heading">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.reporting.admin_eyebrow"}}</p>
            <h2 id="csl-report-moderation-title">{{i18n "crimson_server_list.reporting.admin_title"}}</h2>
            <p>{{i18n "crimson_server_list.v3_admin.reports_description"}}</p>
          </div>
          <div class="csl-v3-panel-heading__actions">
            {{#if this.hasLoaded}}
              <span class="csl-v3-panel-count">{{i18n "crimson_server_list.reporting.pending_count" count=this.reports.length}}</span>
            {{/if}}
            <DButton
              @action={{this.reload}}
              @label="crimson_server_list.reporting.reload"
              @isLoading={{this.isLoading}}
              class="csl-button csl-v3-admin-refresh"
            />
          </div>
        </header>

        {{#if this.message}}
          <p class="csl-notice csl-notice--success" role="status">{{this.message}}</p>
        {{/if}}
        {{#if this.errorMessage}}
          <div class="csl-v3-panel-error">
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
            {{#unless this.hasLoaded}}
              <DButton
                @action={{this.reload}}
                @label="crimson_server_list.owner_panel.retry"
                class="csl-button"
              />
            {{/unless}}
          </div>
        {{/if}}

        {{#if this.isLoading}}
          <div class="csl-v3-tab-loading" role="status">
            <span class="csl-v3-loading-dot" aria-hidden="true"></span>
            {{i18n "crimson_server_list.reporting.loading"}}
          </div>
        {{else if this.hasLoaded}}
          <div class="csl-v3-report-list">
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
                  <DButton
                    @action={{fn this.dismiss report}}
                    @label="crimson_server_list.reporting.dismiss"
                    @disabled={{this.moderationBusy}}
                    @isLoading={{eq this.busyReportId report.id}}
                    class="csl-button"
                  />
                  <DButton
                    @action={{fn this.resolve report}}
                    @label="crimson_server_list.reporting.resolve"
                    @disabled={{this.moderationBusy}}
                    @isLoading={{eq this.busyReportId report.id}}
                    class="csl-button csl-button--primary"
                  />
                </div>
              </article>
            {{else}}
              <div class="csl-empty csl-empty--compact csl-v3-tab-empty">
                <p>{{i18n "crimson_server_list.reporting.empty"}}</p>
              </div>
            {{/each}}
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
