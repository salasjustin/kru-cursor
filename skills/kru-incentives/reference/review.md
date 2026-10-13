# Review — the reviewer is paid in findings

A reviewer's visible product is a finding list, and an empty one looks like no work. That pulls toward filing: branches nobody reaches, severities rounded up, mitigations that answer only *could an attacker* and never *would one*. Each such finding costs a round trip through the fix loop and cheapens the real ones beside it. The builder under review is paid in *done*; the review exists for that incentive, and inflating it trades one bias for another.

- **A finding names the actor who reaches it.** The user who hits the branch, the input that arrives, the attacker with a reason to send it. With no actor it's a scope decision, and `code-reviewer`'s *Not every unbuilt path is a finding* already settles those.
- **Severity is reach × harm, not capability.** The same bug is `high` on an anonymous endpoint and a non-event behind admin auth. A security finding runs `code-reviewer`'s incentive bullet; `security.md` is the build side of the same arithmetic.
- **A clean pass is a result.** State the coverage that produced it, so a short list reads as *looked and found little*, never as *didn't look*.
- **A proposed fix passes the same test as the finding.** A mitigation that makes the attack impossible in theory but leaves it profitable in practice buys nothing; one that prices it out does.
