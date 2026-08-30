import RouteTemplate from "ember-route-template";
import CrimsonServerV3Shell from "../components/crimson-server-v3-shell";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap csl-route-wrap--paginated-discovery">
      <CrimsonServerV3Shell @model={{@model}} />
    </div>
  </template>,
);
