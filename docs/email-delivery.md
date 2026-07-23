# Email delivery — production checklist

Everything the Cloud Functions need in order to actually land mail in an
inbox. The code side is done; the items marked **DNS** and **relay** have to be
done in the Resend dashboard and in the capacify.de zone, and nothing in this
repo can verify them.

## Environment variables

Set in `functions/.env` (gitignored) and read in `functions/index.js`.

| Variable | Required | What breaks without it |
| --- | --- | --- |
| `SMTP_URL` | yes | No email sends at all. Every send path logs "no SMTP_URL configured" and returns. |
| `MAIL_FROM` | **yes** | No email sends at all, and the log says why. See below. |
| `APP_URL` | no (defaults `https://capacify.de`) | CTA buttons point at the wrong host. |
| `UNSUB_SECRET` | for bulk mail | The two engagement emails ship *without* `List-Unsubscribe` headers. They still send; each run logs an error. |
| `UNSUB_MAILBOX` | no | Only the HTTPS unsubscribe is advertised, not the `mailto:` fallback. Set it only if someone actually reads that inbox. |
| `UNSUB_URL` | no (defaults `${APP_URL}/e/abmelden`) | Only needed to bypass the Hosting rewrite and point straight at the function. |

### Why `MAIL_FROM` has no default

It used to default to `Capacify <onboarding@resend.dev>` — Resend's shared
sandbox sender. That address **only delivers to the Resend account owner's own
inbox**. Everything else is accepted by the relay and dropped: no bounce, no
SMTP error, nothing in the function logs. A launch with `SMTP_URL` set and
`MAIL_FROM` forgotten would have looked like it was emailing users and reached
none of them.

There is now no default. `mailReady()` refuses to send when it's missing and
logs an error naming the variable.

## DNS — SPF, DKIM, DMARC

Required on the domain in `MAIL_FROM`. Without them Gmail spam-folders the mail
and several German business mail hosts reject it outright.

1. **relay** — add capacify.de as a domain in Resend and copy the records it
   generates.
2. **DNS** — publish them in the capacify.de zone:
   - **SPF**: one `TXT @` record, e.g. `v=spf1 include:amazonses.com ~all`
     (Resend shows the exact value). Only ever *one* SPF record per domain —
     a second one invalidates both.
   - **DKIM**: the `CNAME`/`TXT` selector records Resend lists.
   - **DMARC**: `TXT _dmarc` → start at `v=DMARC1; p=none; rua=mailto:dmarc@capacify.de`,
     watch the aggregate reports for a couple of weeks, then tighten to
     `p=quarantine` and eventually `p=reject`.
3. **relay** — wait for the domain to show *Verified* before sending anything
   real.
4. Verify end-to-end by sending to a Gmail address and checking
   *Show original*: `SPF: PASS`, `DKIM: PASS`, `DMARC: PASS`.

## One-click unsubscribe (RFC 8058)

Gmail and Yahoo's bulk-sender rules require a working one-click unsubscribe on
marketing/engagement mail. A footer sentence pointing at the Settings screen
does not satisfy it — the requirement is a header the mail client can act on.

Which emails carry it:

- **Engagement (bulk)** — `notifyOnNewCapacity` (match alerts) and
  `weeklyDigest`. Both are gated on `companies/{id}.emailOptIn` and both send
  `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`,
  plus a visible unsubscribe link in the footer.
- **Transactional** — grant notifications, new-message emails, address
  verification, nudges. Deliberately *no* unsubscribe headers: these are direct
  responses to the recipient's own listing or conversation, not a subscription,
  and making them opt-out-able would break the product.

How it works: each link carries the company id and an HMAC-SHA256 signature
over it, keyed with `UNSUB_SECRET`. The `emailUnsubscribe` function verifies
the signature (constant-time) and clears `companies/{id}.emailOptIn`. Company
ids are readable from the public directory, so an unsigned endpoint would let
anyone unsubscribe anyone — hence the signature rather than a bare id.

`firebase.json` rewrites `/e/abmelden` to the function so the link sits on
capacify.de rather than cloudfunctions.net. That rewrite **must stay ahead of
the `**` SPA catch-all** — Hosting takes the first match, and behind it the
mail client's POST would get `index.html` and a 200, silently unsubscribing
nobody.

Rotating `UNSUB_SECRET` invalidates the links in mail that has already been
delivered. Don't, unless it leaks.

### Testing the endpoint

```bash
curl -i -X POST "https://capacify.de/e/abmelden?c=<companyId>&t=<sig>" -d "List-Unsubscribe=One-Click"
```

A valid signature returns 200 and flips `emailOptIn` to `false`; anything else
returns 400 with the same response whether or not the company exists.
