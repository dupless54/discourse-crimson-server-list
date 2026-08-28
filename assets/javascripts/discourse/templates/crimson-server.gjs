import RouteTemplate from "ember-route-template";
import CrimsonServerDetail from "../components/crimson-server-detail";
import CrimsonServerReportPanel from "../components/crimson-server-report-panel";
import CrimsonServerUptimePanel from "../components/crimson-server-uptime-panel";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap">
      <CrimsonServerDetail @model={{@model}} />
      <CrimsonServerUptimePanel @model={{@model}} />
      <CrimsonServerReportPanel @model={{@model}} />
    </div>
  </template>,
);
