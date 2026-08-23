import RouteTemplate from "ember-route-template";
import CrimsonServerDetail from "../components/crimson-server-detail";

export default RouteTemplate(
  <template>
    <CrimsonServerDetail @model={{@model}} />
  </template>,
);
