# Allow an "estimated duration" for jobs and show a progress indicator - Features Requests - Buildkite Community Forum

<https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878>

[Skip to where you left off (last reply, post 5)](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/5) [Skip to top](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/1)

[Skip to main content](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878#main-container)

0

# [Allow an “estimated duration” for jobs and show a progress indicator](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

-   

-   [Topics](https://forum.buildkite.community/latest "All topics")
-   

-   [Changelog](https://buildkite.com/changelog)
-   [Documentation](https://buildkite.com/docs)
-   [System Status](https://www.buildkitestatus.com/)

-   [Announcements](https://forum.buildkite.community/c/announcements/8)
-   [General](https://forum.buildkite.community/c/general/23)
-   [Pipelines](https://forum.buildkite.community/c/pipelines/43)
-   [Elastic CI Stack for AWS](https://forum.buildkite.community/c/elastic-ci-stack-for-aws/9)
-   [Docker](https://forum.buildkite.community/c/docker/42)
-   [All categories](https://forum.buildkite.community/categories)

# [Allow an “estimated duration” for jobs and show a progress indicator](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

0

 

 

 

[Apr 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/1 "Jump to the first post")

1 / 5

Apr 2023

[May 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/5)

## post by shannon on Apr 19, 2023

[shannon](https://forum.buildkite.community/u/shannon)

[Apr 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878 "Post date")

It might be cool if, when specifying a job, it were possible to supply an “estimated job duration” field. The build/job UI could then display some sort of progress indicator comparing elapsed wall-clock time to estimated duration. Of course it would not be perfect, but some rough indication would be helpful. We have some short jobs (< 1 min) and some really long ones (~ 1 hour): making this obvious at a glance could be a win.

It could be left to whoever builds the pipeline to provide an estimate or BK could track historical data and do it automatically.

  

 

 

 

## post by james.s on Apr 19, 2023

[james.s](https://forum.buildkite.community/u/james.s) [Buildkite Staff](https://forum.buildkite.community/g/team)

[Apr 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/2 "Post date")

Hello [@shannon](https://forum.buildkite.community/u/shannon)!

Thanks for reaching out and for the suggestion! I don’t believe this sort of idea has been brought up before so I’ll raise the feedback to get ideas with Product around it.

Cheers 

  

## post by Ozdenyilmaz on Apr 21, 2023

[Ozdenyilmaz](https://forum.buildkite.community/u/ozdenyilmaz)

[Apr 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/3 "Post date")

Hi [@shannon](https://forum.buildkite.community/u/shannon) thanks for the feedback. I am from the product team and I’d love to understand a bit more of what you need.

Could you tell me what you’re trying to understand. Are you trying to see if your build is drastically over the average? If yes what do you do with this information next? Does it trigger you to update your steps or look at the commit that caused it or run it on a larger agent?

Do you look at this average information on a step level? Or overall build level?

And what is a problematic case for you? Is it when it is %50 over the average etc?

We will be looking into giving you metrics like that later in the year so let me know if you would like to be involved in user tests involving step/build metrics.

Thank you!

  

## post by shannon on Apr 27, 2023

[shannon](https://forum.buildkite.community/u/shannon)

[Apr 2023](https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878/4 "Post date")

> Could you tell me what you’re trying to understand

I’d just like to get a feel, at a glance, for how long to expect to wait for the build to complete. Do we have a couple of seconds remaining? A couple of minutes? An hour? Displaying this information at the step level would be most useful.

Jenkins does something like this by calculating an estimate based on the last 3 builds or so and then drawing a progress bar comparing the estimate with the elapsed time.

Noticing if build times are over the average could also be interesting for noticing problems, but is not the primary intent of the feature suggestion.

Yes, I’d be happy to be involved in user tests.

  

11 days later

## post by Ozdenyilmaz on May 8, 2023

  

### Related topics

Topic list, column headers with buttons are sortable.
| Topic | Replies | Views | Activity |
| --- | --- | --- | --- |
| [Build run times](https://forum.buildkite.community/t/build-run-times/4093)
[Pipelines](https://forum.buildkite.community/c/pipelines/43)

 | [3](https://forum.buildkite.community/t/build-run-times/4093/1) | 142 | [Dec 2024](https://forum.buildkite.community/t/build-run-times/4093/4) |
| [How to get start time and endtime for a job or step as Buildkite variable](https://forum.buildkite.community/t/how-to-get-start-time-and-endtime-for-a-job-or-step-as-buildkite-variable/3908)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

 | [1](https://forum.buildkite.community/t/how-to-get-start-time-and-endtime-for-a-job-or-step-as-buildkite-variable/3908/1) | 139 | [Aug 2024](https://forum.buildkite.community/t/how-to-get-start-time-and-endtime-for-a-job-or-step-as-buildkite-variable/3908/2) |
| [Pipelines dashboard: custom pipeline metrics](https://forum.buildkite.community/t/pipelines-dashboard-custom-pipeline-metrics/1433)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

 | [5](https://forum.buildkite.community/t/pipelines-dashboard-custom-pipeline-metrics/1433/1) | 1.6k | [Nov 2022](https://forum.buildkite.community/t/pipelines-dashboard-custom-pipeline-metrics/1433/6) |
| [Queue wait times metric](https://forum.buildkite.community/t/queue-wait-times-metric/1220)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

 | [9](https://forum.buildkite.community/t/queue-wait-times-metric/1220/1) | 1.7k | [Sep 2023](https://forum.buildkite.community/t/queue-wait-times-metric/1220/10) |
| [Adding queue wait time to buildkite-agent-metrics](https://forum.buildkite.community/t/adding-queue-wait-time-to-buildkite-agent-metrics/4626)

[Features Requests](https://forum.buildkite.community/c/feature-requests/11)

 | [3](https://forum.buildkite.community/t/adding-queue-wait-time-to-buildkite-agent-metrics/4626/1) | 67 | [Sep 4](https://forum.buildkite.community/t/adding-queue-wait-time-to-buildkite-agent-metrics/4626/4) |
