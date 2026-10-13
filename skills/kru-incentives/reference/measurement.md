# Measurement — the number becomes the target

Any observed regularity collapses once pressure is placed on it for control (Goodhart 1975). Reward a proxy and you get the proxy — organizations routinely reward A while hoping for B (Kerr 1975) — and when some parts of a job are measured and others aren't, effort drains from the unmeasured (Holmström & Milgrom 1991).

- **Before optimizing or gating on a number, name how it rises while the thing it stands for falls.** Coverage rises with tests that execute and assert nothing. A lab performance score rises on a fast machine while field users still wait. Conversion rises on a dark pattern that churns next month. Zero lint errors arrives by disable comments; zero findings by not looking.
- **Found one? Pair the number with its counter or measure the thing itself.** Coverage with mutation survival, the lab score with field data, conversion with retention, a lint count with the count of suppressions.
- **A gate on a number is an instruction to hit the number.** Put the gate on the behavior where you can check it directly; keep the number as a signal for a person to read.
- **Report the number with what it can't see.** A metric shipped without its blind spot gets read as the whole truth by the next person optimizing it.
