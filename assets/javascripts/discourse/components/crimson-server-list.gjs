import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";

export default class CrimsonServerList extends Component {
  @tracked servers = this.args.model?.servers || [];
  @tracked pendingServers = this.args.model?.pending_servers || [];
  @tracked games = this.args.model?.games || [];
  @tracked stats = this.args.model?.stats || {};
  @tracked selectedGame = "all";
  @tracked searchQuery = "";
  @tracked sortMode = "top";
  @tracked showSubmit = false;
  @tracked showModeration = false;
  @tracked isSubmitting = false;
  @tracked busyServerId = null;
  @tracked announcement = "";
  @tracked errorMessage = "";

  get viewer() {
    return this.args.model?.viewer || {};
  }

  get visibleServers() {
    const needle = this.searchQuery.trim().toLocaleLowerCase("tr-TR");
    let servers = this.servers.filter((server) => {
      const gameMatches =
        this.selectedGame === "all" || server.game_slug === this.selectedGame;
      const haystack = [
        server.name,
        server.short_description,
        server.host,
        server.game?.name,
        server.mode,
        server.version,
      ]
        .filter(Boolean)
        .join(" ")
        .toLocaleLowerCase("tr-TR");

      return gameMatches && (!needle || haystack.includes(needle));
    });

    servers = [...servers].sort((left, right) => {
      if (this.sortMode === "new") {
        return Date.parse(right.created_at) - Date.parse(left.created_at);
      }

      if (this.sortMode === "players") {
        return (
          right.players_online - left.players_online ||
          right.vote_count - left.vote_count
        );
      }

      if (this.sortMode === "online") {
        return (
          Number(right.status === "online") - Number(left.status === "online") ||
          right.vote_count - left.vote_count
        );
      }

      return (
        Number(right.featured) - Number(left.featured) ||
        right.vote_count - left.vote_count ||
        right.players_online - left.players_online
      );
    });

    return servers.map((server, index) => ({ ...server, rank: index + 1 }));
  }

  @action
  selectGame(slug) {
    this.selectedGame = slug;
  }

  @action
  updateSearch(event) {
    this.searchQuery = event.currentTarget.value;
  }

  @action
  updateSort(event) {
    this.sortMode = event.currentTarget.value;
  }

  @action
  toggleSubmit() {
    this.showSubmit = !this.showSubmit;
    this.showModeration = false;
    this.clearMessages();
  }

  @action
  toggleModeration() {
    this.showModeration = !this.showModeration;
    this.showSubmit = false;
    this.clearMessages();
  }

  @action
  async submitServer(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());

    this.isSubmitting = true;
    this.clearMessages();

    try {
      const response = await ajax("/crimson-server-list/servers.json", {
        type: "POST",
        data,
      });

      this.announcement = response.message;
      form.reset();

      if (!response.pending) {
        this.publishServer(response.server);
      }

      this.showSubmit = false;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  @action
  async vote(server) {
    if (server.voted_today || this.busyServerId) {
      return;
    }

    this.busyServerId = server.id;
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/servers/${server.id}/vote.json`,
        { type: "POST" },
      );

      this.servers = this.servers.map((candidate) =>
        candidate.id === server.id
          ? {
              ...candidate,
              vote_count: response.vote_count,
              voted_today: true,
            }
          : candidate,
      );
      this.stats = {
        ...this.stats,
        vote_count: Number(this.stats.vote_count || 0) + 1,
      };
      this.announcement = response.message;
    } catch (error) {
      this.errorMessage = this.errorText(error);
    } finally {
      this.busyServerId = null;
    }
  }

  @action
  async approveServer(server) {
    await this.moderate(server, { approved: true, enabled: true }, true);
  }

  @action
  async rejectServer(server) {
    await this.moderate(server, { approved: false, enabled: false }, false);
  }

  @action
  async copyAddress(server) {
    try {
      await navigator.clipboard.writeText(server.address);
      this.clearMessages();
      this.announcement = `${server.address} kopyalandı.`;
    } catch {
      this.errorMessage = "Adres kopyalanamadı; elle seçip kopyalayabilirsin.";
    }
  }

  async moderate(server, data, publish) {
    if (this.busyServerId) {
      return;
    }

    this.busyServerId = server.id;
    this.clearMessages();

    try {
      const response = await ajax(
        `/crimson-server-list/admin/servers/${server.id}.json`,
        { type: "PUT", data },
      );

      this.pendingServers = this.pendingServers.filter(
        (candidate) => candidate.id !== server.id,
      );

      if (publish) {
        this.publishServer(response.server);
        this.announcement = `${server.name} yayınlandı.`;
      } else {
        this.announcement = `${server.name} başvurusu reddedildi.`;
      }
    } catch (error) {
      this.errorMessage = this.errorText(error);
      popupAjaxError(error);
    } finally {
      this.busyServerId = null;
    }
  }

  clearMessages() {
    this.announcement = "";
    this.errorMessage = "";
  }

  publishServer(server) {
    const gameWasEmpty = !this.servers.some(
      (candidate) => candidate.game_slug === server.game_slug,
    );

    this.servers = [server, ...this.servers];
    this.games = this.games.map((game) =>
      game.slug === server.game_slug
        ? { ...game, server_count: Number(game.server_count || 0) + 1 }
        : game,
    );
    this.stats = {
      ...this.stats,
      server_count: Number(this.stats.server_count || 0) + 1,
      game_count:
        Number(this.stats.game_count || 0) + (gameWasEmpty ? 1 : 0),
    };
  }

  errorText(error) {
    return (
      error?.jqXHR?.responseJSON?.errors?.join(" ") ||
      error?.responseJSON?.errors?.join(" ") ||
      "İşlem tamamlanamadı. Lütfen yeniden dene."
    );
  }

  <template>
    <main class="csl-page">
      <section class="csl-hero" aria-labelledby="csl-title">
        <div class="csl-hero__copy">
          <p class="csl-eyebrow">SENİN.ME OYUN TOPLULUĞU</p>
          <h1 id="csl-title">Private Server Top Listesi</h1>
          <p>
            Topluluğun önerdiği özel oyun sunucularını keşfet, filtrele ve her
            gün favorine oy ver.
          </p>
        </div>

        <div class="csl-hero__actions">
          {{#if this.viewer.can_submit}}
            <button class="csl-button csl-button--primary" type="button" {{on "click" this.toggleSubmit}}>
              {{if this.showSubmit "Formu kapat" "Sunucu ekle"}}
            </button>
          {{else if this.viewer.logged_in}}
            <span class="csl-button csl-button--disabled">Başvurular kapalı</span>
          {{else}}
            <a class="csl-button csl-button--primary" href="/login?return_path=%2Fservers">Giriş yap ve ekle</a>
          {{/if}}

          {{#if this.viewer.is_admin}}
            <button class="csl-button" type="button" {{on "click" this.toggleModeration}}>
              Onay kuyruğu
              <span class="csl-button__count">{{this.pendingServers.length}}</span>
            </button>
          {{/if}}
        </div>
      </section>

      <section class="csl-stats" aria-label="Top liste özeti">
        <article><strong>{{this.stats.server_count}}</strong><span>yayındaki sunucu</span></article>
        <article><strong>{{this.stats.vote_count}}</strong><span>toplam oy</span></article>
        <article><strong>{{this.stats.online_count}}</strong><span>çevrimiçi işaretli</span></article>
        <article><strong>{{this.stats.game_count}}</strong><span>aktif oyun</span></article>
      </section>

      {{#if this.announcement}}
        <p class="csl-notice csl-notice--success" role="status">{{this.announcement}}</p>
      {{/if}}
      {{#if this.errorMessage}}
        <p class="csl-notice csl-notice--error" role="alert">{{this.errorMessage}}</p>
      {{/if}}

      {{#if this.showSubmit}}
        <section class="csl-panel csl-submit" aria-labelledby="csl-submit-title">
          <header>
            <div>
              <p class="csl-eyebrow">YENİ BAŞVURU</p>
              <h2 id="csl-submit-title">Sunucunu listeye gönder</h2>
            </div>
            <p>Başvurular yayınlanmadan önce yönetici tarafından incelenir.</p>
          </header>

          <form class="csl-form" {{on "submit" this.submitServer}}>
            <label>
              <span>Oyun</span>
              <select name="game_slug" required>
                {{#each this.games as |game|}}
                  <option value={{game.slug}}>{{game.icon}} {{game.name}}</option>
                {{/each}}
              </select>
            </label>
            <label>
              <span>Sunucu adı</span>
              <input name="name" maxlength="100" required placeholder="Örn. CrimsonCraft" />
            </label>
            <label class="csl-form__wide">
              <span>Kısa açıklama</span>
              <input name="short_description" maxlength="180" required placeholder="Sunucuyu tek cümlede anlat" />
            </label>
            <label>
              <span>Sunucu adresi</span>
              <input name="host" maxlength="255" required placeholder="play.ornek.com" inputmode="url" />
            </label>
            <label>
              <span>Port</span>
              <input name="port" type="number" min="1" max="65535" required placeholder="25565" />
            </label>
            <label>
              <span>Dil</span>
              <input name="language" maxlength="60" placeholder="Türkçe" />
            </label>
            <label>
              <span>Ülke kodu</span>
              <input name="country_code" maxlength="2" placeholder="TR" />
            </label>
            <label>
              <span>Sürüm</span>
              <input name="version" maxlength="60" placeholder="1.21 / Classic / Season 3" />
            </label>
            <label>
              <span>Oyun modu</span>
              <input name="mode" maxlength="60" placeholder="Survival, Roleplay, PvP…" />
            </label>
            <label class="csl-form__wide">
              <span>Web sitesi</span>
              <input name="website_url" type="url" placeholder="https://…" />
            </label>
            <label class="csl-form__wide">
              <span>Discord daveti</span>
              <input name="discord_url" type="url" placeholder="https://discord.gg/…" />
            </label>
            <label class="csl-form__wide">
              <span>Banner görseli</span>
              <input name="banner_url" type="url" placeholder="https://…/banner.webp" />
            </label>
            <label class="csl-form__wide">
              <span>Detaylı açıklama</span>
              <textarea name="description" maxlength="4000" rows="4" placeholder="Özellikler, kurallar ve topluluk hakkında bilgi"></textarea>
            </label>
            <div class="csl-form__actions csl-form__wide">
              <button class="csl-button" type="button" {{on "click" this.toggleSubmit}}>Vazgeç</button>
              <button class="csl-button csl-button--primary" type="submit" disabled={{this.isSubmitting}}>
                {{if this.isSubmitting "Gönderiliyor…" "Onaya gönder"}}
              </button>
            </div>
          </form>
        </section>
      {{/if}}

      {{#if this.showModeration}}
        <section class="csl-panel csl-moderation" aria-labelledby="csl-moderation-title">
          <header>
            <div>
              <p class="csl-eyebrow">YÖNETİCİ</p>
              <h2 id="csl-moderation-title">Onay kuyruğu</h2>
            </div>
            <p>{{this.pendingServers.length}} bekleyen başvuru</p>
          </header>

          {{#each this.pendingServers as |server|}}
            <article class="csl-pending-row">
              <div class="csl-game-icon csl-game--{{server.game_slug}}" aria-hidden="true">{{server.game.icon}}</div>
              <div>
                <strong>{{server.name}}</strong>
                <span>{{server.game.name}} · {{server.address}} · @{{server.owner.username}}</span>
                <p>{{server.short_description}}</p>
              </div>
              <div class="csl-pending-row__actions">
                <button class="csl-button" type="button" disabled={{eq this.busyServerId server.id}} {{on "click" (fn this.rejectServer server)}}>Reddet</button>
                <button class="csl-button csl-button--primary" type="button" disabled={{eq this.busyServerId server.id}} {{on "click" (fn this.approveServer server)}}>Yayınla</button>
              </div>
            </article>
          {{else}}
            <p class="csl-empty csl-empty--compact">Onay bekleyen sunucu yok.</p>
          {{/each}}
        </section>
      {{/if}}

      <section class="csl-discovery" aria-label="Sunucu filtreleri">
        <div class="csl-game-filter" role="list" aria-label="Oyunlar">
          <button class={{if (eq this.selectedGame "all") "is-active" ""}} type="button" {{on "click" (fn this.selectGame "all")}}>
            <span class="csl-game-filter__all">∞</span>
            <strong>Tümü</strong>
            <small>{{this.stats.server_count}}</small>
          </button>
          {{#each this.games as |game|}}
            <button class="csl-game--{{game.slug}} {{if (eq this.selectedGame game.slug) "is-active" ""}}" type="button" {{on "click" (fn this.selectGame game.slug)}}>
              <span>{{game.icon}}</span>
              <strong>{{game.name}}</strong>
              <small>{{game.server_count}}</small>
            </button>
          {{/each}}
        </div>

        <div class="csl-toolbar">
          <label class="csl-search">
            <span class="sr-only">Sunucu ara</span>
            <input type="search" value={{this.searchQuery}} placeholder="Sunucu adı, oyun veya adres ara…" {{on "input" this.updateSearch}} />
          </label>
          <label class="csl-sort">
            <span>Sırala</span>
            <select value={{this.sortMode}} {{on "change" this.updateSort}}>
              <option value="top">En yüksek oy</option>
              <option value="online">Çevrimiçi</option>
              <option value="players">Oyuncu sayısı</option>
              <option value="new">En yeni</option>
            </select>
          </label>
        </div>
      </section>

      <section class="csl-server-list" aria-live="polite">
        {{#each this.visibleServers as |server|}}
          <article class="csl-server-card csl-game--{{server.game_slug}}">
            <div class="csl-rank" aria-label="Sıra {{server.rank}}">
              <span>#</span>{{server.rank}}
            </div>

            <div class="csl-server-card__visual">
              {{#if server.banner_url}}
                <img src={{server.banner_url}} alt="" loading="lazy" />
              {{else}}
                <div class="csl-server-card__fallback" aria-hidden="true">{{server.game.icon}}</div>
              {{/if}}
              <span class="csl-game-label">{{server.game.icon}} {{server.game.name}}</span>
            </div>

            <div class="csl-server-card__body">
              <header>
                <div>
                  <h2>{{server.name}}</h2>
                  <p>{{server.short_description}}</p>
                </div>
                {{#if server.featured}}<span class="csl-featured">ÖNE ÇIKAN</span>{{/if}}
              </header>

              <div class="csl-meta">
                <span class="csl-status csl-status--{{server.status}}"><i></i>{{server.status_label}}</span>
                {{#if server.language}}<span>{{server.language}}</span>{{/if}}
                {{#if server.version}}<span>{{server.version}}</span>{{/if}}
                {{#if server.mode}}<span>{{server.mode}}</span>{{/if}}
              </div>

              <div class="csl-address">
                <code>{{server.address}}</code>
                <button type="button" {{on "click" (fn this.copyAddress server)}} aria-label="Sunucu adresini kopyala">Kopyala</button>
              </div>

              {{#if server.description}}
                <details class="csl-description">
                  <summary>Sunucu ayrıntıları</summary>
                  <p>{{server.description}}</p>
                </details>
              {{/if}}

              <footer>
                <div class="csl-owner">
                  {{#if server.owner.avatar_url}}<img src={{server.owner.avatar_url}} alt="" loading="lazy" />{{/if}}
                  <span>@{{server.owner.username}} tarafından eklendi</span>
                </div>
                <nav aria-label="Sunucu bağlantıları">
                  {{#if server.website_url}}<a href={{server.website_url}} target="_blank" rel="noopener noreferrer">Web</a>{{/if}}
                  {{#if server.discord_url}}<a href={{server.discord_url}} target="_blank" rel="noopener noreferrer">Discord</a>{{/if}}
                </nav>
              </footer>
            </div>

            <aside class="csl-server-card__score">
              <div class="csl-players">
                {{#if server.players_max}}
                  <strong>{{server.players_online}}</strong>
                  <span>/ {{server.players_max}} oyuncu</span>
                {{else}}
                  <strong>—</strong>
                  <span>oyuncu bilgisi yok</span>
                {{/if}}
              </div>
              <div class="csl-votes">
                <strong>{{server.vote_count}}</strong>
                <span>oy</span>
              </div>
              {{#if this.viewer.can_vote}}
                <button class="csl-vote-button {{if server.voted_today "is-voted" ""}}" type="button" disabled={{server.voted_today}} aria-pressed={{server.voted_today}} {{on "click" (fn this.vote server)}}>
                  {{if server.voted_today "Bugün oylandı" "Oy ver"}}
                </button>
              {{else if this.viewer.logged_in}}
                <span class="csl-vote-button is-disabled">Oylama kapalı</span>
              {{else}}
                <a class="csl-vote-button" href="/login?return_path=%2Fservers">Oy vermek için giriş yap</a>
              {{/if}}
            </aside>
          </article>
        {{else}}
          <div class="csl-empty">
            <span aria-hidden="true">⌁</span>
            <h2>Eşleşen sunucu bulunamadı</h2>
            <p>Arama metnini veya oyun filtresini değiştirmeyi dene.</p>
          </div>
        {{/each}}
      </section>

      <p class="csl-footnote">
        Çevrimiçi durumu ve oyuncu sayıları bu ilk sürümde yönetici tarafından
        doğrulanır; sunuculara otomatik ağ isteği gönderilmez.
      </p>
    </main>
  </template>
}
