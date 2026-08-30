import RouteTemplate from "ember-route-template";
import CrimsonReportModeration from "../components/crimson-report-moderation";
import CrimsonServerDiscoveryPanel from "../components/crimson-server-discovery-panel";
import CrimsonServerFeaturedStrip from "../components/crimson-server-featured-strip";
import CrimsonServerFavoritesPanel from "../components/crimson-server-favorites-panel";
import CrimsonServerList from "../components/crimson-server-list";
import CrimsonServerOwnerPanel from "../components/crimson-server-owner-panel";
import CrimsonServerV3Nav from "../components/crimson-server-v3-nav";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap csl-route-wrap--paginated-discovery">
      <CrimsonServerV3Nav @viewer={{@model.viewer}} />

      <section id="csl-v3-discover" class="csl-v3-route-section">
        <CrimsonServerList @model={{@model}} />
        <CrimsonServerFeaturedStrip @servers={{@model.servers}} />
        <CrimsonServerDiscoveryPanel @model={{@model}} />
      </section>

      {{#if @model.viewer.logged_in}}
        <section id="csl-v3-favorites" class="csl-v3-route-section csl-v3-route-section--secondary">
          <CrimsonServerFavoritesPanel @viewer={{@model.viewer}} />
        </section>

        <section id="csl-v3-owned" class="csl-v3-route-section csl-v3-route-section--secondary">
          <CrimsonServerOwnerPanel @viewer={{@model.viewer}} />
        </section>
      {{/if}}

      {{#if @model.viewer.is_admin}}
        <section id="csl-v3-admin" class="csl-v3-route-section csl-v3-route-section--secondary">
          <CrimsonReportModeration @viewer={{@model.viewer}} />
        </section>
      {{/if}}
    </div>
  </template>,
);
