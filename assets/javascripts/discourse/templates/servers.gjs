import RouteTemplate from "ember-route-template";
import CrimsonServerList from "../components/crimson-server-list";

export default RouteTemplate(
  <template>
    <CrimsonServerList @model={{@model}} />
  </template>,
);
