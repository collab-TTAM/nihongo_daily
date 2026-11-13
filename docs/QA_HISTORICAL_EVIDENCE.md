# Historical CI evidence and gate manifests

The live `qa/matrix.json` is the required-step inventory for the current workflow.
It must not be applied retroactively to captured runs from older source revisions.

The immutable snapshot
`qa/evidence/20261029-native-receipts-9c986e0-attempt2.json` records run
40840683867, attempt 2, on source commit `9c986e0401d37ee13cee139280ecd23b33ce077d`. Its matching gate manifest
is stored beside it as `20261029-native-receipts-9c986e0-attempt2-ci-gates.json`.
That manifest was copied from `qa/matrix.json` at the exact source commit; its
matrix blob is `8874b6bb1ddc331248397f7a3d9704aa8cd6ddb6` and its workflow blob is
`1781354f064cabd4b53fc87aff69013ebc9a4b6b`.

The historical Flutter gate had 29 required steps. The current matrix adds
`Verify browser completed-study transactions in Chrome`. That later step remains
mandatory for current CI, but it cannot be demanded from a run whose source
workflow predates it. Conversely, the old snapshot is never amended with a
synthetic success step.

`qa/test_verify_qa.py` binds the snapshot's run SHA, run ID and attempt to this
historical manifest before validating job IDs, URLs, ordering, status and every
historical critical step. Synthetic evidence tests continue to use the current
matrix. This preserves strict current gates and truthful historical provenance.
