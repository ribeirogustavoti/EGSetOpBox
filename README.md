# EGSetOpBox

A personal TV set-top box: a Rust application with a 10-foot interface (Slint + libmpv) on a Raspberry Pi 4B, running a custom Fedora image built with KIWI NG and connected to a Sony Bravia 4K TV.

It plays live channels delivered as add-ons, browses movie and series catalogs, streams torrents, fetches subtitles from OpenSubtitles, and is controlled by the TV remote (HDMI-CEC), keyboard, mouse and a phone web remote.

## Status

Under development — milestone M0 (Foundations & spikes).

## Project documents

- [`EGSetOpBox-Chat-Master.md`](EGSetOpBox-Chat-Master.md) — decisions, architecture and backlog.
- [`EGSetOpBox-Issue-Master.md`](EGSetOpBox-Issue-Master.md) — GitHub issue format.
- [`EGSetOpBox-Code-Master.md`](EGSetOpBox-Code-Master.md) — implementation rules and quality gate.

## Build

To be written by the workspace scaffold issue (Chat Master §8, M0-02).

## Legal

The torrent engine and the Stremio bridge are content-agnostic. This project ships no content sources; what is played is the user's responsibility. DRM-protected streams are not supported, and DRM is never circumvented.

## Licence

GPL-3.0-only — see [`LICENSE`](LICENSE). A personal, private-use project; it is not distributed as a product.
