# Runs - Open Machine Learning

<https://docs.openml.org/concepts/runs/>

[Skip to content](https://docs.openml.org/concepts/runs/#runs)

Open Machine Learning

Runs

  

Type to start searching

-   [OpenML](https://docs.openml.org/)
-   [Get Started](https://docs.openml.org/intro/)
-   [Datasets](https://docs.openml.org/data/)
-   [Benchmarking](https://docs.openml.org/benchmark/)
-   [Ecosystem](https://docs.openml.org/ecosystem/)
-   [Contributing](https://docs.openml.org/contributing/)
-   [Questions](https://docs.openml.org/help/)
-   [Python](https://docs.openml.org/python/)
-   [PyTorch](https://docs.openml.org/pytorch/)
-   [TensorFlow](https://docs.openml.org/tensorflow/)
-   [Julia](https://docs.openml.org/julia/)
-   [R](https://docs.openml.org/r/)
-   [APIv2](https://docs.openml.org/apiv2/)

-   [Get Started](https://docs.openml.org/intro/)
    
    -   [OpenML in 10 minutes](https://docs.openml.org/notebooks/getting_started/)
    -   [Concepts](https://docs.openml.org/concepts/)
        
        -   [Data](https://docs.openml.org/concepts/data/)
        -   [Tasks](https://docs.openml.org/concepts/tasks/)
        -   [Flows](https://docs.openml.org/concepts/flows/)
        -   [Runs](https://docs.openml.org/concepts/runs/)
        -   [Collections & Benchmarks](https://docs.openml.org/concepts/benchmarking/)
        -   [Tagging](https://docs.openml.org/concepts/tagging/)
        -   [Authentication](https://docs.openml.org/concepts/authentication/)
        -   [Sharing](https://docs.openml.org/concepts/sharing/)
        
    -   [Showcase](https://docs.openml.org/intro/showcase/)
    -   [Governance](https://docs.openml.org/intro/Governance/)
    -   [Terms](https://docs.openml.org/intro/terms/)
    

Table of contents

-   [Automated reproducible evaluations](https://docs.openml.org/concepts/runs/#automated-reproducible-evaluations)
-   [Online organization](https://docs.openml.org/concepts/runs/#online-organization)
-   [Independent (server-side) evaluation](https://docs.openml.org/concepts/runs/#independent-server-side-evaluation)

# Runs[¶](https://docs.openml.org/concepts/runs/#runs "Permanent link")

## Automated reproducible evaluations[¶](https://docs.openml.org/concepts/runs/#automated-reproducible-evaluations "Permanent link")

Runs are experiments (benchmarks) evaluating a specific flows on a specific task. As shown above, they are typically submitted automatically by machine learning libraries through the OpenML [APIs](https://www.openml.org/apis)), including lots of automatically extracted meta-data, to create reproducible experiments. With a few for-loops you can easily run (and share) millions of experiments.

## Online organization[¶](https://docs.openml.org/concepts/runs/#online-organization "Permanent link")

OpenML organizes all runs online, linked to the underlying data, flows, parameter settings, people, and other details. See the many examples above, where every dot in the scatterplots is a single OpenML run.

## Independent (server-side) evaluation[¶](https://docs.openml.org/concepts/runs/#independent-server-side-evaluation "Permanent link")

OpenML runs include all information needed to independently evaluate models. For most tasks, this includes all predictions, for all train-test splits, for all instances in the dataset, including all class confidences. When a run is uploaded, OpenML automatically evaluates every run using a wide array of evaluation metrics. This makes them directly comparable with all other runs shared on OpenML. For completeness, OpenML will also upload locally computed evaluation metrics and runtimes.

New metrics can also be added to OpenML's evaluation engine, and computed for all runs afterwards. Or, you can download OpenML runs and analyse the results any way you like.

Note

Please note that while OpenML tries to maximise reproducibility, exactly reproducing all results may not always be possible because of changes in numeric libraries, operating systems, and hardware.

May 7, 2024 May 7, 2024

[

Previous

Flows

](https://docs.openml.org/concepts/flows/)[

Next

Collections & Benchmarks

](https://docs.openml.org/concepts/benchmarking/)
