# AniKage 0.3.3: external captions

Owner-authorized module-only repair for One Piece episode 1 Sub. No app code,
resolver, source/audio selection, host permissions, signing policy or other
connector changes.

## Exact artifacts

- Baseline 0.3.2 SHA-256: `630503794e6b48c85991483c4cdecfcddf44f6f4c28cd49e9c743a836dcfc994`.
- Candidate 0.3.3 SHA-256: `70e5a37f0ea1a97c637f65be7b751be892b64b1bdbf520da70114fa5926fd657`.
- Release engine used: `4ac3f4450c39144fe4228ee06592ea41bb89160c`.

The provider already supplies document-level `subtitles[*]` entries. The old
manifest ignored them. The new mapping reads `file`, resolves it through the same
existing provider base used for video, and retains `label` and optional language
metadata. No language is invented. Native subtitle parsing detects VTT/SRT; no
executable code or external service has been added.

## Focused evidence

Standalone native harness: `tests/anikage/SubtitleCheck.swift`. Link it against
the reference app's built VireoCore/SwiftSoup modules and pass two arguments:
the baseline manifest and candidate manifest. `--fixtures-only` disables live
network probes. The harness never prints stream routes, cue text or headers.

- 14 fixture assertions passed across Sub and Dub: video URL/header preservation,
  caption extraction, English/French label preservation, relative URL resolution,
  native VTT parsing and no-caption video continuity. Missing-file rows are ignored.
- One Piece episode 1: Sub and Dub each returned one English track with 285 cues
  parsed by Aroki's actual native parser; HLS playlist probes passed.
- Sword Art Online episode 1: Sub and Dub each returned one English track with
  367 native-parsed cues; HLS playlist probes passed.
- Static compatibility check: the 1.2-era reference tag
  `aroki-v1.2.0-no-accounts-final` already supports these exact subtitle fields.
  This is not an old-device runtime test.

## Evidence boundaries

The final frozen 50-title rerun (seed 20260817; corpus SHA-256
`d9c309abfcd4712aaf878de86027711a421caa9aaeacf0559dc47c3a278c6ed5`) completed
with 36 passes, 1 failure and 13 blocked checks. Native core regression tests
passed. Twelve blocks were HTTP 429 and one was unconfirmed Ghost in the Shell
identity. The failure was the existing Slime Season 2 no-stream case. Verdict:
PARTIAL, not whole-source certification. Four bounded workers were used; future
wide AniKage runs should use a single worker and cooldown to reduce rate limiting.

Earlier 0.3.2 evidence had 45 passes, 3 failures and 2 identity blocks on the same
corpus. The current rate-limited run does not establish a reliability improvement
or regression. Video extraction was byte-for-byte unchanged as structured data;
the requested caption fix is independently proven by the exact-episode tests.

English is the provider's label. Spoken language, Dub timing alignment, visible
iPhone rendering, long playback, downloads, PiP and AirPlay are not certified by
these checks. The ON control still represents the user's caption preference;
this module-only change does not alter that UI.

The initial isolated draft put the mapping at the wrong schema level. Native
validation rejected it before publication. It was corrected to
`operations.streams.extract.subtitles` before all focused checks above and the
final 50-title rerun. The invalid draft was never published.

## Publication and recovery

Use the existing protected Publish Aroki connector workflow with connector_id
anikage and the full candidate commit SHA. The workflow runs native tests,
signs both immutable manifest and index, and verifies the complete repository.
Do not hand-edit signatures or replace an old content-addressed artifact.

Any rollback must be a higher-version release restoring previous resolver data,
with a newly signed index timestamp. Never push an older signed index.
