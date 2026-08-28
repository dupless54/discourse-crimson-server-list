import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CrimsonVerifiedBadge extends Component {
  <template>
    {{#if @server.verified}}
      <span
        class="csl-verified-badge"
        title={{i18n "crimson_server_list.verification.badge_title"}}
      >
        {{dIcon "circle-check"}}
        <span>{{i18n "crimson_server_list.verification.badge"}}</span>
      </span>
    {{/if}}
  </template>
}
