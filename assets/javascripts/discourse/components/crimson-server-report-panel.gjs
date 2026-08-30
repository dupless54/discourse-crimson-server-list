import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import CrimsonServerReportModal from "./modal/crimson-server-report";

export default class CrimsonServerReportPanel extends Component {
  @service siteSettings;
  @service modal;

  @tracked submitted = false;
  @tracked message = "";

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

  @action
  openReport() {
    this.modal.show(CrimsonServerReportModal, {
      model: {
        server: this.server,
        onSubmitted: this.reportSubmitted,
      },
    });
  }

  @action
  reportSubmitted(response) {
    this.submitted = true;
    this.message = response.message;
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

        {{#unless this.submitted}}
          <button class="csl-button" type="button" {{on "click" this.openReport}}>
            {{i18n "crimson_server_list.reporting.open"}}
          </button>
        {{/unless}}
      </section>
    {{/if}}
  </template>
}
