import app/app.{type App}
import gleam/dynamic/decode
import gleam/json
import glimr/db/db
import glimr/http/context.{type Context}
import glimr/http/response.{type Response}

/// @get "/healthz"
pub fn show(ctx: Context(App)) -> Response {
  case db.query_one(ctx.app.db, "SELECT 1", [], decode.at([0], decode.int)) {
    Ok(_) -> json.object([#("status", json.string("ok"))]) |> response.json(200)
    Error(_) ->
      json.object([#("status", json.string("unavailable"))])
      |> response.json(503)
  }
  |> response.header("cache-control", "no-store")
}
