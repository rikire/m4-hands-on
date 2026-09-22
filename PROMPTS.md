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
- Commit: `e366ebc` — "Fix off-by-one in loyalty tier-3 boundary check"
  (message drafted by AI, "why" line added by hand; committed with `-m`
  instead of interactive `-e` since this session has no terminal editor
  to review in).

### Part C — Reflect

- **Most useful:** the Part B patch reply — one prompt, one correct
  one-line diff, verified by tests. **Least useful:** pastes 2-3 and 5 of
  the Part A trace-explain loop — they just repeated the same diagnosis in
  different words while adding zero new lines of reasoning.
- Stack trace amount: without repo access, one line (the assertion
  message) was already enough to name the right mechanism; a second frame
  naming my own test file/line was the only other one worth pasting.
  With repo access, trace length stopped mattering entirely — the AI just
  opened the source and, worse, found a comment in the test file that
  names the exact planted bug. Full traces cost nothing but reading time
  here; they'd matter more for an unchecked exception where the *cause
  chain* (not just the top frame) carries information. Net: paste little
  first, add more only if the first answer is vague — and know that a
  repo-aware assistant may just read the answer off a comment instead of
  reasoning from the trace at all.

---

## Session 4B — Reducing cyclomatic complexity

### Setup

- PMD/SpotBugs are **not** wired into this starter's Makefile (per
  `README.md`: "PMD/SpotBugs are not wired in here (they show up in
  Modules 5/8)"). No PMD/SpotBugs run — deferred to later modules.
- Cyclomatic complexity of `quote`: README says "roughly 14"; the AI's
  own count (Part A below) came out at ~19-20 counting every branch
  including the compound `||` guard and the `&&` in the VIP20 check. Manual
  recount: 1 (base) + 2 (null/empty guard `||`) + 1 (loop) + 1 (qty guard)
  + 1 (expedited if) + 3 (promo if/else-if x3, one with an extra `&&` so
  +1 more) + 3 (loyalty if/else-if x3) + 3 (tax if/else-if x3) + 1
  (loyaltyRate>0 guard) + 1 (taxRate>0 guard) ≈ **18**. Close enough to the
  AI's estimate; the README's "~14" undercounts the promo/tax cascades.

### Part A — Rank refactor targets

Prompt used:

> Rank the methods in this file by refactoring priority. For each, give:
> (a) current cyclomatic complexity estimate, (b) the single refactor move
> you would apply first (extract-method, flatten-guard-clauses,
> replace-loop-with-pipeline, or rename), (c) one sentence on the expected
> complexity reduction. Do not propose code yet.

Ranking (AI reply, verbatim, repo-aware subagent):

> The file defines exactly one method — `PriceEngine.quote(Order,
> Customer)`. There's nothing else to rank against it, so the "ranking"
> below is really a priority-ordered breakdown of that method's five
> internal responsibilities (subtotal, surcharge, promo, loyalty, tax).
>
> **1. `quote(Order, Customer)` — highest (and only) priority**
> (a) Cyclomatic complexity estimate: ~19-20 — driven by the compound
> null/empty guard, the subtotal loop plus its inner guard, the expedited
> `if`, a 3-branch promo cascade (one with an extra `&&`), a 4-way
> loyalty-tier cascade, a 4-way region-tax cascade, and two more gating
> `if`s.
> (b) First move: **extract-method** — the Javadoc already documents five
> sequential steps, each delimited by a numbered comment, a strong signal
> they were designed as independent units.
> (c) Expected reduction: `quote()`'s own complexity would drop from ~20 to
> roughly 5-6, redistributing the rest into five small methods at CC 2-6
> each.
>
> Secondary candidates once extraction happens: the promo/loyalty/tax
> cascades would benefit from **rename** (e.g.
> `loyaltyDiscountRate`, `taxRateForRegion`) to make the magic
> strings/numbers self-documenting — low urgency, not complex on their
> own, just misplaced. The subtotal loop could take
> **replace-loop-with-pipeline**, but that's stylistic, not a complexity
> win. The top guards are already flat, so **flatten-guard-clauses**
> doesn't apply.

My note: only one method exists, so "ranking" collapsed into "which block
inside `quote` to pull out first" — which is exactly what Part B asks for
next. Its CC estimate (~19-20) landed close to my manual recount (~18),
both well above the README's "~14".

### Part B — Apply one extract-method refactor

Prompt used:

> Extract the loyalty-tier discount block into a private helper method
> `applyLoyaltyDiscount(...)`. Do NOT change public method signatures. Show
> the diff.

AI's diff (verbatim, from a repo-aware subagent that read the file first):

```diff
--- a/src/PriceEngine.java
+++ b/src/PriceEngine.java
@@ -48,20 +48,8 @@
             }
         }
 
-        // 4. Loyalty-tier discount
-        //    tier 1 (1-2 years):  2% off
-        //    tier 2 (3-4 years):  5% off
-        //    tier 3 (5+ years):  10% off
-        int years = customer.loyaltyYears();
-        double loyaltyRate;
-        if (years >= 5) {
-            loyaltyRate = 0.10;
-        } else if (years >= 3) {
-            loyaltyRate = 0.05;
-        } else if (years >= 1) {
-            loyaltyRate = 0.02;
-        } else {
-            loyaltyRate = 0.0;
-        }
-        if (loyaltyRate > 0.0) {
-            running = running.subtract(subtotal.times(loyaltyRate));
-        }
+        // 4. Loyalty-tier discount
+        running = applyLoyaltyDiscount(running, subtotal, customer.loyaltyYears());
 
         // 5. Regional tax
         double taxRate;
@@ -84,4 +72,21 @@
 
         return running;
     }
+
+    private static Money applyLoyaltyDiscount(Money running, Money subtotal, int loyaltyYears) {
+        double loyaltyRate;
+        if (loyaltyYears >= 5) {
+            loyaltyRate = 0.10;
+        } else if (loyaltyYears >= 3) {
+            loyaltyRate = 0.05;
+        } else if (loyaltyYears >= 1) {
+            loyaltyRate = 0.02;
+        } else {
+            loyaltyRate = 0.0;
+        }
+        if (loyaltyRate > 0.0) {
+            return running.subtract(subtotal.times(loyaltyRate));
+        }
+        return running;
+    }
 }
```

- Diff review checklist:
  - Changed types in parameters/return? No — new helper returns `Money`,
    takes `(Money, Money, int)`, matches how it's called. `quote`'s own
    signature (`Money quote(Order, Customer)`) is untouched.
  - Missing `final` modifiers? None added, but the original file didn't
    use `final` on any local/parameter either — consistent with existing
    style, not a regression.
  - Silently-lifted early returns? No — the block never had an early
    `return`, just a conditional mutation of `running`; the helper
    reproduces that exactly (returns the discounted or original value).
- `make test` result after applying: all 10 tests pass, no regressions.
- Cyclomatic complexity on `quote`: ~18 → ~14 (the loyalty-tier cascade,
  3 if/else-if branches plus the `loyaltyRate > 0.0` guard, moved out);
  `applyLoyaltyDiscount` now carries that complexity on its own at ~5.
- Commit hash (atomic): `f9a7e08` — "Extract loyalty-tier discount into
  applyLoyaltyDiscount".

### (Optional) Part C — Fix a SpotBugs finding with AI

- Skipped: SpotBugs is not wired into this starter's Makefile (there's no
  `spotbugs` target), and the starter `README.md` says explicitly that
  PMD/SpotBugs "are not wired in here — they show up in Modules 5/8." No
  SpotBugs report exists to pick a finding from, so this optional part
  doesn't apply to this starter.

### Part D — Reflect

- **Complexity drop:** `quote` went from ~18 to ~14 (manual count); the
  ~5 points removed now live in `applyLoyaltyDiscount`, isolated and
  independently testable.
- **SpotBugs:** not applicable — not wired into this starter's Makefile
  (deferred to Modules 5/8 per README), so no rule to understand.
- **Rejected refactor:** the AI also suggested renaming the promo-code and
  region-tax cascades into named lookups (e.g. `taxRateForRegion`) and
  turning the subtotal loop into a filter+map+reduce pipeline. Rejected
  both — they don't reduce complexity (same branch count, just moved or
  restyled) and would touch more of the file for a purely cosmetic gain,
  which isn't worth the extra diff to review for this exercise.
