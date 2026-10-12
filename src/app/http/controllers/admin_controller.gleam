import app/app.{type App}
import app/content/store
import compiled/loom/admin
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import glimr/config
import glimr/http/context.{type Context}
import glimr/http/response.{type Response}
import glimr/session
import wisp

fn message(text: String, status: Int) -> Response {
  json.object([#("message", json.string(text))]) |> response.json(status)
}

fn authenticated(ctx: Context(App)) -> Bool {
  session.get(ctx.session, "studio_admin") == Ok("yes")
}

fn csrf(ctx: Context(App)) -> Bool {
  case
    session.get(ctx.session, "studio_csrf"),
    list.key_find(ctx.req.headers, "x-studio-token")
  {
    Ok(expected), Ok(actual) -> expected != "" && expected == actual
    _, _ -> False
  }
}

fn field(values, key) {
  list.key_find(values, key) |> result.unwrap("") |> string.trim
}

/// @get "/admin"
pub fn index(ctx: Context(App)) -> Response {
  let token = case session.get(ctx.session, "studio_csrf") {
    Ok(token) -> token
    Error(_) -> {
      let token = session.generate_id()
      session.put(ctx.session, "studio_csrf", token)
      token
    }
  }
  admin.render(token: token, logged_in: authenticated(ctx))
  |> response.string_tree(200)
  |> response.header("cache-control", "no-store")
  |> response.header("x-frame-options", "DENY")
}

/// @post "/admin/login"
pub fn login(ctx: Context(App)) -> Response {
  case csrf(ctx) {
    False -> message("Refresh the page and try again.", 403)
    True -> {
      use form <- wisp.require_form(ctx.req)
      let password = config.get_string("admin.password")
      case password != "" && field(form.values, "password") == password {
        True -> {
          session.regenerate(ctx.session)
          session.put(ctx.session, "studio_admin", "yes")
          message("Signed in", 200)
        }
        False -> message("Incorrect password.", 401)
      }
    }
  }
}

/// @post "/admin/logout"
pub fn logout(ctx: Context(App)) -> Response {
  case csrf(ctx) {
    False -> message("Refresh the page and try again.", 403)
    True -> {
      session.invalidate(ctx.session)
      message("Signed out", 200)
    }
  }
}

/// @get "/admin/content"
pub fn content(ctx: Context(App)) -> Response {
  case authenticated(ctx) {
    False -> message("Please sign in.", 401)
    True ->
      store.all(ctx.app.db)
      |> json.array(store.encode)
      |> response.json(200)
      |> response.header("cache-control", "no-store")
  }
}

pub fn valid_id(id: String) -> Bool {
  id != ""
  && string.length(id) <= 120
  && list.all(string.to_graphemes(id), fn(char) {
    string.contains(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-",
      char,
    )
  })
}

fn validate(entry: store.Entry) -> String {
  let checks = [
    #(
      !valid_id(entry.id),
      "Use letters, numbers, underscores or hyphens for the URL slug.",
    ),
    #(
      entry.title == "" || entry.category == "",
      "Title and topic are required.",
    ),
    #(string.length(entry.title) > 240, "Keep the title under 240 characters."),
    #(
      entry.kind != "article" && entry.kind != "video",
      "Choose article or video.",
    ),
    #(
      entry.status != "draft" && entry.status != "published",
      "Choose draft or published.",
    ),
    #(
      entry.kind == "article" && entry.body == "",
      "Write some article content first.",
    ),
    #(
      entry.kind == "video"
        && { string.length(entry.youtube) != 11 || !valid_id(entry.youtube) },
      "Enter a valid 11-character YouTube video ID.",
    ),
    #(
      entry.thumbnail != "" && !string.starts_with(entry.thumbnail, "https://"),
      "Thumbnail URL must begin with https://.",
    ),
  ]
  case list.find(checks, fn(check) { check.0 }) {
    Ok(check) -> check.1
    Error(_) -> ""
  }
}

/// @post "/admin/save"
pub fn save(ctx: Context(App)) -> Response {
  case authenticated(ctx), csrf(ctx) {
    False, _ -> message("Please sign in.", 401)
    _, False -> message("Refresh the page and try again.", 403)
    True, True -> {
      use form <- wisp.require_form(ctx.req)
      let f = fn(key) { field(form.values, key) }
      let entry =
        store.Entry(
          f("id"),
          f("kind"),
          f("title"),
          f("category"),
          f("excerpt"),
          f("body"),
          f("youtube"),
          f("creator"),
          f("thumbnail"),
          f("status"),
          f("date"),
          f("minutes"),
        )
      let original = f("original_id")
      let exists = list.any(store.all(ctx.app.db), fn(e) { e.id == entry.id })
      case validate(entry), original, exists {
        "", "", True ->
          message("This URL slug already exists. Choose another.", 409)
        "", original, _ if original != "" && original != entry.id ->
          message("The URL slug cannot change after creation.", 422)
        "", _, _ -> {
          case store.save(ctx.app.db, entry) {
            Ok(_) -> message("Content saved.", 200)
            Error(_) -> message("Could not save. Please try again.", 500)
          }
        }
        error, _, _ -> message(error, 422)
      }
    }
  }
}

/// @post "/admin/delete/:id"
pub fn delete(ctx: Context(App), id: String) -> Response {
  case authenticated(ctx), csrf(ctx) {
    False, _ -> message("Please sign in.", 401)
    _, False -> message("Refresh the page and try again.", 403)
    True, True -> {
      case store.delete(ctx.app.db, id) {
        Ok(_) -> message("Content deleted.", 200)
        Error(_) -> message("Could not delete. Please try again.", 500)
      }
    }
  }
}
