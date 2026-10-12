import app/app.{type App}
import app/community/store as community
import app/content/store
import compiled/loom/question
import compiled/loom/questions
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import glimr/http/context.{type Context}
import glimr/http/response.{type Response}
import glimr/session
import wisp

fn message(text: String, status: Int) -> Response {
  json.object([#("message", json.string(text))]) |> response.json(status)
}

fn field(values, key) {
  list.key_find(values, key) |> result.unwrap("") |> string.trim
}

fn secret_field(values, key) {
  list.key_find(values, key) |> result.unwrap("")
}

fn csrf(ctx: Context(App)) -> Bool {
  case
    session.get(ctx.session, "community_csrf"),
    list.key_find(ctx.req.headers, "x-community-token")
  {
    Ok(expected), Ok(actual) -> expected != "" && expected == actual
    _, _ -> False
  }
}

fn admin(ctx: Context(App)) -> Bool {
  session.get(ctx.session, "studio_admin") == Ok("yes")
}

fn user(ctx: Context(App)) {
  community.by_id(
    ctx.app.db,
    session.get(ctx.session, "community_user") |> result.unwrap(""),
  )
}

fn current_id(ctx: Context(App)) -> String {
  case user(ctx) {
    Ok(user) -> user.id
    Error(_) -> ""
  }
}

fn valid_secret(secret: String, kind: String) -> Bool {
  case kind {
    "pin" ->
      string.length(secret) >= 6
      && string.length(secret) <= 12
      && list.all(string.to_graphemes(secret), fn(char) {
        string.contains("0123456789", char)
      })
    _ -> False
  }
}

fn pin_kind(kind: String) -> String {
  case kind {
    "" -> "pin"
    _ -> kind
  }
}

fn published(ctx: Context(App), slug: String) {
  list.find(store.published(ctx.app.db), fn(post) { post.id == slug })
}

fn fresh_name(ctx: Context(App), attempts: Int) -> String {
  let name = community.username()
  case community.by_name(ctx.app.db, name) {
    Ok(_) if attempts > 0 -> fresh_name(ctx, attempts - 1)
    _ -> name
  }
}

/// @get "/community/session"
pub fn state(ctx: Context(App)) -> Response {
  let token = case session.get(ctx.session, "community_csrf") {
    Ok(token) -> token
    Error(_) -> {
      let token = session.generate_id()
      session.put(ctx.session, "community_csrf", token)
      token
    }
  }
  let suggestion = case session.get(ctx.session, "community_name") {
    Ok(name) if name != "" -> {
      case string.contains(name, "-") {
        False -> name
        True -> {
          let name = fresh_name(ctx, 64)
          session.put(ctx.session, "community_name", name)
          name
        }
      }
    }
    _ -> {
      let name = fresh_name(ctx, 64)
      session.put(ctx.session, "community_name", name)
      name
    }
  }
  let account = case user(ctx) {
    Ok(user) ->
      json.object([
        #("name", json.string(user.name)),
        #("kind", json.string(user.kind)),
      ])
    Error(_) -> json.null()
  }
  json.object([
    #("token", json.string(token)),
    #("suggestion", json.string(suggestion)),
    #("user", account),
    #("admin", json.bool(admin(ctx))),
  ])
  |> response.json(200)
  |> response.header("cache-control", "no-store")
}

/// @post "/community/name"
pub fn rename(ctx: Context(App)) -> Response {
  case csrf(ctx) {
    False -> message("Refresh the page and try again.", 403)
    True -> {
      session.put(ctx.session, "community_name", fresh_name(ctx, 64))
      state(ctx)
    }
  }
}

/// @post "/community/signup"
pub fn signup(ctx: Context(App)) -> Response {
  case csrf(ctx), user(ctx) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Ok(_) ->
      message("You already have an account. Sign out to create another.", 409)
    True, Error(_) -> {
      use form <- wisp.require_form(ctx.req)
      let secret = secret_field(form.values, "secret")
      let kind = field(form.values, "kind") |> pin_kind()
      let name = session.get(ctx.session, "community_name") |> result.unwrap("")
      case valid_secret(secret, kind), name != "" {
        False, _ -> message("Use a PIN with 6–12 digits.", 422)
        _, False -> message("Refresh to generate your username.", 422)
        True, True -> {
          let salt = session.generate_id()
          let account =
            community.User(
              session.generate_id(),
              name,
              salt,
              community.hash(secret, salt),
              kind,
            )
          case community.create(ctx.app.db, account) {
            Ok(_) -> {
              session.regenerate(ctx.session)
              session.put(ctx.session, "community_user", account.id)
              session.put(ctx.session, "community_name", "")
              state(ctx)
            }
            Error(_) ->
              message(
                "That name was just taken. Generate another and try again.",
                409,
              )
          }
        }
      }
    }
  }
}

/// @post "/community/login"
pub fn login(ctx: Context(App)) -> Response {
  case csrf(ctx) {
    False -> message("Refresh the page and try again.", 403)
    True -> {
      use form <- wisp.require_form(ctx.req)
      let name = field(form.values, "name") |> string.lowercase
      let secret = secret_field(form.values, "secret")
      case string.length(name) <= 80 && valid_secret(secret, "pin") {
        False -> message("Incorrect username or PIN.", 401)
        True -> {
          case community.login_blocked(ctx.app.db, name) {
            True -> message("Too many attempts. Try again in 15 minutes.", 429)
            False -> {
              let account = community.by_name(ctx.app.db, name)
              let correct = case account {
                Ok(account) ->
                  account.kind == "pin"
                  && community.verify(secret, account.salt, account.hash)
                Error(_) -> {
                  // Equal password work for an unknown username.
                  let _ = community.hash(secret, "unknown-account")
                  False
                }
              }
              case account, correct {
                Ok(account), True -> {
                  let _ = community.login_clear(ctx.app.db, name)
                  session.regenerate(ctx.session)
                  session.put(ctx.session, "community_user", account.id)
                  state(ctx)
                }
                _, _ -> {
                  let _ = community.login_failed(ctx.app.db, name)
                  message("Incorrect username or PIN.", 401)
                }
              }
            }
          }
        }
      }
    }
  }
}

/// @post "/community/logout"
pub fn logout(ctx: Context(App)) -> Response {
  case csrf(ctx) {
    False -> message("Refresh the page and try again.", 403)
    True -> {
      session.put(ctx.session, "community_user", "")
      session.regenerate(ctx.session)
      state(ctx)
    }
  }
}

/// @post "/community/credentials"
pub fn credentials(ctx: Context(App)) -> Response {
  case csrf(ctx), user(ctx) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Error(_) -> message("Sign in first.", 401)
    True, Ok(account) -> {
      use form <- wisp.require_form(ctx.req)
      let old = secret_field(form.values, "current_secret")
      let secret = secret_field(form.values, "secret")
      let kind = field(form.values, "kind") |> pin_kind()
      case valid_secret(old, "pin") && valid_secret(secret, kind) {
        False -> message("Use a PIN with 6–12 digits.", 422)
        True -> {
          case community.login_blocked(ctx.app.db, account.name) {
            True -> message("Too many attempts. Try again in 15 minutes.", 429)
            False -> {
              case community.verify(old, account.salt, account.hash) {
                False -> {
                  let _ = community.login_failed(ctx.app.db, account.name)
                  message("Your current PIN is incorrect.", 401)
                }
                True -> {
                  let salt = session.generate_id()
                  case
                    community.credentials(
                      ctx.app.db,
                      account.id,
                      salt,
                      community.hash(secret, salt),
                      kind,
                    )
                  {
                    Ok(_) -> {
                      let _ = community.login_clear(ctx.app.db, account.name)
                      session.regenerate(ctx.session)
                      message("PIN updated.", 200)
                    }
                    Error(_) -> message("Could not update. Try again.", 500)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

/// @get "/community/posts/:slug/comments/:page"
pub fn comments(ctx: Context(App), slug: String, page: String) -> Response {
  case published(ctx, slug), int.parse(page) {
    Error(_), _ -> message("Post not found.", 404)
    _, Error(_) -> message("Invalid page.", 422)
    Ok(_), Ok(page) if page >= 1 && page <= 100_000 -> {
      let assert Ok(comments) = community.comments(ctx.app.db, slug, page)
      let counts = community.counts(ctx.app.db, slug)
      json.object([
        #(
          "comments",
          json.array(comments, fn(c) {
            community.encode(c, current_id(ctx), admin(ctx))
          }),
        ),
        #("roots", json.int(counts.0)),
        #("total", json.int(counts.1)),
      ])
      |> response.json(200)
      |> response.header("cache-control", "no-store")
    }
    _, _ -> message("Invalid page.", 422)
  }
}

/// @post "/community/posts/:slug/comments"
pub fn add(ctx: Context(App), slug: String) -> Response {
  case csrf(ctx), published(ctx, slug) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Error(_) -> message("Post not found.", 404)
    True, Ok(post) -> {
      let identity = case admin(ctx), user(ctx) {
        True, _ -> Ok(#("studio-author", post.creator, "author"))
        False, Ok(account) -> Ok(#(account.id, account.name, "member"))
        _, _ -> Error(Nil)
      }
      case identity {
        Error(_) -> message("Create an account or sign in to comment.", 401)
        Ok(identity) -> {
          use form <- wisp.require_form(ctx.req)
          let body = field(form.values, "body")
          let parent = field(form.values, "parent")
          let id = session.generate_id()
          let root = case parent {
            "" -> Ok(id)
            _ -> {
              case community.comment(ctx.app.db, parent) {
                Ok(parent) if parent.post == slug -> Ok(parent.root)
                _ -> Error(Nil)
              }
            }
          }
          case
            string.length(body) >= 1 && string.length(body) <= 2000,
            root,
            community.too_fast(ctx.app.db, identity.0)
          {
            False, _, _ ->
              message("Write a comment between 1 and 2,000 characters.", 422)
            _, Error(_), _ ->
              message("Reply target not found on this post.", 422)
            _, _, True ->
              message("Please wait a minute before posting again.", 429)
            True, Ok(root), False -> {
              let comment =
                community.Comment(
                  id,
                  slug,
                  identity.0,
                  identity.1,
                  identity.2,
                  parent,
                  root,
                  body,
                  "",
                  0,
                )
              case community.add(ctx.app.db, comment) {
                Ok(_) -> message("Comment posted.", 201)
                Error(_) -> message("Could not post. Try again.", 500)
              }
            }
          }
        }
      }
    }
  }
}

/// @post "/community/comments/:id/delete"
pub fn delete(ctx: Context(App), id: String) -> Response {
  case csrf(ctx), community.comment(ctx.app.db, id) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Error(_) -> message("Comment not found.", 404)
    True, Ok(comment) -> {
      let viewer = current_id(ctx)
      case admin(ctx) || { viewer != "" && viewer == comment.user } {
        False -> message("You cannot delete this comment.", 403)
        True -> {
          case community.delete(ctx.app.db, id) {
            Ok(_) -> message("Comment removed. Replies are preserved.", 200)
            Error(_) -> message("Could not delete. Try again.", 500)
          }
        }
      }
    }
  }
}

/// @get "/community/bookmarks"
pub fn bookmarks(ctx: Context(App)) -> Response {
  case user(ctx) {
    Error(_) -> message("Sign in to see your saved posts.", 401)
    Ok(account) -> {
      let entries = store.published(ctx.app.db)
      let saved =
        community.bookmark_ids(ctx.app.db, account.id)
        |> list.filter_map(fn(id) {
          list.find(entries, fn(post) { post.id == id })
        })
      json.array(saved, store.encode)
      |> response.json(200)
      |> response.header("cache-control", "no-store")
    }
  }
}

/// @post "/community/bookmarks/:slug"
pub fn bookmark(ctx: Context(App), slug: String) -> Response {
  case csrf(ctx), user(ctx) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Error(_) -> message("Create an account or sign in to save posts.", 401)
    True, Ok(account) -> {
      use form <- wisp.require_form(ctx.req)
      let saved = field(form.values, "saved")
      case saved {
        "yes" | "no" -> {
          case saved == "yes", published(ctx, slug) {
            True, Error(_) -> message("Post not found.", 404)
            _, _ -> {
              case
                community.bookmark(ctx.app.db, account.id, slug, saved == "yes")
              {
                Ok(_) -> bookmarks(ctx)
                Error(_) ->
                  message("Could not update your saved posts. Try again.", 500)
              }
            }
          }
        }
        _ -> message("Choose whether to save or remove this post.", 422)
      }
    }
  }
}

/// @get "/community"
pub fn feed(ctx: Context(App)) -> Response {
  questions.render(items: community.questions(ctx.app.db))
  |> response.string_tree(200)
  |> response.header("cache-control", "no-store")
}

/// @get "/community/thread/:id"
pub fn thread(ctx: Context(App), id: String) -> Response {
  case community.question(ctx.app.db, id) {
    Ok(item) ->
      question.render(item: item)
      |> response.string_tree(200)
      |> response.header("cache-control", "no-store")
    Error(_) -> response.not_found()
  }
}

/// @post "/community/questions"
pub fn create_question(ctx: Context(App)) -> Response {
  case csrf(ctx), user(ctx) {
    False, _ -> message("Refresh the page and try again.", 403)
    _, Error(_) -> message("Sign in to ask a question.", 401)
    True, Ok(account) -> {
      use form <- wisp.require_form(ctx.req)
      let title = field(form.values, "title")
      let body = field(form.values, "body")
      let topic = field(form.values, "topic")
      case
        string.length(title) >= 3
        && string.length(title) <= 180
        && string.length(body) >= 10
        && string.length(body) <= 10_000
        && string.length(topic) >= 1
        && string.length(topic) <= 60,
        community.questions_too_fast(ctx.app.db, account.id)
      {
        False, _ ->
          message(
            "Use a title of 3–180 characters, a topic of 1–60 characters and details of 10–10,000 characters.",
            422,
          )
        _, True ->
          message("Please wait a minute before asking another question.", 429)
        True, False -> {
          let id = session.generate_id()
          let item =
            community.Question(
              id,
              account.id,
              account.name,
              title,
              topic,
              body,
              "",
              0,
            )
          case community.add_question(ctx.app.db, item) {
            Ok(_) ->
              json.object([#("url", json.string("/community/thread/" <> id))])
              |> response.json(201)
            Error(_) -> message("Could not post. Try again.", 500)
          }
        }
      }
    }
  }
}

/// @get "/community/questions/:id/comments/:page"
pub fn question_comments(
  ctx: Context(App),
  id: String,
  page: String,
) -> Response {
  case community.question(ctx.app.db, id), int.parse(page) {
    Error(_), _ -> message("Question not found.", 404)
    Ok(_), Ok(page) if page >= 1 && page <= 100_000 -> {
      let key = "question:" <> id
      let assert Ok(items) = community.comments(ctx.app.db, key, page)
      let counts = community.counts(ctx.app.db, key)
      json.object([
        #(
          "comments",
          json.array(items, fn(c) {
            community.encode(c, current_id(ctx), admin(ctx))
          }),
        ),
        #("roots", json.int(counts.0)),
        #("total", json.int(counts.1)),
      ])
      |> response.json(200)
      |> response.header("cache-control", "no-store")
    }
    _, _ -> message("Invalid page.", 422)
  }
}

/// @post "/community/questions/:id/comments"
pub fn answer(ctx: Context(App), id: String) -> Response {
  case csrf(ctx), user(ctx), community.question(ctx.app.db, id) {
    False, _, _ -> message("Refresh the page and try again.", 403)
    _, _, Error(_) -> message("Question not found.", 404)
    _, Error(_), _ -> message("Sign in to reply.", 401)
    True, Ok(account), Ok(question) -> {
      use form <- wisp.require_form(ctx.req)
      let body = field(form.values, "body")
      let parent = field(form.values, "parent")
      let key = "question:" <> id
      let cid = session.generate_id()
      let root = case parent {
        "" -> Ok(cid)
        _ ->
          case community.comment(ctx.app.db, parent) {
            Ok(c) if c.post == key -> Ok(c.root)
            _ -> Error(Nil)
          }
      }
      case
        string.length(body) >= 1 && string.length(body) <= 2000,
        root,
        community.too_fast(ctx.app.db, account.id)
      {
        False, _, _ ->
          message("Write a reply between 1 and 2,000 characters.", 422)
        _, Error(_), _ ->
          message("Reply target not found on this question.", 422)
        _, _, True -> message("Please wait a minute before posting again.", 429)
        True, Ok(root), False -> {
          let role = case account.id == question.user {
            True -> "author"
            False -> "member"
          }
          case
            community.add(
              ctx.app.db,
              community.Comment(
                cid,
                key,
                account.id,
                account.name,
                role,
                parent,
                root,
                body,
                "",
                0,
              ),
            )
          {
            Ok(_) -> message("Reply posted.", 201)
            Error(_) -> message("Could not post. Try again.", 500)
          }
        }
      }
    }
  }
}
