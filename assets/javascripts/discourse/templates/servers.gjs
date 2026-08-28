import RouteTemplate from "ember-route-template";
import CrimsonReportModeration from "../components/crimson-report-moderation";
import CrimsonServerFavoritesPanel from "../components/crimson-server-favorites-panel";
import CrimsonServerList from "../components/crimson-server-list";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap">
      <CrimsonReportModeration @viewer={{@model.viewer}} />
      <CrimsonServerFavoritesPanel @viewer={{@model.viewer}} />
      <CrimsonServerList @model={{@model}} />
    </div>
  </template>,
);
