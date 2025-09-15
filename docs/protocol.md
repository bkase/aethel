# Aethel A4 Protocol (Markdown + Git)

**Version:** 1.0.0 • **Status:** Draft (implementable) • **License:** CC-BY-SA or MIT (choose on repo init)

---

## 0) Purpose & Philosophy

A4 defines a **plain-Markdown, Git-native** protocol for a personal knowledge base (“vault”) that is:

- **App-agnostic**: notes are ordinary `.md` files in folders you own.
- **Daily-first**: the **daily note** is the primary capture surface; everything else is stitched from it.
- **Low-friction**: apps **append** to known anchors/sections; no UUIDs or heavy schemas.
- **Extensible**: richer artifacts (media, PDFs, large binaries) live alongside Markdown via a separate repo.
- **Future-proof**: compatible with Obsidian/VS Code/Neovim later, but not required now.

A4 prioritizes **flow over ontology**: you capture first (daily), curate later (collections). Structure emerges from anchors, links, and light conventions rather than enforced types.

---

## 1) Scope & Non-Goals

**In scope**

- Folder layout, naming, anchors, linking, and merge semantics for Markdown notes.
- Minimal optional front matter for **application-generated** documents.
- Git workflows for multi-device sync (desktop, iOS, Android), including selective subsets.
- Separation of large assets into a companion repository or LFS.

**Out of scope**

- Mandatory schemas or global IDs.
- A specific editor/app requirement.
- Server or DB components (A4 is file-based).
- “Perfect” ontology—A4 offers conventions; you evolve the rest.

---

## 2) Repositories

A4 uses two repos:

- **`a4-core`** (REQUIRED): all Markdown notes, templates, and small text artifacts.
  Clone everywhere (desktop, laptop, phone, tablet).

- **`a4-assets`** (OPTIONAL): large/rich artifacts (images, audio, video, PDFs, datasets).
  Clone only on devices with space/bandwidth. May be linked into `a4-core` via submodule, symlink, or Git LFS alternative.

> **Recommended:** Use a **git submodule** mounting `a4-assets` at `a4-core/assets/` on desktop. On devices without `a4-assets`, links simply won’t resolve (acceptable degraded behavior).

---

## 3) Directory Layout (in `a4-core/`)

```text
a4-core/
  README.md
  inbox/                       # quick drops / scratch
    YYYY/
      YYYY-MM/
        YYYY-MM-DD--paste-zone.md
  capture/                     # DAILY LEDGER (system heart)
    YYYY/
      YYYY-MM/
        YYYY-MM-DD.md
  collections/                 # curated, “composed” surfaces
    weekly-plans/
      YYYY/
        YYYY-Www.md
    journals/
      YYYY/
        YYYY-MM.md             # optional month roll-ups
    research-memos/
    essays/
  projects/                    # optional light hubs (per project)
    <slug>/
      index.md
      log.md
      sources/
      artifacts/               # tiny text assets only; big files → a4-assets
  sources/                     # consumption inputs (TEXT-FIRST)
    articles/
    transcripts/
    books/
  routines/                    # templates & recurring structures
    templates/
    checklists/
  .a4/                         # (reserved) CLI metadata, cache, hooks (if used)
```

**Rationale**

- You always know **where to start**: `capture/YYYY-MM-DD.md`.
- Everything else (weekly plan, research memo) is a _derivative composition_ under `collections/`.
- `projects/` and `people/` hubs are optional and light; links + searches do the heavy lifting.

---

## 4) Filenames, Slugs, and Paths

- **Dates**:
  - Day: `YYYY-MM-DD.md` (UTC in filename; local times in content)
  - Week: `YYYY-Www.md` (ISO week, e.g. `2025-W37.md`)

- **Human slugs**: lowercase letters, digits, `-` (dash). Avoid spaces; use `-`.
  Example: `projects/gb-ppu/index.md`, `sources/articles/karpathy-state-of-gpt-2025.md`
- **Portability**: paths must be case-sensitive safe and compatible with iOS/Android/Windows/macOS.

---

## 5) Linking & Anchors

### 5.1 Wikilinks

- Use Obsidian-style **wikilinks** for path-relative internal references:
  `[[projects/gb-ppu/index]]`, `[[capture/2025/2025-09/2025-09-14]]`
- Standard Markdown links are equally valid:
  `[GB-PPU](projects/gb-ppu/index.md)`

### 5.2 Block Anchors

A4 identifies append-only content by **anchors**:

- Anchor syntax: a caret `^` followed by a token:
  `^focus-0930`, `^jrnl-0812`, `^read-1102`, `^eod-2215`
- Token grammar (default):
  - `prefix` = `[a-z][a-z0-9-]{1,24}` (semantic category)
  - `time` = `HHMM` in 24-hour local time

- Anchors precede a **block** (one or more bullet lines/paragraphs until blank line or next heading/anchor).

---

## 6) Front Matter (Optional)

Front matter is **optional**. If absent, the note is simply “human-authored.”
Applications **MAY** add front matter when generating/augmenting notes.

### 6.1 Example Header (for app-generated docs)

```yaml
---
kind: capture.day | plan.weekly | focus.session | source.article | memo.research | hub.project
created: 2025-09-14T07:58:12Z
aliases: []
origin: { url: "", via: "" } # for sources
---
```

**Rules**

- **`kind`** is used **only** by applications to signal a document’s type.
- All other metadata besides `kind` is application-specific
- Front matter **MUST NOT** be required for human notes; apps **MUST NOT** rely on it being present to function.
- Apps **SHOULD** tolerate unknown fields; collisions resolved by “last write wins” at the field level.

---

## 7) Canonical Documents & Sections

### 7.1 Daily Note (required)

`capture/YYYY/YYYY-MM/YYYY-MM-DD.md`

**Recommended initial sections** (any order; apps must be tolerant):

```md
# Intention

^intent-0800

# End of Day

^eod-2215
```

**Behavior**

- Apps **APPEND** under the right heading by creating a new **anchored block**.
- If a heading/anchor is missing, apps **MAY** create it on demand.
- Apps **MUST NOT** rewrite or reorder existing content; they append only.

### 7.2 Weekly Plan (optional curated doc)

`collections/weekly-plans/YYYY/YYYY-Www.md`

Contains narrative plus **references** to captured blocks:

```md
## Reflection on W36

- ![[capture/2025-09-14#^eod-2215]]
- ![[capture/2025-09-13#^eod-2230]]

## Big Rocks

- …

## Anchors & Timeboxes

- Morning: build | Afternoon: explore | Evening: admin
```

> Outside Obsidian, `![[...]]` is a **marker**. A4 tooling can **stitch** these into a rendered Markdown artifact later (see §11).

### 7.3 Sources (articles, transcripts)

- `sources/articles/<slug>.md` : highlights + metadata (URL).
- Reflections primarily live in the **daily note** as anchored blocks; optionally, a sibling `…--bk.md` holds longer commentary.

### 7.4 Project Hub (optional)

- `projects/<slug>/index.md` is a landing page.
- `projects/<slug>/log.md` is **append-only** with dated entries (good for “monoidal” merges).

---

## 8) Git Workflows (Multi-Device)

### 8.1 Desktop/Laptop

- Normal Git usage; optional pre-commit hook to bump `updated:` in app-generated docs.
- `a4 sync` helper (see §11) runs: `git pull --rebase && git add -A && git commit -m "a4: <summary>" && git push`.

### 8.2 iOS (Working Copy + 1Writer)

- **Working Copy**: clone `a4-core`; enable background refresh & automatic pulls.
- **1Writer**: open the repo folder in Files; set actions:
  - “Append to Today” → resolves today’s path → inserts anchored block at cursor → saves.
  - Working Copy is configured to auto-commit/push on save or via a Share Sheet action.

### 8.3 Android / Daylight Tablet (GitJournal)

- **GitJournal**: clone `a4-core`; default new entries to `inbox/…` or append to **today** (preferred).
- **Editor**: GitJournal’s editor or Markor. Configure auto-commit/push on note close or every N minutes.

### 8.4 Subsets / Selective Sync

- Keep `a4-core` everywhere; keep `a4-assets` only on desktop/laptop.
- Advanced: use Git **sparse-checkout** on desktop to trim historical months if needed (mobile typically keeps everything in `a4-core` since text is small).

---

## 9) Rich Assets (`a4-assets`)

Two supported modes:

- **Submodule mount (recommended)**: add `a4-assets` as a **submodule** at `a4-core/assets/` on desktops.
  - Pros: simple Markdown links: `![img](assets/img/2025/…/diagram.png)`
  - Mobile without assets: links are inert; acceptable.

- **Git LFS (single repo)**: store assets in LFS with `.gitattributes`.
  - Pros: one repo; links always resolve.
  - Cons: mobile clients may fetch pointers; configure LFS smudge/filters to avoid large downloads.

> For very large libraries, **git-annex** is supported (desktop-only recommendation).

---

## 10) CLI / Libraries (Normative Behaviors)

The A4 CLI is an **optional** reference implementation. Libraries in any language may implement the same behaviors.

**Commands (spec level):**

- `a4 today`
  - **Resolve** path to today’s daily note; **create** from template if absent.

- `a4 append --heading <heading> --anchor <tok> --file <path> --stdin`
  - **Append** a block under `<anchor>` to `<file>`. **Create** `<heading>` if missing. **Never** reorder/rewrite.

- `a4 sync`
  - Pull-rebase, add all, conventional commit, push.
  - Suggested commit message grammar: `a4: capture|plan|source|log: <short>`.

**Libraries MUST:**

- Treat anchors as write targets and **append** only.
- Be resilient to missing headings/anchors (create as needed).
- Avoid global state (no cross-file IDs required).

---

## 11) Publishing Flow (Private → Public)

A4 assumes **private by default**. Publishing is a **digest/curation** act:

1. Capture raw materials in daily notes and sources.
2. Compose in `collections/` (memos, essays, weekly summaries) via block references.
3. `a4 stitch` to produce a **rendered** standalone Markdown (no transcludes).
4. Optionally post-process (front matter for blog, image path rewrite) and publish.

This preserves privacy of the raw vault while producing minimal, portable artifacts.

---

## 12) Security & Privacy

- Keep both repos private. Treat `a4-core` as **sensitive** (journals, reflections).
- Avoid committing secrets (API keys). If necessary, use `.gitignore` + OS keychain.
- Backups: mirror to a private remote (GitHub/Gitea/Codeberg); optionally encrypted remote (age, git-remote-age).
- Device hygiene: phones/tablets should be protected (PIN/biometric); consider remote-wipe.

---

## 13) Compatibility

- **Obsidian**: A4’s structure, wikilinks, and anchors are compatible. Transcludes `![[…]]` render natively.
- **VS Code / Neovim**: use Markdown LSP (**marksman**), `zk-nvim` or `telekasten.nvim` for daily notes/backlinks, `ripgrep/fzf` for search.
- **Mobile**: iOS (Working Copy + 1Writer), Android (GitJournal + Markor).
- **No dependency** on any single app or plugin.

---

## 14) Examples

### 14.1 Focus session appended to today

```md
^focus-1410

- **Start** 14:10–14:45 — “Design Weekly Plan generator”
- Goal: outline
- Result: rough H2s + prompts
- Energy: 7/10
- Tag: #focus
```

### 14.2 Source note (article)

`sources/articles/karpathy-state-of-gpt-2025.md`

```md
---
kind: source.article
created: 2025-09-14T10:45:00Z
origin: { url: "https://...", via: "Reader" }
tags: [ml]
---

## Highlights

- …

## Notes

- …

## Links

- Referenced in [[capture/2025-09-14#^read-1102]]
```

---

## 15) Versioning & Evolution

- Spec uses **semver**. Non-breaking additions (e.g., new recommended sections) bump **minor**.
- Breaking changes (layout or rules) bump **major**.
- Repos may record the target spec version in `a4-core/.a4/version`.

---

## 16) Conformance Checklist (Apps/CLI)

**MUST**

- Append-only writes under anchors; no reorder/rewrites.
- Tolerate missing headings/anchors (create as needed).
- Never require front matter for human notes.
- Preserve unknown front matter fields.
- Leave non-Markdown assets untouched.

**SHOULD**

- Use anchor grammar `^<prefix>-<HHMM>(__suffix)?`.
- Add device suffix on collision.
- Provide `created/updated` when generating docs.

**MAY**

- Add inline block IDs (hash comments) for dedupe.
- Provide `stitch`, `collate`, and `ingest` utilities.

---

## 17) Appendix: Grammar & Conventions

- **Slug**: `[a-z0-9][a-z0-9-]{1,63}` (no spaces).
- **Anchor prefix** (suggested set): `intent|tasks|focus|jrnl|read|eod`.
- **Time tokens**: local time `HHMM`; if time is unknown, use `0000` and add text timestamp in block.
- **Dates in content**: ISO `YYYY-MM-DD` (local); filenames use UTC date to avoid TZ drift across devices.
- **Line endings**: LF (`\n`).
- **Encoding**: UTF-8.

---

## 18) Quick Start (Human)

1. `git init a4-core && cd a4-core`
2. Create folders as per §3; drop templates into `routines/templates/`.
3. Make today’s note in `capture/…/YYYY-MM-DD.md` from the daily template.
4. On iOS: clone in **Working Copy**, edit with **1Writer**; on Android: use **GitJournal**.
5. Commit/push daily. That’s it—structure grows with use.
