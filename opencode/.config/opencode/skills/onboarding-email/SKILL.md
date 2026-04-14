---
name: onboarding-email
description: >
  Generate onboarding emails for Perselio.com customers with analytics script deployment instructions.
  Use this skill whenever the user asks to write, draft, or compose an onboarding email, a script deployment email,
  a probe/sonda deployment message, or any customer communication about integrating Perselio tracking scripts.
  Also trigger when the user mentions "onboarding email", "sonda", "nasazeni sondy", "script deployment email",
  or asks to email a customer about their Perselio integration. Works with Linear issues to pull customer
  and site data automatically.
---

# Onboarding Email Generator for Perselio.com

Generate professional onboarding emails that inform customers about deploying the Perselio.com analytics script on their websites.

## Context

Perselio.com is an analytics product. During customer onboarding, a tracking script (called "sonda" / probe) is created for each customer site. The customer needs to embed this script in their site's HTML `<head>`. These emails instruct the customer on how and where to place the script, and request confirmation of deployment so the team can validate everything works.

## Gathering Required Information

Before generating the email, collect these pieces of information. If the user provides a Linear issue ID/link, read the issue first and extract what you can. Ask the user only for what's missing.

**Required fields:**

- **Customer name** (company or contact name for the greeting)
- **Site(s)**: one or more target website domains (e.g., `altisport.cz`, `emos.sk`)
- **Script identifier(s)**: short tenant identifiers used to build the script URL (e.g., `alt`, `emssk`)
- **Language**: Czech (default) or English

**Derived automatically:**

- **Script URL(s)**: constructed as `https://static.perselio.com/versions/v3/interactions-{tenant_identifier}.js`
- **Recipient email(s)**: extract from the Linear issue, comments, linked project, stakeholder tables, or related notes when present
- **Preferred primary recipient**: prefer a technical contact first (webmaster, developer, IT, e-shop admin, agency implementer). If no technical contact is available, use the main business owner/contact.
- **Greeting name**: if a concrete contact person is known, address them by name in the salutation

If the user provides a Linear issue, use the `linear_get_issue` tool to read it. Look for site domains, script identifiers, and contact emails in the issue description, comments, title, and linked project context. If you can't find some information, ask the user.

## Email Structure

The email follows a consistent structure. Adapt between the single-script and multi-script variants based on how many sites/scripts the customer has.

### Single Script Variant

Use when there is exactly one site/script pair.

```
Dobry den,

zasilam informace k nasazeni sondy Perselio.com

Vytvorili jsme sondu pro sber uzivatelskych interakci na webu {site_domain}.

URL:
{script_url}

Tento skript, prosim, umistete do hlavicky stranky v html dokumentu. Nejlepe bez vyuziti GTM kvuli rychlosti nacteni.

<html>
	<head>
		<script src="{script_url}" async></script>
		<!-- ostatni skripty -->
	</head>

</html>

Skript zatim nase plochy nevykresluji, pouze sbiraji analyticka data pro trenink AI modelu.

Nevahejte me kontaktovat, pokud nejsou instrukce jasne.
Kdy, prosim, bude skript nasazeny?
Radi bychom zvalidovali, ze vse bez problemu funguje.

Dekuji.
```

If a named contact is available, prefer a personalized greeting such as `Dobrý den, pane Cibulko,` or `Dobrý den, paní Nováková,`. If the gender/form is unclear, use a safe neutral form like `Dobrý den, Martine,` only when appropriate; otherwise fall back to `Dobrý den,`.

### Multiple Scripts Variant

Use when there are two or more site/script pairs.

```
Dobry den,

zasilam informace k nasazeni sondy Perselio.com

Vytvorili jsme sondy pro sber uzivatelskych interakci na webu/webech {customer_context}.

Zde je seznam:

{for each site/script pair:}
{site_domain}: {script_url}

Skript, prosim, umistete do hlavicky stranky v html dokumentu. Nejlepe bez vyuziti GTM kvuli rychlosti nacteni. Priklad ({example_site_short}):

<html>
	<head>
		<script src="{example_script_url}" async></script>
		<!-- ostatni skripty -->
	</head>

</html>

Skripty zatim nase plochy nevykresluji, pouze sbiraji analyticka data pro trenink AI modelu.

Nevahejte me kontaktovat, pokud nejsou instrukce jasne.
Kdy, prosim, bude skript nasazeny?
Radi bychom zvalidovali, ze vse bez problemu funguje.

Dekuji.
```

For the multi-script HTML example, pick one of the listed scripts (ideally a recognizable one, or the first in the list) to illustrate the pattern.

When recipient emails are known, also provide a ready-to-send envelope above the email body:

```
Predmet: Nasazeni sondy Perselio.com pro {site_or_customer}

Komu: {primary_email}
Kopie: {secondary_emails_if_any}
```

Pick the primary email using the technical-contact preference described above.

## Czech Diacritics

The templates above are shown without diacritics for readability. The actual output **must include proper Czech diacritics** (e.g., "Dobrý den", "zasílám", "Vytvořili jsme", "Děkuji", etc.). Always output correct Czech with full diacritics.

## English Variant

When the user requests English, adapt the content while keeping the same structure and tone. The key points to convey:

1. Greeting
2. We created a tracking probe/script for their site(s)
3. The script URL(s)
4. Place it in the HTML `<head>`, preferably without GTM for loading speed
5. Code example
6. The script only collects analytics data for AI model training, it doesn't render any visual elements yet
7. Contact us if instructions are unclear
8. When will the script be deployed? We'd like to validate everything works.
9. Thank you

## Workflow

1. **If a Linear issue is provided**: read it with `linear_get_issue`, extract customer name, site domains, script identifiers, and contact emails from the description/comments.
2. **Check linked project context**: if the issue lacks details, inspect the linked Linear project and stakeholder tables for domains, contact names, roles, and emails.
3. **Choose recipients**: if multiple emails are available, select the primary recipient as the most technical implementation owner (webmaster, IT, dev, agency implementer, e-shop admin). Put business stakeholders into CC unless the user asks otherwise.
4. **Ask for missing info**: if any required field is still missing after reading the issue/project (or if no issue was provided), ask the user.
5. **Construct script URLs**: build each URL using the pattern `https://static.perselio.com/versions/v3/interactions-{identifier}.js`
6. **Choose variant**: single script or multiple scripts based on the count.
7. **Generate the email**: output the complete email text, ready to copy-paste. If recipient emails are known, include `Předmět`, `Komu`, and optionally `Kopie` above the body.
8. **Use named salutation when safe**: if a clear contact person is known, personalize the greeting by name.
9. **Present to user**: show the email and ask if any adjustments are needed.

## Important Notes

- The default language is Czech. Only use English if explicitly requested.
- The brand name is **Perselio.com** — always use this exact form.
- Script URLs always use the base `https://static.perselio.com/versions/v3/interactions-{identifier}.js`.
- Always recommend placing the script in the HTML `<head>` without GTM (Google Tag Manager) for better loading performance.
- The `async` attribute on the script tag is important — always include it.
- Keep the tone professional but friendly — the Czech style uses polite "vy" form (vykání).
- When both business and technical contacts exist, prefer the technical person in `Komu` and keep the business owner in `Kopie`.
- If the user asks for a "final version", include the send-ready envelope (`Předmět`, `Komu`, `Kopie`) when the emails are known.
