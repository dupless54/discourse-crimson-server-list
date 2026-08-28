import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "crimson-server-list-follow-notifications",

  initialize() {
    withPluginApi((api) => {
      api.registerNotificationTypeRenderer(
        "crimson_server_back_online",
        (NotificationTypeBase) => {
          return class extends NotificationTypeBase {
            get label() {
              return i18n("crimson_server_list.notifications.back_online_label");
            }

            get description() {
              return this.notification.data.server_name;
            }

            get linkHref() {
              return this.notification.data.detail_url;
            }

            get linkTitle() {
              return i18n("crimson_server_list.notifications.back_online_title", {
                server: this.notification.data.server_name,
              });
            }

            get icon() {
              return "circle-check";
            }
          };
        },
      );
    });
  },
};
