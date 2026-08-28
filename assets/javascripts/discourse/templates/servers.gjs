import RouteTemplate from "ember-route-template";
import CrimsonServerList from "../components/crimson-server-list";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap">
      <CrimsonServerList @model={{@model}} />
    </div>
  </template>,
);
