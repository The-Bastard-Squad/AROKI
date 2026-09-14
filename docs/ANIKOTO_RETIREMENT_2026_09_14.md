# AniKoto retirement

Owner-authorized retirement of AniKoto only. Synthetiq One and all other sources
remain unchanged.

The optional repository preference naming AniKoto as the default was removed.
Clients already treat a missing preference as no publisher recommendation. The
previous preference remains recoverable in Git; users' selections are preserved.

Publish version 0.3.9 with `status: retired` through the existing protected
publishing workflow. This is a metadata-only retirement of the exact published
0.3.8 resolver; it does not claim a repaired stream path. The native schema already
supports retirement, including older readers. The signed index and manifest must
agree, and the index timestamp must advance.

Evidence: September 13's 50-title assessment found no passing AniKoto routes
(37 failures, 13 unconfirmed title matches). September 14's fresh Sword Art Online
native check again returned no playable stream. Previously inspected provider
responses exposed encrypted payloads instead of the expected sources collection;
no verified declarative repair was established.

Existing installed copies and user data are preserved. The retirement takes effect
for collection installation/update offers after the device refreshes; there is no
remote uninstall or immediate push kill switch. Users may manually remove their
old copy and choose another source.

Historical artifacts remain immutable. Restoring this source later requires a
tested, higher-version active release and a freshly signed forward index; do not
restore an older signed index because clients enforce anti-replay checks.

The publishing fixture alignment admits only the exact reviewed 0.3.9 SHA-256 and
asserts its retired status. Existing extraction assertions stay in place. No app,
engine, account, trust-policy or signing-key change is required.
