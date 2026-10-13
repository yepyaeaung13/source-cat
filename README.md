# SourceCat

A Gleam web application created from the [official Glimr template](https://github.com/glimr-org/glimr).

## Deploy

For Fly.io, follow [deploy/FLY.md](deploy/FLY.md). The included Dockerfile builds
an Erlang shipment and frontend assets. SQLite and file cache live on a Fly
volume; run one Machine in Singapore. The previous VPS/Caddy instructions
remain available in [deploy/README.md](deploy/README.md).

## Development

```sh
./glimr run
```

Open http://localhost:8000. Glimr starts Vite and enables hot reloading.
The example JSON endpoint is http://localhost:8000/api/welcome.

## Build and test

```sh
./glimr build
npm run build
gleam test
```

## Setup on another machine

Install Gleam, Erlang/OTP, rebar3, Node.js, npm, and a C compiler for SQLite, then:

```sh
gleam deps download
npm ci
cp .env.example .env
```

Set unique `APP_KEY` and `SECRET_KEY_BASE` values in `.env`. The local `.env` already has generated secrets and is ignored by Git.

```sh
./glimr build
./glimr migrate
./glimr run
```

SQLite stores application and session data at `src/database/main/data.db`.
If registry.npmjs.org is unreachable on your network, use an accessible npm registry mirror; keep the package lockfile integrity hashes.

Controllers live in `src/app/http/controllers/`, Loom templates in
`src/resources/views/`, and settings in `config/`.

See [GLIMR_GUIDE.md](GLIMR_GUIDE.md) for the full upstream framework guide.

## Creator Studio

Open http://localhost:8000/admin. Sign in using `ADMIN_PASSWORD` from the local
`.env` file. No default password is shipped. Set your own strong password when
setting up another environment.

Studio lets you create, edit, draft, publish, and delete articles or YouTube
videos. Add a title, introduction, topic, author/channel, optional HTTPS thumbnail,
and URL slug. Articles accept author-written HTML (`<p>`, `<h2>`, `<pre><code>`).
For videos, paste a YouTube URL or the 11-character video ID.

Drafts remain private. Published articles and videos appear together in the
public thumbnail feed. Topics are generated from published content automatically.
Existing URL slugs are fixed so shared links remain stable. Deleting a post
requires confirmation in Studio.

Content is persisted in `src/database/main/data.db`. Back up this SQLite database
before deployment or moving the project. `src/app/content/blog.gleam` is now only
the initial seed; edit content through Studio after installation. Deleted starter
content is not automatically recreated.

Admin authentication uses signed, server-side sessions. Save/delete/logout
requests require a session CSRF token. Keep `.env` outside version control and use
HTTPS for a public deployment. Admin article HTML is trusted editor content, not
an untrusted public submission format.

## Integration verification

With `./glimr run` running:

```sh
python3 scripts/check_admin.py
```

This checks authentication, CSRF, validation, draft privacy, publishing, editing,
video rendering, deletion, and logout. It creates and removes its own temporary
content. The generated password is read locally and never printed by this check.

## VPS deployment

See [deploy/README.md](deploy/README.md) for the production release build,
systemd service, Caddy HTTPS setup, persistent SQLite storage and backups.

## Visitor accounts and comments

The public site prompts first-time visitors to create an account. A friendly
username such as `Sunny Mango` is generated automatically; visitors choose
a 6–12 digit PIN and confirm it before the account
is created. Browsing remains available without an account. The account button
opens sign-in and account settings, including changing the PIN with the
current credential. Save your generated username and credential; there is no
email-based account recovery in this version.

Credentials use salted PBKDF2-HMAC-SHA256 (600,000 iterations); only the username
is remembered in browser local storage. Authentication uses the existing signed,
server-side session cookies. Repeated login failures are throttled. Community
mutations require a session CSRF token.

Published articles and videos have paginated comment threads, including replies
to other replies. Studio admins reply using the post's author name with an
Author badge. Members can delete their own comments; Studio admins can moderate
any comment directly on the public post. Removed comments retain a placeholder
so replies remain readable. Comments are plain text; they cannot execute HTML.
Draft posts never expose their comments. Deleting a post removes its comments.

Accounts, bookmarks and comments are stored in the same SQLite database as posts and are
included in the existing database backup. Their tables are created automatically
on startup, including when updating an existing deployment.

Bookmark buttons on feed cards and post pages save articles or videos to the
signed-in account. Open `/bookmarks` or the Saved posts link in the sidebar/account
dialog to browse your reading list with search and topic/type filters. Bookmarks
are private, persist across sign-ins and devices, and are included in SQLite
backups. Draft posts stay out of saved lists; deleting a post also removes its
bookmarks. Saving twice keeps one bookmark. If a guest tries to save, signing in
closes the account dialog and completes that save automatically.

Visitor authentication is PIN-only. Password account creation and credential
changes are rejected by the server. The PIN is masked on screen and stored as a
salted hash. Creator Studio retains its separate admin password.

The Studio description editor supports rich text for articles and YouTube video
descriptions: paragraphs, headings, bold/italic, lists, links, quotes, code blocks,
and undo/redo. The introduction remains a short plain-text summary. Formatting
from pasted content is cleaned before saving.

With `./glimr run` running, check the community flows with:

```sh
python3 scripts/check_community.py
```

The check creates and cleans up its own posts and accounts.
