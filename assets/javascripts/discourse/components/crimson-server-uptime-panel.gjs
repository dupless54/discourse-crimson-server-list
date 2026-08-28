import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CrimsonServerUptimePanel extends Component {
  @service siteSettings;

  @tracked selectedRange = "24h";
  @tracked history = null;
  @tracked isLoading = false;
  @tracked errorMessage = "";

  constructor() {
    super(...arguments);

    if (this.isEnabled && this.server.id) {
      void this.loadHistory();
    }
  }

  get server() {
    return this.args.model?.server || {};
  }

  get isEnabled() {
    return Boolean(this.siteSettings.crimson_server_list_uptime_history_enabled);
  }

  get ranges() {
    return [
      { value: "24h", label: i18n("crimson_server_list.uptime.range_24h") },
      { value: "7d", label: i18n("crimson_server_list.uptime.range_7d") },
      { value: "30d", label: i18n("crimson_server_list.uptime.range_30d") },
    ];
  }

  get hasSamples() {
    return (this.history?.sample_count || 0) > 0;
  }

  get hasObservedSamples() {
    return (this.history?.known_sample_count || 0) > 0;
  }

  get uptimeLabel() {
    const value = this.history?.uptime_percent;
    return value === null || value === undefined ? "—" : `${value}%`;
  }

  get coverageLabel() {
    return i18n("crimson_server_list.uptime.coverage", {
      known: this.history?.known_sample_count || 0,
      total: this.history?.sample_count || 0,
    });
  }

  get timelineLabel() {
    return i18n("crimson_server_list.uptime.timeline_label", {
      range: this.rangeLabel(this.selectedRange),
    });
  }

  statusLabel(status) {
    return i18n(`crimson_server_list.uptime.status_${status || "unknown"}`);
  }

  pointLabel(point) {
    return `${this.statusLabel(point.status)} · ${point.sampled_at}`;
  }

  rangeLabel(value) {
    return this.ranges.find((range) => range.value === value)?.label || value;
  }

  @action
  async selectRange(value) {
    if (this.isLoading || value === this.selectedRange) {
      return;
    }

    this.selectedRange = value;
    await this.loadHistory();
  }

  async loadHistory() {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      this.history = await ajax(
        `/crimson-server-list/servers/${this.server.id}/uptime.json?range=${this.selectedRange}`,
      );
    } catch (error) {
      this.history = null;
      this.errorMessage =
        error?.jqXHR?.responseJSON?.errors?.join(" ") ||
        error?.responseJSON?.errors?.join(" ") ||
        i18n("crimson_server_list.uptime.generic_error");
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#if this.isEnabled}}
      <section class="csl-panel csl-uptime-panel" aria-labelledby="csl-uptime-title">
        <header class="csl-uptime-panel__header">
          <div>
            <p class="csl-eyebrow">{{i18n "crimson_server_list.uptime.eyebrow"}}</p>
            <h2 id="csl-uptime-title">{{i18n "crimson_server_list.uptime.title"}}</h2>
            <p>{{i18n "crimson_server_list.uptime.description"}}</p>
          </div>

          <div class="csl-uptime-ranges" aria-label={{i18n "crimson_server_list.uptime.range_label"}}>
            {{#each this.ranges as |range|}}
              <button
                type="button"
                class="csl-button {{if (eq range.value this.selectedRange) "is-active" ""}}"
                aria-pressed={{eq range.value this.selectedRange}}
                disabled={{this.isLoading}}
                {{on "click" (fn this.selectRange range.value)}}
              >
                {{range.label}}
              </button>
            {{/each}}
          </div>
        </header>

        {{#if this.errorMessage}}
          <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
        {{else if this.isLoading}}
          <p class="csl-empty csl-empty--compact" role="status">{{i18n "crimson_server_list.uptime.loading"}}</p>
        {{else if this.hasSamples}}
          <div class="csl-uptime-summary">
            <div>
              <strong>{{this.uptimeLabel}}</strong>
              <span>{{i18n "crimson_server_list.uptime.observed"}}</span>
            </div>
            <div>
              <strong>{{this.history.known_sample_count}}/{{this.history.sample_count}}</strong>
              <span>{{this.coverageLabel}}</span>
            </div>
          </div>

          {{#unless this.hasObservedSamples}}
            <p class="csl-uptime-note">{{i18n "crimson_server_list.uptime.no_observed"}}</p>
          {{/unless}}

          <div class="csl-uptime-timeline" role="img" aria-label={{this.timelineLabel}}>
            {{#each this.history.series as |point|}}
              <span
                class="csl-uptime-point csl-uptime-point--{{point.status}}"
                title={{this.pointLabel point}}
                aria-hidden="true"
              ></span>
            {{/each}}
          </div>

          <div class="csl-uptime-legend" aria-hidden="true">
            <span><i class="csl-uptime-point--online"></i>{{i18n "crimson_server_list.uptime.status_online"}}</span>
            <span><i class="csl-uptime-point--offline"></i>{{i18n "crimson_server_list.uptime.status_offline"}}</span>
            <span><i class="csl-uptime-point--unknown"></i>{{i18n "crimson_server_list.uptime.status_unknown"}}</span>
            <span><i class="csl-uptime-point--maintenance"></i>{{i18n "crimson_server_list.uptime.status_maintenance"}}</span>
          </div>
        {{else}}
          <p class="csl-empty csl-empty--compact">{{i18n "crimson_server_list.uptime.empty"}}</p>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
