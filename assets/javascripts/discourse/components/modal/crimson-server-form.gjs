import Component from "@glimmer/component";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class CrimsonServerFormModal extends Component {
  @tracked selectedGameSlug =
    this.args.model?.server?.game_slug ||
    this.args.model?.games?.[0]?.slug ||
    "minecraft";
  @tracked isSubmitting = false;
  @tracked errorMessage = "";
  @tracked result = null;

  get mode() {
    return this.args.model?.mode === "edit" ? "edit" : "create";
  }

  get isEdit() {
    return this.mode === "edit";
  }

  get server() {
    return this.args.model?.server || {};
  }

  get games() {
    return this.args.model?.games || [];
  }

  get title() {
    return i18n(
      this.isEdit
        ? "crimson_server_list.server_form.edit_title"
        : "crimson_server_list.server_form.create_title",
    );
  }

  get intro() {
    return i18n(
      this.isEdit
        ? "crimson_server_list.server_form.edit_intro"
        : "crimson_server_list.server_form.create_intro",
    );
  }

  get submitLabel() {
    if (this.isSubmitting) {
      return i18n("crimson_server_list.server_form.saving");
    }

    return i18n(
      this.isEdit
        ? "crimson_server_list.server_form.save_changes"
        : "crimson_server_list.server_form.submit_for_review",
    );
  }

  get gameFields() {
    const game = this.games.find(
      (candidate) => candidate.slug === this.selectedGameSlug,
    );
    const values =
      this.isEdit && this.selectedGameSlug === this.server.game_slug
        ? this.server.game_details || {}
        : {};

    return (game?.fields || []).map((field) => ({
      ...field,
      inputName: `game_detail__${field.key}`,
      label: i18n(
        `crimson_server_list.server_form.field_labels.${field.key}`,
      ),
      placeholder:
        field.key === "wipe_schedule"
          ? i18n("crimson_server_list.server_form.field_placeholders.wipe_schedule")
          : field.placeholder,
      unit:
        field.key === "group_limit"
          ? i18n("crimson_server_list.server_form.field_units.people")
          : field.unit,
      value: values[field.key] ?? "",
    }));
  }

  get monitoringChecked() {
    return this.isEdit ? Boolean(this.server.monitoring_enabled) : true;
  }

  @action
  updateGame(event) {
    this.selectedGameSlug = event.currentTarget.value;
  }

  @action
  async submit(_actionParam, event) {
    if (this.isSubmitting) {
      return;
    }

    const form = event?.currentTarget?.form || event?.currentTarget;
    if (!(form instanceof HTMLFormElement)) {
      this.errorMessage = i18n("crimson_server_list.server_form.generic_error");
      return;
    }

    const data = this.serverFormData(form);
    this.isSubmitting = true;
    this.errorMessage = "";

    try {
      const response = this.isEdit
        ? await ajax(`/crimson-server-list/servers/${this.server.id}.json`, {
            type: "PUT",
            data,
          })
        : await ajax("/crimson-server-list/servers.json", {
            type: "POST",
            data,
          });

      if (this.isEdit) {
        this.args.model?.onSaved?.(response.server, response);
        this.args.closeModal(response);
        return;
      }

      this.args.model?.onSubmitted?.(response);
      this.result = response;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  serverFormData(form) {
    const data = Object.fromEntries(new FormData(form).entries());
    const gameDetails = {};

    for (const [key, value] of Object.entries(data)) {
      if (key.startsWith("game_detail__")) {
        const detailKey = key.slice("game_detail__".length);
        const normalized = String(value || "").trim();
        if (normalized) {
          gameDetails[detailKey] = normalized;
        }
        delete data[key];
      }
    }

    data.game_details = gameDetails;
    data.monitoring_enabled = Boolean(form.elements.monitoring_enabled?.checked);
    data.banner_url = form.elements.banner_url?.value?.trim() || "";
    return data;
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      i18n("crimson_server_list.server_form.generic_error")
    );
  }

  <template>
    <DModal
      class="csl-server-form-modal --large"
      @title={{this.title}}
      @closeModal={{@closeModal}}
      @tagName="form"
    >
      <:body>
        {{#if this.result}}
          <div class="csl-server-form-success" role="status">
            <div class="csl-server-form-success__mark" aria-hidden="true">✓</div>
            <div>
              <h3>{{i18n "crimson_server_list.server_form.success_title"}}</h3>
              <p>{{this.result.message}}</p>
              {{#if this.result.server.detail_url}}
                <a class="csl-button" href={{this.result.server.detail_url}}>
                  {{i18n "crimson_server_list.server_form.open_submission"}}
                </a>
              {{/if}}
            </div>
          </div>
        {{else}}
          <div class="csl-server-form-intro">
            <p>{{this.intro}}</p>
            <span>{{i18n "crimson_server_list.server_form.safety_note"}}</span>
          </div>

          {{#if this.errorMessage}}
            <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
          {{/if}}

          <div class="csl-modal-form">
            <fieldset class="csl-modal-form__section">
              <legend>
                <span>{{i18n "crimson_server_list.server_form.identity_title"}}</span>
                <small>{{i18n "crimson_server_list.server_form.identity_description"}}</small>
              </legend>

              <div class="csl-modal-form__grid">
                <label>
                  <span>{{i18n "crimson_server_list.server_form.game"}}</span>
                  <select name="game_slug" required {{on "change" this.updateGame}}>
                    {{#each this.games as |game|}}
                      <option value={{game.slug}} selected={{eq game.slug this.selectedGameSlug}}>
                        {{game.icon}} {{game.name}}
                      </option>
                    {{/each}}
                  </select>
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.name"}}</span>
                  <input
                    name="name"
                    value={{this.server.name}}
                    maxlength="100"
                    required
                    placeholder={{i18n "crimson_server_list.server_form.name_placeholder"}}
                  />
                </label>
                <label class="csl-modal-form__wide">
                  <span>{{i18n "crimson_server_list.server_form.short_description"}}</span>
                  <input
                    name="short_description"
                    value={{this.server.short_description}}
                    maxlength="180"
                    required
                    placeholder={{i18n "crimson_server_list.server_form.short_description_placeholder"}}
                  />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.language"}}</span>
                  <input name="language" value={{this.server.language}} maxlength="60" placeholder={{i18n "crimson_server_list.server_form.language_placeholder"}} />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.country_code"}}</span>
                  <input name="country_code" value={{this.server.country_code}} maxlength="2" placeholder={{i18n "crimson_server_list.server_form.country_code_placeholder"}} />
                </label>
              </div>
            </fieldset>

            <fieldset class="csl-modal-form__section">
              <legend>
                <span>{{i18n "crimson_server_list.server_form.connection_title"}}</span>
                <small>{{i18n "crimson_server_list.server_form.connection_description"}}</small>
              </legend>

              <div class="csl-modal-form__grid csl-modal-form__grid--three">
                <label class="csl-modal-form__span-two">
                  <span>{{i18n "crimson_server_list.server_form.host"}}</span>
                  <input
                    name="host"
                    value={{this.server.host}}
                    maxlength="255"
                    required
                    placeholder="play.example.com"
                    inputmode="url"
                  />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.port"}}</span>
                  <input name="port" value={{this.server.port}} type="number" min="1" max="65535" required placeholder="25565" />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.query_port"}}</span>
                  <input name="query_port" value={{this.server.query_port}} type="number" min="1" max="65535" placeholder="25565" />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.version"}}</span>
                  <input name="version" value={{this.server.version}} maxlength="60" placeholder="1.21 / Classic" />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.mode"}}</span>
                  <input name="mode" value={{this.server.mode}} maxlength="60" placeholder="Survival / Roleplay / PvP" />
                </label>
                <label class="csl-modal-form__check csl-modal-form__wide">
                  <input name="monitoring_enabled" type="checkbox" checked={{this.monitoringChecked}} />
                  <span>
                    <strong>{{i18n "crimson_server_list.server_form.monitoring"}}</strong>
                    <small>{{i18n "crimson_server_list.server_form.monitoring_description"}}</small>
                  </span>
                </label>
              </div>
            </fieldset>

            {{#if this.gameFields.length}}
              <fieldset class="csl-modal-form__section">
                <legend>
                  <span>{{i18n "crimson_server_list.server_form.game_details_title"}}</span>
                  <small>{{i18n "crimson_server_list.server_form.game_details_description"}}</small>
                </legend>
                <div class="csl-modal-form__grid">
                  {{#each this.gameFields as |field|}}
                    <label>
                      <span>{{field.label}}{{#if field.unit}} ({{field.unit}}){{/if}}</span>
                      <input
                        name={{field.inputName}}
                        value={{field.value}}
                        type={{field.type}}
                        min={{field.min}}
                        max={{field.max}}
                        step={{field.step}}
                        maxlength="100"
                        placeholder={{field.placeholder}}
                      />
                    </label>
                  {{/each}}
                </div>
              </fieldset>
            {{/if}}

            <fieldset class="csl-modal-form__section">
              <legend>
                <span>{{i18n "crimson_server_list.server_form.presentation_title"}}</span>
                <small>{{i18n "crimson_server_list.server_form.presentation_description"}}</small>
              </legend>

              <div class="csl-modal-form__grid">
                <label class="csl-modal-form__wide">
                  <span>{{i18n "crimson_server_list.server_form.tags"}}</span>
                  <input
                    name="tags"
                    value={{this.server.tags_csv}}
                    maxlength="300"
                    placeholder={{i18n "crimson_server_list.server_form.tags_placeholder"}}
                  />
                  <small>{{i18n "crimson_server_list.server_form.tags_help"}}</small>
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.website"}}</span>
                  <input name="website_url" value={{this.server.website_url}} type="url" placeholder="https://…" />
                </label>
                <label>
                  <span>{{i18n "crimson_server_list.server_form.discord"}}</span>
                  <input name="discord_url" value={{this.server.discord_url}} type="url" placeholder="https://discord.gg/…" />
                </label>
                <label class="csl-modal-form__wide">
                  <span>{{i18n "crimson_server_list.server_form.banner"}}</span>
                  <input
                    name="banner_url"
                    value={{this.server.banner_url}}
                    type="text"
                    inputmode="url"
                    autocomplete="off"
                    placeholder="https://…/banner.webp"
                  />
                  <small>{{i18n "crimson_server_list.server_form.banner_help"}}</small>
                </label>
                <label class="csl-modal-form__wide">
                  <span>{{i18n "crimson_server_list.server_form.description"}}</span>
                  <textarea
                    name="description"
                    value={{this.server.description}}
                    maxlength="4000"
                    rows="6"
                    placeholder={{i18n "crimson_server_list.server_form.description_placeholder"}}
                  ></textarea>
                </label>
              </div>
            </fieldset>
          </div>
        {{/if}}
      </:body>

      <:footer>
        {{#if this.result}}
          <DButton
            @action={{@closeModal}}
            @label="crimson_server_list.server_form.close"
            class="btn-primary"
          />
        {{else}}
          <DButton
            @action={{@closeModal}}
            @label="crimson_server_list.server_form.cancel"
            @disabled={{this.isSubmitting}}
          />
          <DButton
            @action={{this.submit}}
            @forwardEvent={{true}}
            @translatedLabel={{this.submitLabel}}
            @type="submit"
            @isLoading={{this.isSubmitting}}
            class="btn-primary"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
