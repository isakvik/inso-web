# inso web

repository for [inso.minusgn.no](https://inso.minusgn.no).

## docs workflow

documentation articles live in `content/docs/` as markdown files. each file starts with front matter:

```yaml
---
title: getting started
description: installing inso and how to start mapping
order: 10
---
```

article links should point to another source article with a relative `.md` path. the generator converts those links to generated documentation urls and fails the build when the article is missing.

the site build compiles the odin generator automatically when needed:

```sh
./run.sh
```

the site is served at `http://127.0.0.1:8000/`. pass a port as the first argument, or set `PORT`, when needed:

```sh
./run.sh 8080
PORT=8080 ./run.sh
```

the github pages workflow installs odin, builds the generator binary, and then runs the same site build.

The generated Lua API reference follows the current `main` branch of the game repository. Download links still resolve the latest published release.
