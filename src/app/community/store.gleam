import gleam/dynamic/decode
import gleam/json
import gleam/string
import glimr/db/db.{type DbPool}

pub type User {
  User(id: String, name: String, salt: String, hash: String, kind: String)
}

pub type Comment {
  Comment(
    id: String,
    post: String,
    user: String,
    name: String,
    role: String,
    parent: String,
    root: String,
    body: String,
    date: String,
    deleted: Int,
  )
}

@external(erlang, "community_crypto_ffi", "hash")
pub fn hash(secret: String, salt: String) -> String

@external(erlang, "community_crypto_ffi", "verify")
pub fn verify(secret: String, salt: String, expected: String) -> Bool

@external(erlang, "community_crypto_ffi", "username")
pub fn username() -> String

pub fn setup(pool: DbPool) {
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS community_users (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, password_hash TEXT NOT NULL, credential_kind TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()))",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS community_comments (id TEXT PRIMARY KEY, post_id TEXT NOT NULL, user_id TEXT NOT NULL, name TEXT NOT NULL, role TEXT NOT NULL, parent_id TEXT NOT NULL, root_id TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()), deleted INTEGER NOT NULL DEFAULT 0)",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE INDEX IF NOT EXISTS community_comments_post ON community_comments(post_id, root_id, created_at)",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE INDEX IF NOT EXISTS community_comments_user ON community_comments(user_id, created_at)",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS community_login_attempts (name TEXT PRIMARY KEY, failures INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE UNIQUE INDEX IF NOT EXISTS community_users_name_nocase ON community_users(name COLLATE NOCASE)",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS community_bookmarks (user_id TEXT NOT NULL, post_id TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()), PRIMARY KEY (user_id, post_id))",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE TABLE IF NOT EXISTS community_questions (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL, title TEXT NOT NULL, topic TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()))",
      [],
    )
  let assert Ok(_) =
    db.exec(
      pool,
      "CREATE INDEX IF NOT EXISTS community_questions_user ON community_questions(user_id, created_at)",
      [],
    )
  Nil
}

fn user_decoder() {
  use id <- decode.then(decode.at([0], decode.string))
  use name <- decode.then(decode.at([1], decode.string))
  use salt <- decode.then(decode.at([2], decode.string))
  use hash <- decode.then(decode.at([3], decode.string))
  use kind <- decode.then(decode.at([4], decode.string))
  decode.success(User(id, name, salt, hash, kind))
}

pub fn by_name(pool: DbPool, name: String) {
  db.query_one(
    pool,
    "SELECT id, name, salt, password_hash, credential_kind FROM community_users WHERE name = ? COLLATE NOCASE",
    [db.string(string.lowercase(name))],
    user_decoder(),
  )
}

pub fn by_id(pool: DbPool, id: String) {
  db.query_one(
    pool,
    "SELECT id, name, salt, password_hash, credential_kind FROM community_users WHERE id = ?",
    [db.string(id)],
    user_decoder(),
  )
}

pub fn create(pool: DbPool, user: User) {
  db.exec(
    pool,
    "INSERT INTO community_users (id, name, salt, password_hash, credential_kind) VALUES (?, ?, ?, ?, ?)",
    [
      db.string(user.id),
      db.string(user.name),
      db.string(user.salt),
      db.string(user.hash),
      db.string(user.kind),
    ],
  )
}

pub fn credentials(
  pool: DbPool,
  id: String,
  salt: String,
  hash: String,
  kind: String,
) {
  db.exec(
    pool,
    "UPDATE community_users SET salt = ?, password_hash = ?, credential_kind = ? WHERE id = ?",
    [db.string(salt), db.string(hash), db.string(kind), db.string(id)],
  )
}

pub fn login_blocked(pool: DbPool, name: String) -> Bool {
  let assert Ok(count) =
    db.query_one(
      pool,
      "SELECT COUNT(*) FROM community_login_attempts WHERE name = ? AND failures >= 10 AND updated_at > unixepoch() - 900",
      [db.string(string.lowercase(name))],
      decode.at([0], decode.int),
    )
  count > 0
}

pub fn login_failed(pool: DbPool, name: String) {
  db.exec(
    pool,
    "INSERT INTO community_login_attempts (name, failures, updated_at) VALUES (?, 1, unixepoch()) ON CONFLICT(name) DO UPDATE SET failures = CASE WHEN updated_at < unixepoch() - 900 THEN 1 ELSE failures + 1 END, updated_at = unixepoch()",
    [db.string(string.lowercase(name))],
  )
}

pub fn login_clear(pool: DbPool, name: String) {
  db.exec(pool, "DELETE FROM community_login_attempts WHERE name = ?", [
    db.string(string.lowercase(name)),
  ])
}

fn comment_decoder() {
  use id <- decode.then(decode.at([0], decode.string))
  use post <- decode.then(decode.at([1], decode.string))
  use user <- decode.then(decode.at([2], decode.string))
  use name <- decode.then(decode.at([3], decode.string))
  use role <- decode.then(decode.at([4], decode.string))
  use parent <- decode.then(decode.at([5], decode.string))
  use root <- decode.then(decode.at([6], decode.string))
  use body <- decode.then(decode.at([7], decode.string))
  use date <- decode.then(decode.at([8], decode.string))
  use deleted <- decode.then(decode.at([9], decode.int))
  decode.success(Comment(
    id,
    post,
    user,
    name,
    role,
    parent,
    root,
    body,
    date,
    deleted,
  ))
}

const columns = "id, post_id, user_id, name, role, parent_id, root_id, body, strftime('%Y-%m-%dT%H:%M:%SZ', created_at, 'unixepoch'), deleted"

pub fn comment(pool: DbPool, id: String) {
  db.query_one(
    pool,
    "SELECT " <> columns <> " FROM community_comments WHERE id = ?",
    [db.string(id)],
    comment_decoder(),
  )
}

pub fn comments(pool: DbPool, post: String, page: Int) {
  db.query_all(
    pool,
    "SELECT "
      <> columns
      <> " FROM community_comments WHERE post_id = ? AND root_id IN (SELECT id FROM community_comments WHERE post_id = ? AND parent_id = '' ORDER BY created_at DESC, rowid DESC LIMIT 10 OFFSET ?) ORDER BY created_at ASC, rowid ASC",
    [db.string(post), db.string(post), db.int({ page - 1 } * 10)],
    comment_decoder(),
  )
}

pub fn counts(pool: DbPool, post: String) {
  let assert Ok(roots) =
    db.query_one(
      pool,
      "SELECT COUNT(*) FROM community_comments WHERE post_id = ? AND parent_id = ''",
      [db.string(post)],
      decode.at([0], decode.int),
    )
  let assert Ok(total) =
    db.query_one(
      pool,
      "SELECT COUNT(*) FROM community_comments WHERE post_id = ? AND deleted = 0",
      [db.string(post)],
      decode.at([0], decode.int),
    )
  #(roots, total)
}

pub fn add(pool: DbPool, c: Comment) {
  db.exec(
    pool,
    "INSERT INTO community_comments (id, post_id, user_id, name, role, parent_id, root_id, body) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    [
      db.string(c.id),
      db.string(c.post),
      db.string(c.user),
      db.string(c.name),
      db.string(c.role),
      db.string(c.parent),
      db.string(c.root),
      db.string(c.body),
    ],
  )
}

pub fn too_fast(pool: DbPool, user: String) -> Bool {
  let assert Ok(count) =
    db.query_one(
      pool,
      "SELECT COUNT(*) FROM community_comments WHERE user_id = ? AND created_at > unixepoch() - 60",
      [db.string(user)],
      decode.at([0], decode.int),
    )
  count >= 10
}

pub fn delete(pool: DbPool, id: String) {
  db.exec(
    pool,
    "UPDATE community_comments SET body = '', deleted = 1 WHERE id = ?",
    [db.string(id)],
  )
}

pub fn encode(c: Comment, viewer: String, admin: Bool) {
  json.object([
    #("id", json.string(c.id)),
    #("name", json.string(c.name)),
    #("role", json.string(c.role)),
    #("parent", json.string(c.parent)),
    #("root", json.string(c.root)),
    #("body", json.string(c.body)),
    #("date", json.string(c.date)),
    #("deleted", json.bool(c.deleted == 1)),
    #(
      "can_delete",
      json.bool(
        c.deleted == 0 && { admin || { viewer != "" && viewer == c.user } },
      ),
    ),
  ])
}

pub fn bookmark_ids(pool: DbPool, user: String) -> List(String) {
  let assert Ok(ids) =
    db.query_all(
      pool,
      "SELECT post_id FROM community_bookmarks WHERE user_id = ? ORDER BY created_at DESC, rowid DESC",
      [db.string(user)],
      decode.at([0], decode.string),
    )
  ids
}

pub fn bookmark(pool: DbPool, user: String, post: String, saved: Bool) {
  case saved {
    True ->
      db.exec(
        pool,
        "INSERT INTO community_bookmarks (user_id, post_id) VALUES (?, ?) ON CONFLICT(user_id, post_id) DO NOTHING",
        [db.string(user), db.string(post)],
      )
    False ->
      db.exec(
        pool,
        "DELETE FROM community_bookmarks WHERE user_id = ? AND post_id = ?",
        [db.string(user), db.string(post)],
      )
  }
}

pub type Question {
  Question(
    id: String,
    user: String,
    name: String,
    title: String,
    topic: String,
    body: String,
    date: String,
    replies: Int,
  )
}

fn question_decoder() {
  use id <- decode.then(decode.at([0], decode.string))
  use user <- decode.then(decode.at([1], decode.string))
  use name <- decode.then(decode.at([2], decode.string))
  use title <- decode.then(decode.at([3], decode.string))
  use topic <- decode.then(decode.at([4], decode.string))
  use body <- decode.then(decode.at([5], decode.string))
  use date <- decode.then(decode.at([6], decode.string))
  use replies <- decode.then(decode.at([7], decode.int))
  decode.success(Question(id, user, name, title, topic, body, date, replies))
}

const question_columns = "q.id, q.user_id, q.name, q.title, q.topic, q.body, strftime('%Y-%m-%dT%H:%M:%SZ', q.created_at, 'unixepoch'), (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = 'question:' || q.id AND c.deleted = 0)"

pub fn questions(pool: DbPool) {
  let assert Ok(items) =
    db.query_all(
      pool,
      "SELECT "
        <> question_columns
        <> " FROM community_questions q ORDER BY q.created_at DESC, q.rowid DESC",
      [],
      question_decoder(),
    )
  items
}

pub fn question(pool: DbPool, id: String) {
  db.query_one(
    pool,
    "SELECT "
      <> question_columns
      <> " FROM community_questions q WHERE q.id = ?",
    [db.string(id)],
    question_decoder(),
  )
}

pub fn add_question(pool: DbPool, q: Question) {
  db.exec(
    pool,
    "INSERT INTO community_questions (id,user_id,name,title,topic,body) VALUES (?,?,?,?,?,?)",
    [
      db.string(q.id),
      db.string(q.user),
      db.string(q.name),
      db.string(q.title),
      db.string(q.topic),
      db.string(q.body),
    ],
  )
}

pub fn questions_too_fast(pool: DbPool, user: String) {
  let assert Ok(count) =
    db.query_one(
      pool,
      "SELECT COUNT(*) FROM community_questions WHERE user_id = ? AND created_at > unixepoch() - 60",
      [db.string(user)],
      decode.at([0], decode.int),
    )
  count >= 3
}
