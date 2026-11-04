# Site pages
- Read docs/frontend.md before changing or adding a page: the UI is being rebuilt as one
  component system for the site and the desktop app
- meionotes, Jacob's notes on the site: `deploy/meionotes.sh list`; before UI work on a
  page, read its meionotes. Commit a fix with `deploy/commit.sh --meionote N` (the deploy
  marks it fixed), a broad one into a plan doc then `meionotes.sh fixed N <doc>`, none
  needed `kept N WHY`. Never `done`: that is Jacob's check
