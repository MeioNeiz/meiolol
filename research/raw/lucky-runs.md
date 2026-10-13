# NeurIPS Separating Real Improvements from Lucky Runs in Autonomous ML Research

<https://neurips.cc/virtual/2026/loc/sydney/157611>

[Skip to yearly menu bar](https://neurips.cc/virtual/2026/loc/sydney/157611#child-menu) [Skip to main content](https://neurips.cc/virtual/2026/loc/sydney/157611#main)

## Main Navigation

-   [NeurIPS](https://neurips.cc/virtual/2026/loc/sydney/157611#)
-   [My Stuff](https://neurips.cc/MyStuff)

[Login](https://neurips.cc/accounts/login?nextp=/virtual/2026/loc/sydney/poster/155994)

-    
-    
-    

-   [Select Year: (2026)](https://neurips.cc/virtual/2026/loc/sydney/157611#)
-   [Dates](https://neurips.cc/Conferences/2026/Dates)
-   [Submit](https://neurips.cc/virtual/2026/loc/sydney/157611#)
-   [Attend](https://neurips.cc/virtual/2026/loc/sydney/157611#)
-   [Organizers](https://neurips.cc/virtual/2026/loc/sydney/157611#)
-   [Exhibitors](https://neurips.cc/virtual/2026/loc/sydney/157611#)

  
  

Poster  
in  
Workshop: [Workshop for Autonomous Machine Learning Research](https://neurips.cc/virtual/2026/workshop/137509)

# Separating Real Improvements from Lucky Runs in Autonomous ML Research

Pratham Grover

[Project Page](https://openreview.net/forum?id=x3lY2QO0Xe) \[ [OpenReview](https://openreview.net/forum?id=x3lY2QO0Xe "OpenReview")\] 

### Abstract

Autonomous ML research agents increasingly operate by proposing many candidate changes, evaluating them under noisy training, and selecting the strongest observed result. We study how reliably improvements selected by this process survive independent evaluation. In a controlled nanoGPT environment, we first run the same training program across 60 seeds. Selecting the best of 32 runs produces an expected apparent improvement of 0.00544 validation bits-per-byte (val_bpb), or 2.7 times our preregistered meaningful-effect threshold delta = 0.002, a gain produced entirely by selection. We then evaluate a frozen 24-candidate bank containing exact-null controls, benchmark interventions, and modifications produced by an autonomous agent without access to the sealed evaluation seeds. Across 749 training runs, nine candidates are exact nulls by construction. Of the remaining 15 candidates, eight independently replicate as meaningful improvements, three fail replication, and four remain inconclusive. The agent finds several large improvements near 0.014 val_bpb. In this regime, the effects are large relative to the experimental noise, and preregistered search and confirmation policies make no false declarations on this bank. The harder cases are the smaller improvements near delta, several of which remain unresolved even after 24-33 sealed evaluations. Large effects are readily confirmed, while gains near the scale of experimental noise require substantially more evidence to resolve.

Chat is not available.

<table class="gdpr-statement"><colgroup><col> <col style="width:120px"></colgroup><tbody><tr><td style="padding:5px">NeurIPS uses cookies for essential functions only. We do not sell your personal information. <a href="https://neurips.cc/public/PrivacyPolicy">Our Privacy Policy »&nbsp;</a></td><td><button float-end="" class="btn btn-light btn-sm btn btn-outline-dark" id="accept_cookies_button">Accept</button></td></tr></tbody></table>

  

###### 

The NeurIPS Logo above may be used on presentations. Right-click and choose download. It is a vector graphic and may be used at any scale.

###### Useful links

-   [Press](https://neurips.cc/Conferences/2025/Press)
-   [Proceedings](https://proceedings.neurips.cc/)

###### Contact

1269 Law St, San Diego CA 92109

[Email](https://neurips.cc/Help/Contact)

[NeurIPS Proceedings](https://proceedings.neurips.cc/)
