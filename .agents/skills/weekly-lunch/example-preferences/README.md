# Example preferences

These files are **examples**, not live configuration. They show the structure
the `weekly-lunch` skill expects your preference notes to have:

- `nutrition-spec.example.md` -- your nutrition targets (calorie band,
  lean-protein floor, saturated-fat ceiling, fiber, plate ratio, and the
  per-option deliverable). The numbers are illustrative -- set your own.
- `operating-rules.example.md` -- the operating rules that keep the
  recommendations complete, varied, and verified-real. Already generalized;
  copy as-is and adjust wording to taste.

## How to use them

On first setup, copy these into your own **private** preference notes under
`data/memories/` (that directory is gitignored, so your personal targets never
get committed or published). For example:

- `data/memories/lunch-nutrition-criteria` <- from `nutrition-spec.example.md`
- `data/memories/lunch-presentation-and-reminders` <- from `operating-rules.example.md`
- `data/memories/lunch-restaurant-notes` <- start empty; add per-restaurant
  gotchas as you learn them

Then edit the numbers and rules to your own goals. The skill (`SKILL.md`, step 0)
reads your notes -- not these examples -- on every run.

You'll also want a note recording whose line the orders go on in the Notion doc,
your Notion lunch-page URL, and your Slack DM channel id (see `SKILL.md`).
