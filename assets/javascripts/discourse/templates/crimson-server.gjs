import RouteTemplate from "ember-route-template";
import CrimsonServerDetail from "../components/crimson-server-detail";

export default RouteTemplate(
  <template>
    <div class="wrap csl-route-wrap">
      <CrimsonServerDetail @model={{@model}} />
    </div>
  </template>,
);
