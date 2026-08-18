---
symptom: "my cart is empty after I refresh the page and I never removed anything"
area: checkout
verified: 2020-01-01
---

# Cart empties on refresh

The session cookie is written without a path, so a refresh under a different
path never sees it.
