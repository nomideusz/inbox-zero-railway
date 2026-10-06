# Deploy and Host Inbox Zero on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/inbox-zero?utm_medium=integration&utm_source=button&utm_campaign=inbox-zero)

[Inbox Zero](https://www.getinboxzero.com/) is the open-source AI email assistant for Gmail and Outlook. You describe how you want your email handled in plain English: label and archive newsletters, draft replies in your voice, flag cold outreach, follow up on threads nobody answered. Inbox Zero applies those rules to new mail as it arrives. It also has one-click bulk unsubscribe, a reply tracker, email digests, meeting briefs and an assistant chat over your inbox. This template runs the full self-hosted version with every premium feature unlocked, using your own AI provider key, so your mail never passes through someone else's SaaS.

## About Hosting Inbox Zero

The stack is four services: Inbox Zero, Redis-HTTP, Redis and Postgres.

- **Inbox Zero** is the Next.js web app and API on the public domain. It receives Gmail push notifications and Outlook webhooks, runs your rules through the LLM and acts on your mailbox.
- **Scheduled jobs built in.** Upstream runs a separate cron container that calls the app's job endpoints. Here the same loops run inside the Inbox Zero service and start once the app is healthy: scheduled actions and snoozes every 15 minutes, automation jobs, digests, meeting briefs and follow-up reminders, and Gmail/Outlook watch renewal every 6 hours. That keeps real-time notifications from expiring.
- **Redis-HTTP** is [serverless-redis-http](https://github.com/hiett/serverless-redis-http), the Upstash-compatible REST proxy that upstream's compose file also uses. Inbox Zero talks to Redis through it for caching, rate limits and locks.
- **Redis** backs that proxy and the live inbox updates in the UI.
- **Postgres** holds users, connected accounts, rules, history and encrypted OAuth tokens.
- **Safe first boot.** On a fresh deploy Postgres is often still starting. Upstream's start script skips failed migrations and boots anyway, which leaves an app without tables. This template retries the migrations until they succeed, and only then starts the server.
- **Locked to you.** Only the addresses in `AUTH_ALLOWED_EMAILS` can sign up, so nobody else can use your instance or your AI key.

## Common Use Cases

- An AI assistant that triages, labels, archives and pre-drafts replies for a busy founder or sales inbox
- Cleaning up years of newsletters and promotions with bulk unsubscribe and archive, without granting a third-party SaaS access to your mailbox
- A team or company deployment where email content and AI calls must stay on infrastructure you control, with your own LLM provider or zero-data-retention keys

## Dependencies for Inbox Zero Hosting

- Postgres 17 (included, private network only)
- Redis 8 and the serverless-redis-http proxy (included, private network only)
- A Google Cloud OAuth client (for Gmail) and/or a Microsoft Entra app registration (for Outlook)
- An API key from an LLM provider: Anthropic, OpenAI, Google, OpenRouter, Groq, Bedrock and more

### Deployment Dependencies

- [Inbox Zero self-hosting docs](https://docs.getinboxzero.com/hosting/self-hosting)
- [Google OAuth setup](https://docs.getinboxzero.com/hosting/google-oauth) and [Google Pub/Sub setup](https://docs.getinboxzero.com/hosting/google-pubsub)
- [Microsoft OAuth setup](https://docs.getinboxzero.com/hosting/microsoft-oauth)
- [LLM providers and model settings](https://docs.getinboxzero.com/hosting/llm-setup)
- [Inbox Zero on GitHub](https://github.com/elie222/inbox-zero)
- [Template source on GitHub](https://github.com/nomideusz/inbox-zero-railway)

### Implementation Details

**Inbox Zero lives at the Inbox Zero service's Railway domain** (`https://<app>.up.railway.app`, written `YOUR_DOMAIN` below). You can deploy before you have the OAuth credentials: put placeholders in `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` and `GOOGLE_PUBSUB_TOPIC_NAME`, read the domain off the service once it is up, then come back and fill them in. The first boot runs the database migrations and takes 2–3 minutes.

**Gmail (Google OAuth)**

1. In [Google Cloud Console](https://console.cloud.google.com/), create or pick a project and open **APIs & Services → OAuth consent screen**. Choose **Internal** for Google Workspace, or **External** for personal Gmail. With External, add your own address under **Audience → Test users**.
2. Under **Data Access → Add or remove scopes**, add `userinfo.profile`, `userinfo.email`, `https://www.googleapis.com/auth/gmail.modify` and `https://www.googleapis.com/auth/gmail.settings.basic`.
3. Enable the [Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com).
4. Go to **Credentials → Create credentials → OAuth client ID → Web application**. Set **Authorized JavaScript origins** to `https://YOUR_DOMAIN`, and **Authorized redirect URIs** to:
   - `https://YOUR_DOMAIN/api/auth/callback/google`
   - `https://YOUR_DOMAIN/api/google/linking/callback`
   - `https://YOUR_DOMAIN/api/google/calendar/callback` (optional, calendar)
   - `https://YOUR_DOMAIN/api/google/drive/callback` (optional, Drive)
5. Copy the client ID and secret into `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` on the Inbox Zero service.
6. For real-time email processing, create a [Pub/Sub topic](https://console.cloud.google.com/cloudpubsub/topic/list) (for example `inbox-zero-emails`). Under its **Permissions**, grant `gmail-api-push@system.gserviceaccount.com` the **Pub/Sub Publisher** role.
7. On that topic, create a **Push** subscription with the endpoint `https://YOUR_DOMAIN/api/google/webhook?token=TOKEN`. Use the `GOOGLE_PUBSUB_VERIFICATION_TOKEN` value from the service's Variables tab as `TOKEN`.
8. Set `GOOGLE_PUBSUB_TOPIC_NAME` to the full name, `projects/<project-id>/topics/inbox-zero-emails`, and let the service redeploy.

**Outlook (Microsoft OAuth, optional)**

1. In the [Azure portal](https://portal.azure.com/), open **Microsoft Entra ID → App registrations → New registration**. Pick multitenant for any Microsoft account, or single tenant for your organization only. Add a **Web** redirect URI: `https://YOUR_DOMAIN/api/auth/callback/microsoft`.
2. Under **Authentication**, add `https://YOUR_DOMAIN/api/outlook/linking/callback`. Optionally add `https://YOUR_DOMAIN/api/outlook/calendar/callback` and `https://YOUR_DOMAIN/api/outlook/drive/callback`.
3. Under **API permissions → Microsoft Graph → Delegated**, add `openid`, `profile`, `email`, `User.Read`, `offline_access`, `Mail.ReadWrite`, `Mail.Send`, `MailboxSettings.ReadWrite`, `Calendars.Read`, `Calendars.ReadWrite` and `Files.ReadWrite`.
4. Under **Certificates & secrets → New client secret**, create a secret. Set `MICROSOFT_CLIENT_ID` (Application ID) and `MICROSOFT_CLIENT_SECRET` (the secret's **Value**). For single tenant, also set `MICROSOFT_TENANT_ID`.
5. Outlook only? Set `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` and `GOOGLE_PUBSUB_TOPIC_NAME` to `skipped`.

**AI provider.** `DEFAULT_LLMS` and `ECONOMY_LLMS` take `provider:model` entries, and the default is Anthropic. For OpenAI, use for example `openai:gpt-6-luna`; the same pattern works for `google:`, `openrouter:`, `groq:` and `bedrock:`. Put the matching key in `LLM_API_KEY`. A ChatGPT or Claude subscription does not include API access; the key needs billing credits on the provider's platform.

**Sign in** at `https://YOUR_DOMAIN` with Google or Microsoft, using an address listed in `AUTH_ALLOWED_EMAILS`. To add teammates, extend that list, or set `AUTH_ALLOWED_EMAIL_DOMAINS=yourcompany.com` instead.

**Memory.** Expect about 1.1 GB at idle on Railway: about 0.9 GB for Inbox Zero, 120 MB each for Redis-HTTP and Postgres, and under 10 MB for Redis. Inbox Zero alone is over the Trial plan's limit, so deploy on Hobby or above.

**Custom domain.** Add it in the Inbox Zero service's Settings → Networking. Set `NEXT_PUBLIC_BASE_URL` to `https://your.domain`, then update the OAuth redirect URIs and the Pub/Sub push endpoint to the new domain.

**Never change** `EMAIL_ENCRYPT_SECRET` or `EMAIL_ENCRYPT_SALT` after the first sign-in. They encrypt the stored OAuth tokens, so changing them disconnects every mailbox.

**Backups.** Everything lives in Postgres, so turn on Railway's volume backups for the Postgres volume.

## Why Deploy Inbox Zero on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Inbox Zero on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
