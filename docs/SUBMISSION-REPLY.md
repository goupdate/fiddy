# Fiddy — the bounty submission reply

**Reply to:** https://farcaster.xyz/balajis.eth/0x50184b62 (hash `0x50184b62b4c52fd76628713562e1eda3dccaf63d`, @balajis.eth, FID 37)
**Posted:** 2026-10-17T14:47:30Z · **Deadline:** 2026-10-24T14:47:30Z (Sat 20:17:30 IST) — 7 days exactly from the post.
**Post from:** the owner's Farcaster account. No Farcaster credentials exist on this machine, so this cannot be scripted here.

## Before posting

1. Replace `<VOUCHER_CAST_URL>` with the voucher's cast URL and `<HANDLE>` with their username.
2. Re-check both URLs answer: `curl -sI https://fiddy.fun/client` and `gh repo view ivcained/fiddy --json visibility,licenseInfo`.
3. Confirm the repo default branch is pushed (`git status -sb` clean, `main == origin/main`) — the judge reads the repo, not the local clone.
4. Post it as a **reply to the cast above**, not as a standalone cast. Keep the three URLs in the reply.

## Reply text (1021 characters)

```
@balajis.eth — $2048 FOR FARCASTER CLIENTS submission.

(1) Microsite with the quickstart + tutorial: https://fiddy.fun/client
(2) Repo, MIT, all code: https://github.com/ivcained/fiddy
(3) Voucher: <VOUCHER_CAST_URL> — @<HANDLE> ran the tutorial end to end on their own compute and posted what happened.

Three commands: fiddy provision → fiddy node up → fiddy client up. No API keys from anyone: the client reads and writes through your own Snapchain read node.

Two lines in the brief are out of date; we checked both against the live network:
- Read nodes do accept writes: POST /v1/submitMessage is served on both roles. A read node has no mempool, so it validates, gossips to validators and keeps nothing — the tutorial teaches that path, confirms inclusion via MERGE_MESSAGE or a query-back, and offers a submit-to-validator toggle.
- App keys are gasless KEY_ADD signed by the custody address since Snapchain V16 — no Optimism transaction.

Where the tutorial disagrees with the older docs, it shows the citation.
```

## Why the last two paragraphs are in there

The brief opens with "a read node syncs the network but **does not accept writes**, so your client should read from
your own node and submit casts to a validator endpoint", and says the app key needs "one small Optimism
transaction". Both were true once. They are not true now:

- `snapchain.farcaster.xyz/node-types` → "Message submission and the mempool": `submitMessage` (gRPC) and
  `POST /v1/submitMessage` (HTTP) **work on both roles**; a read node has no mempool, so it validates the message,
  gossips it on the `mempool` topic and keeps nothing; confirmation is `MERGE_MESSAGE` or a query-back. A
  validator-endpoint submission is still the more reliable path under load, which is why the client keeps that
  toggle.
- Gasless `KEY_ADD` (EIP-712 from the custody address) replaced the onchain key-gateway transaction at Snapchain
  V16.

Stating this in the reply, with the citation, is the difference between a judge reading "the author knew the
protocol" and "the author copied an old blog post". It also pre-empts the one place where our tutorial would
otherwise look like it contradicts the brief.

## Links that back the claims

- https://snapchain.farcaster.xyz/getting-started — requirements: 16 GB RAM, 4 cores, **2 TB free storage**, ports 3381–3383
- https://github.com/farcasterxyz/snapchain (README) — same, **1.5 TB free storage**; snapshots ~200 GB
- https://snapchain.farcaster.xyz/node-types#message-submission-and-the-mempool — the write path and the mempool
- https://snapchain.farcaster.xyz/node-types — block pruning: read nodes only, off by default