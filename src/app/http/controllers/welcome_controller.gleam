import app/app.{type App}
import app/community/store as community
import app/content/store
import compiled/loom/article
import compiled/loom/welcome
import gleam/list
import gleam/result
import glimr/http/context.{type Context}
import glimr/http/response.{type Response}
import glimr/session

/// @get "/"
pub fn show(ctx: Context(App)) -> Response {
  let entries = store.published(ctx.app.db)
  let topics =
    entries
    |> list.map(fn(e) { e.category })
    |> list.append(["Crash Course"])
    |> list.unique
  welcome.render(entries: entries, topics: topics, saved_view: False)
  |> response.string_tree(200)
}

/// @get "/posts/:slug"
pub fn post(ctx: Context(App), slug: String) -> Response {
  case list.find(store.published(ctx.app.db), fn(post) { post.id == slug }) {
    Ok(post) -> article.render(post: post) |> response.string_tree(200)
    Error(_) -> response.not_found()
  }
}

/// @get "/bookmarks"
pub fn bookmarks(ctx: Context(App)) -> Response {
  let entries = case
    community.by_id(
      ctx.app.db,
      session.get(ctx.session, "community_user") |> result.unwrap(""),
    )
  {
    Error(_) -> []
    Ok(account) -> {
      let published = store.published(ctx.app.db)
      community.bookmark_ids(ctx.app.db, account.id)
      |> list.filter_map(fn(id) {
        list.find(published, fn(post) { post.id == id })
      })
    }
  }
  let topics = entries |> list.map(fn(post) { post.category }) |> list.unique
  welcome.render(entries: entries, topics: topics, saved_view: True)
  |> response.string_tree(200)
  |> response.header("cache-control", "no-store")
}
