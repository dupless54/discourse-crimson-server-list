import RouteTemplate from "ember-route-template";
import CrimsonReportModeration from "../components/crimson-report-moderation";
import CrimsonServerDiscoveryPanel from "../components/crimson-server-discovery-panel";
import CrimsonServerFavoritesPanel from "../components/crimson-server-favorites-panel";
import CrimsonServerList from "../components/crimson-server-list";
import CrimsonServerOwnerPanel from "../components/crimson-server-owner-panel";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap csl-route-wrap--paginated-discovery">
      <CrimsonReportModeration @viewer={{@model.viewer}} />
      <CrimsonServerOwnerPanel @viewer={{@model.viewer}} />
      <CrimsonServerFavoritesPanel @viewer={{@model.viewer}} />
      <CrimsonServerList @model={{@model}} />
      <CrimsonServerDiscoveryPanel @model={{@model}} />
    </div>
  </template>,
);
