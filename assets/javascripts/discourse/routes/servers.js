import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class ServersRoute extends DiscourseRoute {
  model() {
    return ajax("/crimson-server-list.json");
  }

  titleToken() {
    return "Private Server Top Listesi";
  }

  activate() {
    document.body.classList.add("crimson-server-list-route");
  }

  deactivate() {
    document.body.classList.remove("crimson-server-list-route");
  }
}
