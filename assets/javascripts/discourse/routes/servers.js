import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ServersRoute extends DiscourseRoute {
  model() {
    return ajax("/crimson-server-list/bootstrap.json");
  }

  titleToken() {
    return i18n("crimson_server_list.v3.page_title");
  }
}
