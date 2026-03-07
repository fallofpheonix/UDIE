# 🧠 7 Debugging Habits of Strong SREs

This document Codifies the core behaviors that separate senior systems engineers from average developers. Adhering to these habits reduces MTTR (Mean Time To Recovery) and prevents speculative debugging.

---

## 1. Always Reproduce the Problem First
Speculative fixes cause regressions. A strong engineer never attempts a fix until they have a **consistent, repeatable command** that triggers the failure.
> *Smallest Evidence: A `curl` or `scripts/diagnose-udie.sh` output that fails every time.*

## 2. Check the Logs Before Reading Code
The system state is in the logs, not your memory. Never open a source file until you have scrutinized the runtime output.
> *Tooling: `docker logs udie-backend --tail 100 -f`*

## 3. Verify the System Layers (Bottom-Up)
Never debug the whole system at once. Isolate layers:
1. **Infra**: Docker & Network.
2. **Data**: Postgres & Redis.
3. **App**: Core logic & Workers.
4. **API**: Contract & Prefixes.
5. **UI**: Client integration.

## 4. Use Simple Commands Over Complex Tools
Complex debuggers can hide reality. Rely on the "Unix Toolkit": `curl`, `psql`, `redis-cli`, `grep`, and `lsof`.
> *Rule: If you can't see the error with `curl`, you don't understand the network path.*

## 5. Assume Configuration Is the Primary Failure
Code rarely changes on its own, but environments drift. Check `.env`, API prefixes, and physical device IP connectivity before refactoring logic.

## 6. Change Exactly One Thing at a Time
Changing multiple variables at once makes debugging non-deterministic. Change one thing, verify, then move to the next.

## 7. Write Small Diagnostic Scripts
Automation is the highest form of engineering. If you find yourself checking something twice, write a script for it.
> *Implementation: `scripts/diagnose-udie.sh`, `scripts/classify-failure.sh`*

---

MIT © 2026 **UDIE Engineering Group**. 
"In God we trust; all others must bring evidence."
