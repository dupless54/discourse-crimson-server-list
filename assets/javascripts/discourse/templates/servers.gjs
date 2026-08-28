import RouteTemplate from "ember-route-template";
import CrimsonReportModeration from "../components/crimson-report-moderation";
import CrimsonServerList from "../components/crimson-server-list";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap">
      <CrimsonReportModeration @viewer={{@model.viewer}} />
      <CrimsonServerList @model={{@model}} />
    </div>
  </template>,
);
