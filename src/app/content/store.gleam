import app/content/blog
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import glimr/db/db.{type DbPool}

pub type Entry {
  Entry(
    id: String,
    kind: String,
    title: String,
    category: String,
    excerpt: String,
    body: String,
    youtube: String,
    creator: String,
    thumbnail: String,
    status: String,
    date: String,
    minutes: String,
  )
}

pub fn decoder() {
  use id <- decode.field("id", decode.string)
  use kind <- decode.field("kind", decode.string)
  use title <- decode.field("title", decode.string)
  use category <- decode.field("category", decode.string)
  use excerpt <- decode.field("excerpt", decode.string)
  use body <- decode.field("body", decode.string)
  use youtube <- decode.field("youtube", decode.string)
  use creator <- decode.field("creator", decode.string)
  use thumbnail <- decode.field("thumbnail", decode.string)
  use status <- decode.field("status", decode.string)
  use date <- decode.field("date", decode.string)
  use minutes <- decode.field("minutes", decode.string)
  decode.success(Entry(
    id,
    kind,
    title,
    category,
    excerpt,
    body,
    youtube,
    creator,
    thumbnail,
    status,
    date,
    minutes,
  ))
}

pub fn encode(e: Entry) -> json.Json {
  json.object([
    #("id", json.string(e.id)),
    #("kind", json.string(e.kind)),
    #("title", json.string(e.title)),
    #("category", json.string(e.category)),
    #("excerpt", json.string(e.excerpt)),
    #("body", json.string(e.body)),
    #("youtube", json.string(e.youtube)),
    #("creator", json.string(e.creator)),
    #("thumbnail", json.string(e.thumbnail)),
    #("status", json.string(e.status)),
    #("date", json.string(e.date)),
    #("minutes", json.string(e.minutes)),
  ])
}

pub fn setup(pool: DbPool) {
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS blog_entries (id TEXT PRIMARY KEY, payload TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()))",
      [],
    )
  let seeds =
    list.map(blog.posts(), fn(p) {
      Entry(
        p.slug,
        "article",
        p.title,
        p.category,
        p.excerpt,
        p.body,
        "",
        "SourceCat",
        "",
        "published",
        p.date,
        p.minutes,
      )
    })
  let videos =
    list.map(blog.videos(), fn(v) {
      Entry(
        v.id,
        "video",
        v.title,
        v.category,
        v.note,
        "",
        v.id,
        v.creator,
        "",
        "published",
        "12 Oct 2026",
        "Video",
      )
    })
  // Seed only the first installation, so deleted starter content stays deleted.
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS blog_meta (key TEXT PRIMARY KEY)",
      [],
    )
  let assert Ok(seeded) =
    db.query_all(
      pool,
      "SELECT key FROM blog_meta WHERE key = 'seeded'",
      [],
      decode.at([0], decode.string),
    )
  case seeded {
    [] -> {
      list.each(list.append(seeds, videos), fn(e) {
        let assert Ok(_) = save(pool, e)
      })
      let assert Ok(_) =
        db.exec(pool, "INSERT INTO blog_meta(key) VALUES ('seeded')", [])
      Nil
    }
    _ -> Nil
  }
}

pub fn all(pool: DbPool) -> List(Entry) {
  let assert Ok(rows) =
    db.query_all(
      pool,
      "SELECT payload FROM blog_entries ORDER BY created_at DESC, rowid DESC",
      [],
      decode.at([0], decode.string),
    )
  list.filter_map(rows, fn(row) {
    json.parse(row, decoder()) |> result.map_error(fn(_) { Nil })
  })
}

pub fn published(pool: DbPool) -> List(Entry) {
  all(pool) |> list.filter(fn(e) { e.status == "published" })
}

pub fn save(pool: DbPool, entry: Entry) {
  db.exec(
    pool,
    "INSERT INTO blog_entries (id, payload) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
    [db.string(entry.id), db.string(json.to_string(encode(entry)))],
  )
}

pub fn delete(pool: DbPool, id: String) {
  use conn <- db.transaction(pool, 2)
  use _ <- result.try(
    db.exec_with(conn, "DELETE FROM community_comments WHERE post_id = ?", [
      db.string(id),
    ]),
  )
  use _ <- result.try(
    db.exec_with(conn, "DELETE FROM community_bookmarks WHERE post_id = ?", [
      db.string(id),
    ]),
  )
  db.exec_with(conn, "DELETE FROM blog_entries WHERE id = ?", [db.string(id)])
}
