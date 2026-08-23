export default function crimsonServerListRoutes() {
  this.route("servers", { path: "/servers" });
  this.route("crimson-server", { path: "/servers/:slug" });
}
