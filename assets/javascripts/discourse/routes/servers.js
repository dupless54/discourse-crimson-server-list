import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class ServersRoute extends DiscourseRoute {
  model() {
    return ajax("/crimson-server-list.json");
  }

  titleToken() {
    return "Özel Oyun Sunucuları";
  }
}
