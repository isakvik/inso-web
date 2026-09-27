# inso web

repository for [inso.minusgn.no](https://inso.minusgn.no).

## docs workflow

documentation articles live in `content/docs/` as markdown files. each file starts with front matter:

```yaml
---
title: getting started
description: install inso and author your first map
order: 10
---
```

article links should point to another source article with a relative `.md` path. the generator converts those links to generated documentation urls and fails the build when the article is missing.

the site build compiles the odin generator automatically when needed:

```sh
bash gen_site.sh
python3 -m http.server --directory _site
```

the github pages workflow installs odin, builds the generator binary, and then runs the same site build.

The generated Lua API reference follows the current `main` branch of the game repository. Download links still resolve the latest published release.
