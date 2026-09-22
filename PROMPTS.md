# PROMPTS.md — Module 4 Hands-on (CS5013)

Log of AI prompts/replies and reflections for Sessions 4A and 4B.
Repo: https://github.com/rikire/m4-hands-on

---

## Session 4A — AI-assisted debugging

### Setup

- `make test` reproduces the failing test: `quotesDiscountForLoyalCustomer`
  (assertion: expected `<90.0>` but was `<95.0>` — 5-year loyalty customer
  should get 10% off (tier 3), `PriceEngineTest.java:92`).

### Part A — Explain the stack trace

Prompt used (unchanged each time):

> Explain this Java stack trace in plain English. What is the most likely
> root cause? Do NOT propose a patch yet.

Full trace being pasted incrementally (from `make test`):

```
org.opentest4j.AssertionFailedError: 5-year loyalty customer should get 10% off (tier 3) ==> expected: <90.0> but was: <95.0>
	at org.junit.jupiter.api.AssertionFailureBuilder.build(AssertionFailureBuilder.java:151)
	at org.junit.jupiter.api.AssertionFailureBuilder.buildAndThrow(AssertionFailureBuilder.java:132)
	at org.junit.jupiter.api.AssertEquals.failNotEqual(AssertEquals.java:197)
	at org.junit.jupiter.api.AssertEquals.assertEquals(AssertEquals.java:86)
	at org.junit.jupiter.api.Assertions.assertEquals(Assertions.java:1020)
	at PriceEngineTest.quotesDiscountForLoyalCustomer(PriceEngineTest.java:92)
	at java.base/java.lang.reflect.Method.invoke(Method.java:580)
	at java.base/java.util.ArrayList.forEach(ArrayList.java:1596)
	at java.base/java.util.ArrayList.forEach(ArrayList.java:1596)
```

Each paste below went to a fresh, separate subagent — no memory of the
other pastes, no framing that this is a course assignment. Unlike the
first attempt, this time each one had normal read access to
`/home/remi/study/PAI/hand4/m4-pub`, the same as Copilot/Claude Code would
have sitting in the editor with the project open (see note at the end —
this mattered a lot).

---

**Paste 1 — just the first line**

AI's reply (verbatim, key part):

> Most likely root cause: an off-by-one boundary error in the tier
> selection logic in `PriceEngine.java`. The tiering is implemented as:
> `if (years > 5) { loyaltyRate = 0.10; } else if (years >= 3) { ... }`.
> The comment above it documents tier 3 as "5+ years: 10% off," but the
> code checks `years > 5` instead of `years >= 5`. So a customer with
> exactly 5 years of loyalty falls through to the `years >= 3` branch and
> gets 5% instead of 10%.

My note: pinpointed the exact line and the exact fix from one message,
because it just opened `PriceEngine.java` on its own. No ambiguity left.

---

**Paste 2 — first two lines**

Same diagnosis, verbatim: "*The stack frame shown is just JUnit's internal
machinery for constructing the failure — it's not pointing you at the
bug*", followed by the identical `years > 5` finding.

My note: nothing changed. It even said out loud that the extra frame was
useless.

---

**Paste 3 — first six lines**

Same diagnosis again. Verbatim: "*Looking at `PriceEngine.quote()`... the
code uses `years > 5` instead of `years >= 5`... Confirmed this by reading
`PriceEngine.java` and `PriceEngineTest.java`.*"

My note: at this point it's not reading the trace anymore, it's reading
the source. The trace is almost decorative.

---

**Paste 4 — first seven lines**

Same diagnosis, but now it says this outright:

> The test file itself contains a comment (lines 86-88) explicitly stating
> this is a "planted off-by-one" bug for a course exercise (Session 4A),
> confirming the diagnosis.

My note: that's `PriceEngineTest.java:86-88` — the test has a comment that
literally says "the bug the student is asked to find in Session 4A." The
AI isn't diagnosing anything here, it's reading the answer key.

---

**Paste 5 — full trace**

Same result, same comment citation. Adding the last three frames
(`Method.invoke`, two `forEach`) changed nothing — as before, they're JUnit
Platform's test-runner plumbing.

My note: no new information, same as every other paste this round.

---

**How much trace do you actually need?** Once the AI can open the repo,
the answer to "how much trace" barely matters — all five pastes, down to
just the assertion message, produced the exact file, exact line (57), and
exact fix. What actually did the work wasn't the trace, it was
`PriceEngine.java`'s own doc comment ("tier 3 (5+ years): 10% off")
contradicting its code (`years > 5`), plus — more bluntly — a comment in
`PriceEngineTest.java` that names this as a planted exercise bug. So the
real finding from round 2: giving the panel repo access changes the
exercise from "infer the cause from a trace" into "let it read the
comments," which is realistic (that's what Copilot/Claude Code actually
does) but also means the starter code's own comments spoil the exercise
once the AI is allowed to look. The trace-length question from round 1
still holds for a *codeless* AI (message + one file-naming frame is
enough); with repo access, even that one frame is redundant.

### Part B — Propose and verify the patch

Prompt used (sent to a fresh, repo-aware subagent, same setup as Part A round 2):

> Given root cause X (an off-by-one boundary error in the tier-3
> loyalty-discount check in PriceEngine.quote: the code checks `years > 5`
> instead of `years >= 5`, so a customer with exactly 5 years of loyalty
> falls into the tier-2 bucket (5% off) instead of tier-3 (10% off)), write
> the smallest patch that fixes the bug without changing behaviour on any
> other test. Show only the diff.

Diff proposed by AI (verbatim):

```diff
--- a/src/PriceEngine.java
+++ b/src/PriceEngine.java
@@ -54,7 +54,7 @@
         int years = customer.loyaltyYears();
         double loyaltyRate;
-        if (years > 5) {                     
+        if (years >= 5) {                     
             loyaltyRate = 0.10;
         } else if (years >= 3) {
             loyaltyRate = 0.05;
```

Manual review: one-character change (`>` → `>=`), touches only the tier-3
branch. Checked every other branch by hand: `years >= 3` and `years >= 1`
are untouched, and any `years > 5` value was already `true` before this
change (it's still `true` under `>=`), so the only input whose behaviour
changes is `years == 5` — exactly the case the failing test covers. No
other test path is affected.

- `make test` result after applying: all 10 tests pass, including
  `quotesDiscountForLoyalCustomer`. No regressions.
- Commit: `fd52e2b` — "Fix off-by-one in loyalty tier-3 boundary check"
  (message drafted by AI, "why" line added by hand; committed with `-m`
  instead of interactive `-e` since this session has no terminal editor —
  see note below).

### Part C — Reflect

- Most useful reply vs. least useful: _TBD_
- How much stack trace should be given to the AI / consequence of full vs.
  partial trace: _TBD_

---

## Session 4B — Reducing cyclomatic complexity

### Setup

- PMD/SpotBugs are **not** wired into this starter's Makefile (per
  `README.md`: "PMD/SpotBugs are not wired in here (they show up in
  Modules 5/8)"). Manual cyclomatic complexity estimate for `quote`:
  _TBD_ (README states ~14).

### Part A — Rank refactor targets

Prompt used:

> Rank the methods in this file by refactoring priority. For each, give:
> (a) current cyclomatic complexity estimate, (b) the single refactor move
> you would apply first (extract-method, flatten-guard-clauses,
> replace-loop-with-pipeline, or rename), (c) one sentence on the expected
> complexity reduction. Do not propose code yet.

Ranking (AI reply): _TBD_

### Part B — Apply one extract-method refactor

Prompt used:

> Extract the loyalty-tier discount block into a private helper method
> `applyLoyaltyDiscount(...)`. Do NOT change public method signatures. Show
> the diff.

- Diff review checklist:
  - Changed types in parameters/return? _TBD_
  - Missing `final` modifiers? _TBD_
  - Silently-lifted early returns? _TBD_
- `make test` result after applying: _TBD_
- Cyclomatic complexity on `quote` before → after: _TBD_
- Commit hash (atomic): _TBD_

### (Optional) Part C — Fix a SpotBugs finding with AI

- Skipped / _TBD_ (SpotBugs not installed in this environment; PMD/SpotBugs
  are deferred to Modules 5/8 per the starter README).

### Part D — Reflect

- Cyclomatic complexity drop: _TBD_
- Did the SpotBugs fix require understanding the rule, or was the AI's
  explanation enough? _TBD_
- One refactor the AI proposed but was rejected, and why: _TBD_
