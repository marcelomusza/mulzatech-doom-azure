# ADR 0003: Use the original DOOM shareware WAD instead of Freedoom

## Status

Accepted

## Context

DOOM's engine (the code that reads levels, textures, and sounds and turns
them into a playable game) is separate from its data (the WAD file
containing those levels, textures, and sounds). To legally distribute a
playable build of DOOM in a public repo, the WAD bundled with it needs to be
one that's actually redistributable. Two realistic options exist:

- **The original DOOM shareware WAD** (`DOOM1.WAD`, episode 1 only —
  "Knee-Deep in the Dead") — id Software released this WAD in 1993
  specifically for free redistribution, as a marketing sample of the full
  game. It has remained freely distributable ever since, distinct from the
  full retail WAD (`DOOM.WAD`) or DOOM 2's WAD, neither of which are free to
  redistribute.
- **Freedoom** — a long-running open-source project that built an entirely
  new, freely-licensed WAD from scratch (original art, levels, and sounds)
  designed to be compatible with DOOM-engine source ports, without using any
  of id Software's original assets.

## Decision

Use the **original DOOM shareware WAD** (`DOOM1.WAD`), not Freedoom.

## Options considered

| Option | Why not chosen |
|---|---|
| Freedoom | Fully open-licensed and redistribution is not in question, which is attractive. But it replaces all of DOOM's original art, levels, and sound — it is DOOM-engine-compatible, not actually DOOM. It would not be recognizably "playing DOOM" for anyone encountering the project. |
| Original shareware WAD (chosen) | See rationale below. |

## Rationale

- **It's actually DOOM.** The whole premise of the project is "the original
  DOOM (1993), running via a WebAssembly DOS emulator" — a portfolio piece
  meant to be immediately recognizable. Freedoom, while a genuinely
  impressive project, is a different game wearing DOOM-shaped clothes; it
  would undercut the "hey, that's DOOM" moment that makes this a fun
  project to show off.
- **It's legitimately free to redistribute.** id Software explicitly
  released the shareware episode for free distribution as a promotional
  sample back in 1993, and that permission has never been revoked. This is
  a well-established, long-settled point in the DOOM community — the
  shareware WAD is one of the most widely mirrored id Software files in
  existence, precisely because it was designed to be shared.
- **It's small and scoped appropriately.** The shareware WAD contains only
  episode 1 ("Knee-Deep in the Dead"), which is plenty to demonstrate a
  fully playable game without needing to source or license the full retail
  episodes.

## Consequences

- Only episode 1 of DOOM is playable in this project. Episodes 2–4 (part of
  the full retail release) are not included and would require a
  commercially licensed WAD to add — out of scope for this project.
- The WAD file (`DOOM1.WAD`) is committed into the repo's static assets
  (`app/public/`) alongside the DOS executable, since both are freely
  redistributable together as the "shareware release."
- If DOOM 2 or the full DOOM retail episodes are ever desired in a future
  phase, that would require either a legitimately purchased/licensed WAD
  (not committed to a public repo) or switching that specific
  content to Freedoom-compatible data — a separate decision from this one.
