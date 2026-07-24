# demo-contract-provider

A minimal Spring Boot HTTP **provider** demonstrating automated cross-repository
contract-impact verification with **Spring Cloud Contract** (Groovy DSL), **no
broker** and **no artifact publishing**.

Endpoint:

```
GET /api/greetings/{name}  ->  200 {"message":"Hello {name}"}
```

- Java 21, Maven, Spring Boot 3.4.1, Spring Cloud 2024.0.0 (Contract 4.2.0).
- Static demo version: `1.0.0-SNAPSHOT` (never bumped per-PR).
- Groovy contract in `src/test/resources/contracts/greetings/`.
- Producer contract tests are **generated** from that contract; the `*-stubs.jar`
  is installed **only** into the runner-local Maven repository.

## What the demo proves / does not prove

**Proves:** When a provider PR changes the contract-relevant behaviour (e.g.
renames the `message` field), an automated GitHub Actions flow builds the exact
PR commit and runs the **real consumer tests** against the resulting stubs,
reporting pass/fail back on the PR — with no developer-run Maven commands after
the PR is raised, and no artifacts published anywhere.

**Does not prove:** That every consumer everywhere is discovered (discovery is
best-effort — see below), nor that runtime concerns beyond the contract (auth,
performance, Kafka, etc.) are safe. Installing a JAR and running a build is *not*
verification; the workflows explicitly run the changed consumer's tests.

## Architecture / PR verification flow

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant PP as Provider PR
    participant D as discover job
    participant M as verify matrix (parallel, 1 job / consumer)
    participant R as report job
    participant GH as GitHub API

    Dev->>PP: Open / update PR
    PP->>D: cross-repo-verify.yml
    D->>GH: Read pom coords, Code Search + confirm each consumer pom
    D-->>M: matrix = [confirmed consumers]
    par one job per consumer (fail-fast:false, max-parallel:10)
        M->>M: checkout provider@SHA (depth 1) + consumer@default (depth 1)
        M->>M: mvn install provider -> runner-local .m2 (stubs)
        M->>M: mvn test consumer (StubsMode.LOCAL)
        M->>R: upload result artifact (pass/fail + job link)
    end
    R->>GH: single commit status + one summary comment listing breaking repos
    GH-->>PP: ✅/❌ required status check
```

> Fan-out, not a single mega-job: each matrix job checks out only **two** repos
> (provider@SHA + one consumer) with `fetch-depth: 1`, so wall-clock time is
> roughly one build long regardless of consumer count (bounded by `max-parallel`).

## Local test instructions

```bash
# Build, generate + verify contract tests, install stubs into local .m2
mvn clean install

# Confirm the generated producer contract test exists
find target/generated-test-sources -name '*.java'

# Confirm the stubs jar was installed locally (nothing is published remotely)
find ~/.m2/repository/com/example/demo/demo-contract-provider -name '*stubs*.jar'
```

To use an ephemeral, runner-local repository (as CI does):

```bash
mvn clean install -Dmaven.repo.local=/tmp/m2
```

## Breaking-change demonstration

Rename the contract-relevant field and watch consumer verification fail:

1. In `src/main/java/com/example/provider/Greeting.java` rename `message` → `content`.
2. In `src/test/resources/contracts/greetings/shouldReturnGreeting.groovy` change
   `message:` → `content:` and update the provider's own tests.
3. `mvn clean install` — stubs now emit `{"content":...}`.
4. The consumer's `GreetingClientStubRunnerTest` (which expects `message`) fails.

Restore the field to return to green.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `pr-build.yml` | `pull_request`, `workflow_dispatch` | Own build + contract verification; installs stubs into runner-local `.m2`. |
| `cross-repo-verify.yml` | `pull_request`, `workflow_dispatch` | `discover` downstream consumers → `verify` matrix (parallel, one job per consumer, each runs that consumer's tests against provider@SHA stubs) → `report` single status + summary comment. |

`cross-repo-verify.yml` accepts a `workflow_dispatch` input (`consumer_repo`) to
verify a single consumer manually for demos/troubleshooting.

> **Alternative (cross-org / partner-owned):** if verification must execute in
> the consumer's own repo instead of in-repo, replace the matrix with a
> `repository_dispatch` to the consumer (payload = provider SHA) and a receiver
> workflow on the consumer's default branch. Same steps, extra hop; needs
> `Contents: write` to create the dispatch. The in-repo matrix above is used
> here because it is faster and self-contained for the demo.

## GitHub App / PAT setup

Production design uses a **GitHub App** installed on both repos. A fine-grained
**PAT** is documented as a demo-only fallback.

### Required GitHub App permissions (verify against current GitHub docs)

| Scope | Access | Why |
|-------|--------|-----|
| **Metadata** | Read | Always required. |
| **Contents** | Read (both repos) | Check out this repo + the partner repo (private) in the matrix. `Contents: write` is only needed for the `repository_dispatch` alternative described above. |
| **Commit statuses** | Read + write | Post the single branch-protection status check. |
| **Pull requests** | Read + write | Create/update the one summary comment. |
| **Checks** | Write | Only if you switch reporting to Check Runs instead of commit statuses. |

> Verified: the `repository_dispatch` alternative requires `Contents: write` for
> fine-grained tokens / GitHub Apps
> (https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event).
> The in-repo matrix used here needs only `Contents: read` on both repos plus
> statuses/PR write. Confirm against current REST docs before enabling in production.

### Repository variables and secrets

| Name | Kind | Used by | Notes |
|------|------|---------|-------|
| `APP_ID` | Variable | cross-repo-verify | GitHub App id. If empty, PAT fallback is used. |
| `PARTNER_REPO` | Variable | discovery fallback | `owner/demo-contract-consumer`. Deterministic partner when Code Search is cold. |
| `APP_PRIVATE_KEY` | Secret | cross-repo-verify | GitHub App private key (PEM). |
| `DISPATCH_PAT` | Secret | fallback | Fine-grained PAT (Contents: R on both repos, Statuses: W, Pull requests: W, Metadata: R), demo only. |

## Dependency discovery (and its limits)

Discovery is **automated** but **not authoritative**:

- GitHub **dependency graph** can identify supported Maven relationships.
- GitHub **Code Search** finds Maven coordinates / Stub Runner ids, but is
  text-based, may have indexing delay, and is not guaranteed complete.
- HTTP calls, Kafka topics, runtime, dynamically-constructed, and test-only
  relationships may not appear.
- Every candidate is confirmed by reading its `pom.xml`; `PARTNER_REPO` gives a
  deterministic fallback.
- Production likely needs a **generated typed service graph** with a small,
  audited manual override for relationships that cannot be inferred.

## Security model / limitations

- Runs only for same-repo PRs; **fork PRs never receive credentials**.
- Payloads are **validated** (`^[0-9a-f]{40}$` SHA, `owner/name` repo, numeric PR)
  to prevent repository/command injection.
- Cross-repo builds always use the **originating PR SHA**, never an untrusted
  branch name.
- Least-privilege `permissions:`, per-job `timeout-minutes`, and `concurrency`
  groups that cancel superseded runs.
- App tokens are scoped to just the two repositories involved.

## Troubleshooting

- **`StubNotFoundException`**: the provider wasn't installed into the job `.m2`,
  or `provider.stubs.version` doesn't match. Check the install step logs.
- **Discovery found nothing**: set `PARTNER_REPO`, or use the receiver's
  `workflow_dispatch` inputs to run verification manually.
- **Dispatch 404/403**: token lacks `Contents: write`, or the App isn't installed
  on the target repo.
- **No status on PR**: `Commit statuses: write` missing, or the reporting token
  can't see the originating repo.

## Remote setup (run yourself — not done automatically)

```bash
cd demo-contract-provider
git init && git add . && git commit -m "Initial provider demo"
gh repo create demo-contract-provider --private --source=. --remote=origin --push
# Variables / secrets:
gh variable set PARTNER_REPO --body "<you>/demo-contract-consumer"
gh variable set APP_ID       --body "<app-id>"
gh secret   set APP_PRIVATE_KEY < app-private-key.pem
# Demo-only PAT fallback:
gh secret   set DISPATCH_PAT  --body "<fine-grained-pat>"
# Branch protection: require the 'contract-verification/consumer' status check.
```
