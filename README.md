# Duck Days — website

The support site and privacy policy for **Duck Days**, an iPhone countdown app
fronted by a pixel-art rubber duck floating on a pond.

- **Get the app** — [App Store](https://apps.apple.com/us/app/duckdays/id6808773849)
- **Support and FAQ** — https://rohanreddybandi.github.io/DuckDays/
- **Privacy policy** — https://rohanreddybandi.github.io/DuckDays/privacy.html

## Found a bug, or want something changed?

**[Open an issue](https://github.com/RohanReddyBandi/DuckDays/issues)** on this repo.
It is the bug tracker for the app as well as for the website, so you do not need to
know anything about either to file one — what you expected and what happened is
plenty. If you would rather not do it in public, email rohanrbspam@gmail.com.

## What is in here

| | |
| --- | --- |
| `index.html` | support page and FAQ |
| `privacy.html` | privacy policy — the short version is that the app collects nothing |
| `c/` | the page a shared countdown link opens, for people who do not have the app |
| `ducks/` | every duck as an SVG, plus the palette and sprite data `c/` draws from |

The duck art is generated rather than drawn, and the SVGs and `ducks/styles.json`
are emitted from the same table the app itself compiles against — so the duck on
the website cannot drift from the duck on your home screen.

This repository is a publish target rather than a place to edit: its contents are
pushed here from the app's own repository, and anything committed here directly is
overwritten by the next publish.
