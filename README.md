# Customer Portal — Deployment Guide

Use a **throwaway Developer Edition org** (Person Accounts cannot be disabled).

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), Windows for `init-setup-org.bat`, org alias **`coffee-dev1`**.

---

## Checklist

| # | What | How |
|---|------|-----|
| 1 | Org + My Domain | Manual |
| 2 | `sf org login web --alias coffee-dev1 --set-default` | Manual |
| 3–6 | Experiences, site, business record types, perm sets | `init-setup-org.bat` |
| 3b | Sites domain name (one-time, permanent) | Setup → Digital Experiences → Settings |
| 7 | Person Accounts (irreversible) | Manual, then re-run bat |
| 8 | Org-wide email — add & **verify** | Manual |
| 9 | Replace placeholders in project | Manual |
| 10 | Deploy metadata | `sf project deploy start --source-dir force-app` |
| 11 | Publish site + test login | Manual |
| 12 | Demo data (optional) | `test-data/` scripts |

---

## Setup script

```bat
init-setup-org.bat
```

Creates Digital Experiences, **Customer Portal** site (`/customerportal`), business Account RTs (Agency, Agency B2B, Carrier, Carrier B2B), permission sets/profiles. Person Account **Customer** RT deploys with metadata in step 10.

Wait ~1 min after site creation before deploy.

---

## Person Accounts

Setup → Person Accounts → Check Readiness → Enable → re-run `init-setup-org.bat`.

---

## Email setup (important)

You need **two different values**:

### 1. Org-wide email (for sending mail **from** the portal)

1. **Setup → Organization-Wide Email Addresses → Add**
2. Pick your sender address, set Display Name e.g. `COVU` or `Customer Portal`
3. Save → click verification link → confirm **Verified**

Use this **same verified address** in:

| Where | Placeholder to replace |
|-------|------------------------|
| Custom Metadata `Customer_Portal_Settings.Sender_Email` | `askaslam@gmail.com` |
| Network `emailSenderAddress` | `askaslam@gmail.com` |
| Hardcoded refs in Apex/LWC (search project) | `askaslam@gmail.com` |

> After deploy you can also edit **Setup → Custom Metadata Types → Customer Portal Settings → Sender Email** without redeploying code.

Renewal batch emails look up OWA by Display Name **`COVU`** — use that display name when creating the address (or update the batch classes).

### 2. Admin username (for ownership, routing & community admin)

Use the **username of the user running setup** (your login, e.g. `you@example.com`):

| Where | Placeholder to replace |
|-------|------------------------|
| Queues (Service/Tech Support members) | `replyami@yahoo.com` |
| Case assignment & escalation rules | `replyami@yahoo.com` |
| Case default owner/user | `replyami@yahoo.com` |
| Site admin & guest default owner | `replyami@yahoo.com` |
| Custom Metadata `Automation_Settings.Renewal_Case_Email_Recipient` | `replyami@yahoo.com` |

> Queues and rules reference a **User**, not an email address. Use your Salesforce **username**.

**Also update:** favicon host in `experiences/Customer_Portal1/config/mainAppPage.json` (`kapeecoffee7-dev-ed.develop.my.site.com` → your sites domain).

Do steps 8–9 **before** metadata deploy.

---

## Deploy

```bash
sf project deploy validate --source-dir force-app --target-org coffee-dev1
sf project deploy start --source-dir force-app --target-org coffee-dev1
```

---

## After deploy

1. **Digital Experiences → Customer Portal → Publish**
2. Assign **Customer Portal User** profile + permission sets to community users
3. Login: `https://<sites-domain>.my.site.com/customerportal`

### Demo data (optional)

Execute Anonymous, in order:

1. `test-data/data/Account_insert.txt`
2. `test-data/data/Policy_insert.txt`
3. `test-data/scripts/01_create_portal_users.apex`
4. `test-data/scripts/02_create_cases_and_surveys.apex`
5. `test-data/scripts/03_create_documents.apex`

In step 1, demo customer `PersonEmail` values use Gmail plus addressing (e.g. `you+customer1@gmail.com`) so portal/password emails reach your real inbox. Edit those three addresses at the top of `Account_insert.txt` only.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Script fails | Complete login (step 2); run `sf org display -o coffee-dev1` |
| Deploy fails on network/site | OWA must be **Verified** and match placeholders |
| Emails not sending | Check OWA verified + `Sender_Email` custom metadata matches |
| Person Account errors | Enable Person Accounts before full deploy |
