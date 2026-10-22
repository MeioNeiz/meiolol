# Accessibility tools audit results - Overview - GDS accessibility team

<https://alphagov.github.io/accessibility-tool-audit/>

[Accessibility tool audit](https://alphagov.github.io/accessibility-tool-audit/index.html)

1.  Overview

# How do automated accessibility checkers compare?

We ran an audit to see what issues the different accessibility testing tools pick up. We deliberately introduced 142 accessibility barriers to a page of content, and ran them through 13 automated tools. We also had a look at features like usability and cost.

You can use our audit to help choose the best accessibility testing tool for your service.

The full project is available on [Github](https://github.com/alphagov/accessibility-tool-audit). We welcome contributions.

## What we found

We scored each tool for two things.

The first column of numbers shows the percentage of barriers that each tool fully detected on a ‘pass’ or ‘fail’ basis.

The best performing tool in this category found 40% of the problems we introduced. Whereas the worst performing tool only picked up 13% of the barriers.

The second column of results takes into account potential barriers that tools noticed, but needed a human being to check, like whether alt text descriptions were accurate. A tool that flags things like this can help you pick up more issues overall.

The best performing tool in this category picked up 50% of our deliberate mistakes.

### How did each tool do?

| Tool | Barriers found | Barriers and potential barriers found |
| --- | --- | --- |
| [SortSite](https://www.powermapper.com/products/sortsite/) | 40% | 40% |
| [Tenon](https://tenon.io/) | 34% | 34% |
| [AChecker](http://achecker.ca/) | 31% | 35% |
| [WAVE](http://wave.webaim.org/extension/) | 30% | 39% |
| [aXe](https://www.axe-core.org/) | 29% | 30% |
| [Siteimprove](https://siteimprove.com/) | 29% | 36% |
| [ASLint](https://www.aslint.org/) | 28% | 35% |
| [FAE](https://fae.disability.illinois.edu/) | 28% | 50% |
| [Asqatasun](http://asqatasun.org/) | 25% | 47% |
| [HTML\_CodeSniffer](https://squizlabs.github.io/HTML_CodeSniffer/) | 20% | 34% |
| [EIII](http://checkers.eiii.eu/) | 17% | 17% |
| [Google ADT](https://github.com/GoogleChrome/accessibility-developer-tools) | 17% | 17% |
| [Nu Html Checker](https://validator.w3.org/nu/) | 13% | 16% |

Last updated: 13 April 2018

### How do features compare?

We’ve also compared features like how easy tools are to use, cost and technical considerations - all important things to think about when you are choosing a tool.

What these features mean

Feature comparison
| Tool | Cost (manual) | Cost (CI) | Open source | Active | CI | CLI | In-browser | Internal use | Mobile | Script­able | HTTP Auth | Guidance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Google ADT | Free | Free | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Tenon | Free trial,  
from $47 per month | From $47 per month | No | Yes | Yes | Yes | No | No | Yes | Yes | Yes | Good |
| WAVE | Free | Free trial,  
minimum $10 for 250 API calls | No | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| HTML\_­Code­Sniffer | Free | Free | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| aXe | Free | Free | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Good |
| Asqa­tasun | Free | Free | Yes | Yes | Yes | Yes | No | Yes | Yes | Yes | Yes | Good |
| Sort­Site | Free trial,  
from £24.50 per month or £69.30 once | From £384.30 once | No | Yes | Yes | Yes | No | Yes | No | No | Yes | Good |
| EIII | Free | N/A | Yes | No | No | No | No | No | Yes | No | No | OK |
| AChecker | Free | N/A | Yes | No | No | No | No | No | No | No | Yes | OK |
| Nu Html Checker | Free | Free | Yes | Yes | Yes | Yes | No | Yes | No | No | Yes | No |
| Site­improve | Free | N/A | No | Yes | No | No | Yes | Yes | Yes | No | Yes | Good |
| FAE | Free | N/A | Yes | Yes | No | No | Yes | Yes | Yes | No | Yes | OK |
| AS­Lint | Free | Free | No | Yes | Yes | Yes | Yes | Yes | Yes | ? | Yes | OK |

## Read more

[Read detailed test results](https://alphagov.github.io/accessibility-tool-audit/results.html)

[See everything we tested](https://alphagov.github.io/accessibility-tool-audit/test-cases.html)

[Read our blog post on what we found](https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/)

[Open Government Licence](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](http://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/copyright-and-re-use/crown-copyright/)
