# Bakaláři (Diana, ZŠ Libčany)

Diana's school runs Bakaláři at `https://zslibcany.bakalari.cz` (class 2.A).
Izabela's kindergarten has no Bakaláři.

`scripts/bakalari.mjs` reads it through the API the Bakaláři OnLine mobile
app uses. The API is unofficial and documented by the community at
https://github.com/bakalari-api/bakalari-api-v3, so it can change without
notice. The only write is `excuse --submit` (omluvenka, see below).

## Credentials

The parent login lives in the macOS Keychain, not in `.zsh_secrets`. It is
one generic-password item whose account is the login name and whose password
is the password. The item's service name is `school.keychain_service` in
`config.json`:

```zsh
security add-generic-password -U -s kids-diana-bakalari -a LOGIN -w   # prompts for the password
```

`keychainSecret()` in `kids.mjs` reads the item through `security`. Each run
logs in with the password (`POST /api/login`, `client_id=ANDR`) and keeps the
token in memory only. Refresh tokens rotate and can't be reused, so storing
them only causes trouble.

## Commands

```bash
node bakalari.mjs user        didi                 # class, enabled modules (login check)
node bakalari.mjs timetable   didi [DATE]          # week with DATE; changes (suplování, absence třídy)
node bakalari.mjs homework    didi [FROM] [TO]     # by due date, default today .. +7
node bakalari.mjs messages    didi [--all] [--days N]   # Komens received: unread + last 14 days
node bakalari.mjs noticeboard didi
node bakalari.mjs events      didi [FROM]          # school events for her
node bakalari.mjs marks       didi [--days N]      # recent marks + averages
```

`--json` prints the raw API response. None of these need confirmation.
Summarize the answer in Czech and don't paste raw output. Message bodies can
be long, so quote only what answers the question.

## Omluvenka (absence excuse)

```bash
node bakalari.mjs excuse didi FROM REASON... [--to DATE] [--time HH:MM-HH:MM] [--json] [--submit]
```

It sends a Komens message of type `OMLUVENKA` to the class teacher, the
default and only recipient offered, currently Mgr. Michaela Mačurová. The
excuse covers whole days from `FROM` to `--to`, or with `--time` a time range
on a single day (e.g. a doctor's visit, `--time 8-10:30`). `REASON` becomes the
message text, so write it the way a parent would: "nemocná, zůstává doma",
"návštěva lékaře".

Workflow (preview, confirm, submit, check):

1. Ask for the reason if the user didn't give one. Don't make it up.
2. Run without `--submit`. It prints the recipient, the day(s) with weekday,
   the text, and a warning if an omluvenka for an overlapping date was already
   sent. Show that to the user and ask for confirmation.
3. After an explicit yes, run the same command with `--submit`. It sends,
   then re-reads the sent messages and reports whether the new omluvenka is there.
4. If the user is also cancelling lunch or judo for the same days, do one
   preview covering everything and ask for one confirmation.

**Not yet confirmed against a real send.** The payload follows the community
docs: `POST /api/3/komens/message` with `MessageType=OMLUVENKA`,
`RecipientType=U`, `DateFrom` 00:00:00 and `DateTo` 23:59:59 in Prague time
for whole days. It also follows the web form's options (celý den / vyučovací
hodina / konkrétní čas). Hour-based excuses (`vyučovací hodina`) are not
supported. For the first real send, tell the user it's the first one, and
afterwards have them look at it in the web app under Komens → Odeslané zprávy
(`/next/komens.aspx?l=o`). Check that the dates show correctly. Then remove
this paragraph. If the send fails or the message looks wrong, don't retry
blindly. Send it by hand in the web app (`/next/komens_zprava.aspx?l=abs`) and
fix the payload with `--json`.

## Gotcha: Accept-Language

Node's `fetch` sends `Accept-Language: *` by default, and the Bakaláři API
answers that with HTTP 500 on every endpoint before it even checks the token.
The script always sends `Accept-Language: cs`. If every call suddenly returns
500 while login works, check the request headers before blaming the account
or the server.

## Web fallback

If the API breaks, the web app works with a plain cookie session:
`POST /Login` (form fields `username`, `password`, `returnUrl`, `login`) sets
`BakaAuth` and `ASP.NET_SessionId`. After that, server-rendered widgets such as
`/HomeWorks/Widget`, `/Timetable/SubstitutionWidget`, and
`/Dashboard/NoticesWidget` return HTML. Absence excuses are sent from
`/next/komens_zprava.aspx?l=abs`.
