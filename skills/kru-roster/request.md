# A requester asks for a new seat or skill

Someone asks for a new seat, a new skill, or a change to how kru behaves. This path turns that request into `hire` or `author`.

## 1. Restate

Three lines: what it is responsible for, where it stops beside the nearest existing seat, and its official source.

When an existing seat already covers the responsibility, the reply names that seat and how to use it, and the path ends there.

Done when the three lines are written, or the reply names the covering seat.

## 2. Choose and brief

A new seat is [`hire.md`](hire.md). A new skill, or a change to a skill that already exists, is [`author.md`](author.md). Read that file.

Run the chosen recipe from a local checkout of this plugin (or a Cursor cloud agent on a branch), following [`writing-for-agents`](../kru-writing-for-agents/SKILL.md). The brief carries the goal, the constraints, the done-check and the proof ([`reliable-work`](../kru-reliable-work/SKILL.md)).

Done when [`audit`](audit.md) passes on the branch.

## 3. Ship

Leave `commit`+`tag` to the user unless they asked (git rule). A release happens only when the user runs `/kru-roster release` per `release.md`. Tell the requester the version, the name of the seat or skill, and to update the plugin and then run `/kru-setup`.

Done when the requester has the version, the name, and those two steps.
