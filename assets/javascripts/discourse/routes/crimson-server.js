import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class CrimsonServerRoute extends DiscourseRoute {
  model(params) {
    return ajax(
      `/crimson-server-list/servers/${encodeURIComponent(params.slug)}.json`,
    );
  }

  titleToken() {
    return this.currentModel?.server?.name || "Sunucu tanıtımı";
  }

  activate() {
    document.body.classList.add("crimson-server-list-route");
    document.body.classList.add("crimson-server-detail-route");
  }

  deactivate() {
    document.body.classList.remove("crimson-server-list-route");
    document.body.classList.remove("crimson-server-detail-route");
  }
}
