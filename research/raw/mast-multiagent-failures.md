# Why Do Multi-Agent LLM Systems Fail?

<https://arxiv.org/html/2503.13657>

arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) 

 [Back to arXiv](https://arxiv.org/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](https://arxiv.org/html/2503.13657# "Report an Issue") [Back to Abstract](https://arxiv.org/abs/2503.13657v3 "Back to abstract page") [Download PDF](https://arxiv.org/pdf/2503.13657v3 "Download PDF")

1.  [Abstract](https://arxiv.org/html/2503.13657#abstract1 "In Why Do Multi-Agent LLM Systems Fail?")
2.  [1 Introduction](https://arxiv.org/html/2503.13657#S1 "In Why Do Multi-Agent LLM Systems Fail?")
3.  [2 Related Work](https://arxiv.org/html/2503.13657#S2 "In Why Do Multi-Agent LLM Systems Fail?")
4.  [3 The Multi-Agent Systems Dataset](https://arxiv.org/html/2503.13657#S3 "In Why Do Multi-Agent LLM Systems Fail?")
5.  [4 The Multi-Agent System Failure Taxonomy](https://arxiv.org/html/2503.13657#S4 "In Why Do Multi-Agent LLM Systems Fail?")
6.  [5 Towards better Multi-Agent LLM Systems](https://arxiv.org/html/2503.13657#S5 "In Why Do Multi-Agent LLM Systems Fail?")
7.  [6 Conclusion](https://arxiv.org/html/2503.13657#S6 "In Why Do Multi-Agent LLM Systems Fail?")
8.  [References](https://arxiv.org/html/2503.13657#bib "In Why Do Multi-Agent LLM Systems Fail?")
9.  [A MAST Failure Categories: Deep Dive](https://arxiv.org/html/2503.13657#A1 "In Why Do Multi-Agent LLM Systems Fail?")
10.  [B Details of Multi-Agent Systems Evaluated](https://arxiv.org/html/2503.13657#A2 "In Why Do Multi-Agent LLM Systems Fail?")
11.  [C MAST Python Library](https://arxiv.org/html/2503.13657#A3 "In Why Do Multi-Agent LLM Systems Fail?")
12.  [D ProgramDev and ProgramDev-v2 Datasets](https://arxiv.org/html/2503.13657#A4 "In Why Do Multi-Agent LLM Systems Fail?")
13.  [E MAS Failure Modes Correlation](https://arxiv.org/html/2503.13657#A5 "In Why Do Multi-Agent LLM Systems Fail?")
14.  [F Understanding Failures: The Impact of Different LLMs and Agent Architectures](https://arxiv.org/html/2503.13657#A6 "In Why Do Multi-Agent LLM Systems Fail?")
15.  [G Approaches and strategies to improve MASs](https://arxiv.org/html/2503.13657#A7 "In Why Do Multi-Agent LLM Systems Fail?")
16.  [H Intervention Case Studies](https://arxiv.org/html/2503.13657#A8 "In Why Do Multi-Agent LLM Systems Fail?")
17.  [I Analysis on Multi-Agent Systems with Open-Source Models](https://arxiv.org/html/2503.13657#A9 "In Why Do Multi-Agent LLM Systems Fail?")
18.  [J Correlation of Failure Modes with Different Statistics](https://arxiv.org/html/2503.13657#A10 "In Why Do Multi-Agent LLM Systems Fail?")
19.  [K LLM Annotator Cost](https://arxiv.org/html/2503.13657#A11 "In Why Do Multi-Agent LLM Systems Fail?")
20.  [L AG2 - MathChat Scenario](https://arxiv.org/html/2503.13657#A12 "In Why Do Multi-Agent LLM Systems Fail?")
21.  [M ChatDev Prompt Interventions](https://arxiv.org/html/2503.13657#A13 "In Why Do Multi-Agent LLM Systems Fail?")
22.  [N Examples of Different Failure Modes](https://arxiv.org/html/2503.13657#A14 "In Why Do Multi-Agent LLM Systems Fail?")

[License: CC BY-NC-ND 4.0](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:2503.13657v3 \[cs.AI\] 26 Oct 2025

# Why Do Multi-Agent LLM Systems Fail?

Mert Cemri Melissa Z. Pan Shuyi Yang Lakshya A Agrawal Bhavya Chopra Rishabh Tiwari Kurt Keutzer Aditya Parameswaran Dan Klein Kannan Ramchandran Matei Zaharia Joseph E. Gonzalez Ion Stoica

###### Abstract

Despite enthusiasm for Multi-Agent LLM Systems (MAS), their performance gains on popular benchmarks are often minimal. This gap highlights a critical need for a principled understanding of why MAS fail. Addressing this question requires systematic identification and analysis of failure patterns. We introduce MAST-Data, a comprehensive dataset of 1600+ annotated traces collected across 7 popular MAS frameworks. MAST-Data is the first multi-agent system dataset to outline the failure dynamics in MAS for guiding the development of better future systems. To enable systematic classification of failures for MAST-Data, we build the first Multi-Agent System Failure Taxonomy (MAST). We develop MAST through rigorous analysis of 150 traces, guided closely by expert human annotators and validated by high inter-annotator agreement (κ\=0.88). This process identifies 14 unique modes, clustered into 3 categories: (i) system design issues, (ii) inter-agent misalignment, and (iii) task verification. To enable scalable annotation, we develop an LLM-as-a-Judge pipeline with high agreement with human annotations. We leverage MAST and MAST-Data to analyze failure patterns across models (GPT4, Claude 3, Qwen2.5, CodeLlama) and tasks (coding, math, general agent), demonstrating opportunities for improvement through better MAS design. Our analysis provides insights revealing that identified failures require more sophisticated solutions, highlighting a clear roadmap for future research. We publicly release our comprehensive dataset (MAST-Data), the MAST, and our LLM annotator to facilitate widespread research and development in MAS.12

“Happy families are all alike; each unhappy family is unhappy in its own way.” ([Tolstoy \[1\]](https://arxiv.org/html/2503.13657#bib.bib1))“Successful systems all work alike; each failing system has its own problems.” (Berkeley’25)

Figure 1: MAST: A Taxonomy of MAS Failure Modes. The inter-agent conversation stages indicate when a failure typically occurs within the end-to-end MAS execution pipeline. A failure mode spanning multiple stages signifies that the underlying issue can manifest or have implications across these different phases of operation. The percentages shown represent the prevalence of each failure mode and category as observed in our analysis of 1642 MAS execution traces. Detailed definitions for each failure mode and illustrative examples are available in Appendix [A](https://arxiv.org/html/2503.13657#A1 "Appendix A MAST Failure Categories: Deep Dive ‣ Why Do Multi-Agent LLM Systems Fail?").

## 1 Introduction

Recently, Large Language Model (LLM) based agentic systems have gained significant attention in the AI community \[[2](https://arxiv.org/html/2503.13657#bib.bib2), [3](https://arxiv.org/html/2503.13657#bib.bib3), [4](https://arxiv.org/html/2503.13657#bib.bib4)\]. Building on this characteristic, multi-agent systems are increasingly explored in various domains, such as software engineering, drug discoveries, scientific simulations, and general-purpose agents \[[5](https://arxiv.org/html/2503.13657#bib.bib5), [6](https://arxiv.org/html/2503.13657#bib.bib6), [7](https://arxiv.org/html/2503.13657#bib.bib7), [8](https://arxiv.org/html/2503.13657#bib.bib8), [9](https://arxiv.org/html/2503.13657#bib.bib9), [10](https://arxiv.org/html/2503.13657#bib.bib10), [11](https://arxiv.org/html/2503.13657#bib.bib11)\]. In this study, we define an LLM-based agent as an artificial entity with prompt specifications (initial state), conversation trace (state), and ability to interact with the environments such as tool usage (action). A multi-agent system (MAS) is then defined as a collection of agents designed to interact through orchestration, enabling collective intelligence. MAS are structured to coordinate efforts, enabling task decomposition, performance parallelization, context isolation, specialized model ensembling, and diverse reasoning discussions \[[12](https://arxiv.org/html/2503.13657#bib.bib12), [13](https://arxiv.org/html/2503.13657#bib.bib13), [14](https://arxiv.org/html/2503.13657#bib.bib14), [15](https://arxiv.org/html/2503.13657#bib.bib15), [16](https://arxiv.org/html/2503.13657#bib.bib16), [17](https://arxiv.org/html/2503.13657#bib.bib17)\].

Despite the increasing adoption of MAS, their performance gains often remain minimal compared to single-agent frameworks \[[18](https://arxiv.org/html/2503.13657#bib.bib18)\] or simple baselines like best-of-N sampling \[[19](https://arxiv.org/html/2503.13657#bib.bib19)\]. Our empirical analysis reveals 41% to 86.7% failure rate on 7 state-of-the-art (SOTA) open-source MAS detailed in Figure [5](https://arxiv.org/html/2503.13657#A2.F5 "Figure 5 ‣ Appendix B Details of Multi-Agent Systems Evaluated ‣ Why Do Multi-Agent LLM Systems Fail?") (Appendix [B](https://arxiv.org/html/2503.13657#A2 "Appendix B Details of Multi-Agent Systems Evaluated ‣ Why Do Multi-Agent LLM Systems Fail?")). Furthermore, there is no clear consensus on how to build robust and reliable MAS. This motivates the fundamental question we address: Why do MAS fail?

To address this question and systematically understand MAS failures, we introduce MAST-Data, a comprehensive, high-quality collection of 1642 annotated execution traces. We define failures as instances where the MAS does not achieve its intended task objectives. As shown in Table [1](https://arxiv.org/html/2503.13657#S1.T1 "Table 1 ‣ 1 Introduction ‣ Why Do Multi-Agent LLM Systems Fail?"), we collect traces from 7 popular MAS frameworks run with two main model families (GPT-4 series and Claude series), covering tasks such as coding, math problem-solving, and general agent functionalities. Alongside MAST-Data, we also release MAST-Data-human, a smaller dataset featuring 21 traces annotated by three human experts each during our inter-annotator agreement studies. We create MAST-Data to outline failure dynamics in MAS and to guide the development of better future systems.

Systematically annotating failures in diverse MAS for a large-scale dataset like MAST-Data presents challenges unique to MAS: the difficulty in verifying ground truth for root cause detection and the absence of standardized failure definitions. To mitigate these challenges in creating MAST-Data, we first develop the Multi-Agent System Failure Taxonomy (MAST), illustrated in Figure [1](https://arxiv.org/html/2503.13657#S0.F1 "Figure 1 ‣ Why Do Multi-Agent LLM Systems Fail?"). We build MAST using Grounded Theory \[[20](https://arxiv.org/html/2503.13657#bib.bib20)\] from a close analysis of over 150 MAS execution traces (each averaging over 15,000 lines of text). This analysis spans a subset of five open-source MAS frameworks and involves six expert human annotators. To ensure generalizable definitions in MAST for labeling MAST-Data, three annotators independently and iteratively labeled a total of 15 traces until achieving high inter-annotator agreement (κ = 0.88). This comprehensive analysis results in 14 distinct failure modes, clustered into 3 categories. While MAST serves as a foundational first step towards unifying the understanding of MAS failures, we do not claim it covers every potential failure pattern. To enable scalable annotation for the full MAST-Data, we then develop an LLM-as-a-judge pipeline (which we term the LLM annotator) \[[21](https://arxiv.org/html/2503.13657#bib.bib21)\] using OpenAI’s o1 model. We calibrate the LLM annotator to achieve high agreement with human expert annotations (κ = 0.77), and additionally validated applicability on two additional unseen MAS and benchmarks (κ = 0.79).

To demonstrate MAST’s practical usage, our case studies (Appendix [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")) highlight its role in guiding MAS development, and in Section [C](https://arxiv.org/html/2503.13657#A3 "Appendix C MAST Python Library ‣ Why Do Multi-Agent LLM Systems Fail?") we describe how to use the MAST easily as a python library using `pip install agentdash`. For example, the CPO agent in ChatDev can exhibit ‘Failure Mode 1.2 - Disobey Role Specification’ by terminating conversation without the CEO agent’s consensus. We demonstrate that a straightforward system workflow adjustment ensuring the CEO had the final say contributed to a +9.4% increase in overall task success rate. While such MAST\-guided interventions demonstrate improvements, achieving robust MAS reliability often requires more than isolated fixes, pointing towards the need for more complex solutions and fundamental MAS redesigns.

Table 1: MAST-Data configuration details. HE: Human Evaluated (Task completions rates are checked by humans), HA: Human Annotated (Failure modes are annotated by humans), LA: LLM Annotated (Failure modes are annotated by LLM-as-a-Judge).

<table id="S1.T1.6" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="S1.T1.6.1" class="ltx_tr"><td id="S1.T1.6.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.1.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.1.1.1.1" class="ltx_p"><span id="S1.T1.6.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MAS</span></span></span></td><td id="S1.T1.6.1.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.1.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.1.2.1.1" class="ltx_p"><span id="S1.T1.6.1.2.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Benchmark</span></span></span></td><td id="S1.T1.6.1.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.1.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.1.3.1.1" class="ltx_p"><span id="S1.T1.6.1.3.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">LLM</span></span></span></td><td id="S1.T1.6.1.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.1.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.1.4.1.1" class="ltx_p"><span id="S1.T1.6.1.4.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Annotation</span></span></span></td><td id="S1.T1.6.1.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.1.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.1.5.1.1" class="ltx_p"><span id="S1.T1.6.1.5.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Trace #</span></span></span></td></tr><tr id="S1.T1.6.2" class="ltx_tr"><td id="S1.T1.6.2.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.2.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.2.1.1.1" class="ltx_p"><span id="S1.T1.6.2.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span></span></span></td><td id="S1.T1.6.2.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.2.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.2.2.1.1" class="ltx_p"><span id="S1.T1.6.2.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev</span></span></span></td><td id="S1.T1.6.2.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.2.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.2.3.1.1" class="ltx_p"><span id="S1.T1.6.2.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.2.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.2.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.2.4.1.1" class="ltx_p"><span id="S1.T1.6.2.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.2.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.2.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.2.5.1.1" class="ltx_p"><span id="S1.T1.6.2.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.3" class="ltx_tr"><td id="S1.T1.6.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.3.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.3.1.1.1" class="ltx_p"><span id="S1.T1.6.3.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="S1.T1.6.3.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.3.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.3.2.1.1" class="ltx_p"><span id="S1.T1.6.3.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev</span></span></span></td><td id="S1.T1.6.3.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.3.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.3.3.1.1" class="ltx_p"><span id="S1.T1.6.3.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.3.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.3.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.3.4.1.1" class="ltx_p"><span id="S1.T1.6.3.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.3.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.3.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.3.5.1.1" class="ltx_p"><span id="S1.T1.6.3.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.4" class="ltx_tr"><td id="S1.T1.6.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.4.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.4.1.1.1" class="ltx_p"><span id="S1.T1.6.4.1.1.1.1" class="ltx_text" style="font-size:90%;">HyperAgent</span></span></span></td><td id="S1.T1.6.4.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.4.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.4.2.1.1" class="ltx_p"><span id="S1.T1.6.4.2.1.1.1" class="ltx_text" style="font-size:90%;">SWE-Bench Lite</span></span></span></td><td id="S1.T1.6.4.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.4.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.4.3.1.1" class="ltx_p"><span id="S1.T1.6.4.3.1.1.1" class="ltx_text" style="font-size:90%;">Claude-3.7-Sonnet</span></span></span></td><td id="S1.T1.6.4.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.4.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.4.4.1.1" class="ltx_p"><span id="S1.T1.6.4.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.4.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.4.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.4.5.1.1" class="ltx_p"><span id="S1.T1.6.4.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.5" class="ltx_tr"><td id="S1.T1.6.5.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.5.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.5.1.1.1" class="ltx_p"><span id="S1.T1.6.5.1.1.1.1" class="ltx_text" style="font-size:90%;">AppWorld</span></span></span></td><td id="S1.T1.6.5.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.5.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.5.2.1.1" class="ltx_p"><span id="S1.T1.6.5.2.1.1.1" class="ltx_text" style="font-size:90%;">Test-C</span></span></span></td><td id="S1.T1.6.5.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.5.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.5.3.1.1" class="ltx_p"><span id="S1.T1.6.5.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.5.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.5.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.5.4.1.1" class="ltx_p"><span id="S1.T1.6.5.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.5.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.5.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.5.5.1.1" class="ltx_p"><span id="S1.T1.6.5.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.6" class="ltx_tr"><td id="S1.T1.6.6.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.6.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.6.1.1.1" class="ltx_p"><span id="S1.T1.6.6.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 (MathChat)</span></span></span></td><td id="S1.T1.6.6.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.6.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.6.2.1.1" class="ltx_p"><span id="S1.T1.6.6.2.1.1.1" class="ltx_text" style="font-size:90%;">GSM-Plus</span></span></span></td><td id="S1.T1.6.6.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.6.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.6.3.1.1" class="ltx_p"><span id="S1.T1.6.6.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4</span></span></span></td><td id="S1.T1.6.6.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.6.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.6.4.1.1" class="ltx_p"><span id="S1.T1.6.6.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.6.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.6.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.6.5.1.1" class="ltx_p"><span id="S1.T1.6.6.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.7" class="ltx_tr"><td id="S1.T1.6.7.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.7.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.7.1.1.1" class="ltx_p"><span id="S1.T1.6.7.1.1.1.1" class="ltx_text" style="font-size:90%;">Magentic-One</span></span></span></td><td id="S1.T1.6.7.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.7.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.7.2.1.1" class="ltx_p"><span id="S1.T1.6.7.2.1.1.1" class="ltx_text" style="font-size:90%;">GAIA</span></span></span></td><td id="S1.T1.6.7.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.7.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.7.3.1.1" class="ltx_p"><span id="S1.T1.6.7.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.7.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.7.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.7.4.1.1" class="ltx_p"><span id="S1.T1.6.7.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.7.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.7.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.7.5.1.1" class="ltx_p"><span id="S1.T1.6.7.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.8" class="ltx_tr"><td id="S1.T1.6.8.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.8.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.8.1.1.1" class="ltx_p"><span id="S1.T1.6.8.1.1.1.1" class="ltx_text" style="font-size:90%;">OpenManus</span></span></span></td><td id="S1.T1.6.8.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.8.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.8.2.1.1" class="ltx_p"><span id="S1.T1.6.8.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev</span></span></span></td><td id="S1.T1.6.8.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.8.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.8.3.1.1" class="ltx_p"><span id="S1.T1.6.8.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.8.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.8.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.8.4.1.1" class="ltx_p"><span id="S1.T1.6.8.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, HA, LA</span></span></span></td><td id="S1.T1.6.8.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.8.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.8.5.1.1" class="ltx_p"><span id="S1.T1.6.8.5.1.1.1" class="ltx_text" style="font-size:90%;">30</span></span></span></td></tr><tr id="S1.T1.6.9" class="ltx_tr"><td id="S1.T1.6.9.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.9.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.9.1.1.1" class="ltx_p"><span id="S1.T1.6.9.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span></span></span></td><td id="S1.T1.6.9.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.9.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.9.2.1.1" class="ltx_p"><span id="S1.T1.6.9.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.9.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.9.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.9.3.1.1" class="ltx_p"><span id="S1.T1.6.9.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.9.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.9.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.9.4.1.1" class="ltx_p"><span id="S1.T1.6.9.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.9.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.9.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.9.5.1.1" class="ltx_p"><span id="S1.T1.6.9.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.10" class="ltx_tr"><td id="S1.T1.6.10.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.10.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.10.1.1.1" class="ltx_p"><span id="S1.T1.6.10.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="S1.T1.6.10.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.10.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.10.2.1.1" class="ltx_p"><span id="S1.T1.6.10.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.10.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.10.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.10.3.1.1" class="ltx_p"><span id="S1.T1.6.10.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.10.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.10.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.10.4.1.1" class="ltx_p"><span id="S1.T1.6.10.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.10.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.10.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.10.5.1.1" class="ltx_p"><span id="S1.T1.6.10.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.11" class="ltx_tr"><td id="S1.T1.6.11.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.11.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.11.1.1.1" class="ltx_p"><span id="S1.T1.6.11.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="S1.T1.6.11.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.11.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.11.2.1.1" class="ltx_p"><span id="S1.T1.6.11.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.11.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.11.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.11.3.1.1" class="ltx_p"><span id="S1.T1.6.11.3.1.1.1" class="ltx_text" style="font-size:90%;">Claude-3.7-Sonnet</span></span></span></td><td id="S1.T1.6.11.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.11.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.11.4.1.1" class="ltx_p"><span id="S1.T1.6.11.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.11.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.11.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.11.5.1.1" class="ltx_p"><span id="S1.T1.6.11.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.12" class="ltx_tr"><td id="S1.T1.6.12.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.12.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.12.1.1.1" class="ltx_p"><span id="S1.T1.6.12.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span></span></span></td><td id="S1.T1.6.12.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.12.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.12.2.1.1" class="ltx_p"><span id="S1.T1.6.12.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.12.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.12.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.12.3.1.1" class="ltx_p"><span id="S1.T1.6.12.3.1.1.1" class="ltx_text" style="font-size:90%;">Qwen2.5-Coder-32B-Instruct</span></span></span></td><td id="S1.T1.6.12.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.12.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.12.4.1.1" class="ltx_p"><span id="S1.T1.6.12.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.12.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.12.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.12.5.1.1" class="ltx_p"><span id="S1.T1.6.12.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.13" class="ltx_tr"><td id="S1.T1.6.13.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.13.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.13.1.1.1" class="ltx_p"><span id="S1.T1.6.13.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="S1.T1.6.13.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.13.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.13.2.1.1" class="ltx_p"><span id="S1.T1.6.13.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.13.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.13.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.13.3.1.1" class="ltx_p"><span id="S1.T1.6.13.3.1.1.1" class="ltx_text" style="font-size:90%;">Qwen2.5-Coder-32B-Instruct</span></span></span></td><td id="S1.T1.6.13.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.13.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.13.4.1.1" class="ltx_p"><span id="S1.T1.6.13.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.13.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.13.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.13.5.1.1" class="ltx_p"><span id="S1.T1.6.13.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.14" class="ltx_tr"><td id="S1.T1.6.14.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.14.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.14.1.1.1" class="ltx_p"><span id="S1.T1.6.14.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span></span></span></td><td id="S1.T1.6.14.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.14.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.14.2.1.1" class="ltx_p"><span id="S1.T1.6.14.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.14.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.14.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.14.3.1.1" class="ltx_p"><span id="S1.T1.6.14.3.1.1.1" class="ltx_text" style="font-size:90%;">CodeLlama-7b-Instruct-hf</span></span></span></td><td id="S1.T1.6.14.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.14.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.14.4.1.1" class="ltx_p"><span id="S1.T1.6.14.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.14.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.14.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.14.5.1.1" class="ltx_p"><span id="S1.T1.6.14.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.15" class="ltx_tr"><td id="S1.T1.6.15.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.15.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.15.1.1.1" class="ltx_p"><span id="S1.T1.6.15.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="S1.T1.6.15.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.15.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.15.2.1.1" class="ltx_p"><span id="S1.T1.6.15.2.1.1.1" class="ltx_text" style="font-size:90%;">ProgramDev-v2</span></span></span></td><td id="S1.T1.6.15.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.15.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.15.3.1.1" class="ltx_p"><span id="S1.T1.6.15.3.1.1.1" class="ltx_text" style="font-size:90%;">CodeLlama-7b-Instruct-hf</span></span></span></td><td id="S1.T1.6.15.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.15.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.15.4.1.1" class="ltx_p"><span id="S1.T1.6.15.4.1.1.1" class="ltx_text" style="font-size:90%;">LA</span></span></span></td><td id="S1.T1.6.15.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.15.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.15.5.1.1" class="ltx_p"><span id="S1.T1.6.15.5.1.1.1" class="ltx_text" style="font-size:90%;">100</span></span></span></td></tr><tr id="S1.T1.6.16" class="ltx_tr"><td id="S1.T1.6.16.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.16.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.16.1.1.1" class="ltx_p"><span id="S1.T1.6.16.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 (MathChat)</span></span></span></td><td id="S1.T1.6.16.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.16.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.16.2.1.1" class="ltx_p"><span id="S1.T1.6.16.2.1.1.1" class="ltx_text" style="font-size:90%;">OlympiadBench</span></span></span></td><td id="S1.T1.6.16.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.16.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.16.3.1.1" class="ltx_p"><span id="S1.T1.6.16.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.16.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.16.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.16.4.1.1" class="ltx_p"><span id="S1.T1.6.16.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, LA</span></span></span></td><td id="S1.T1.6.16.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.16.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.16.5.1.1" class="ltx_p"><span id="S1.T1.6.16.5.1.1.1" class="ltx_text" style="font-size:90%;">206</span></span></span></td></tr><tr id="S1.T1.6.17" class="ltx_tr"><td id="S1.T1.6.17.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.17.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.17.1.1.1" class="ltx_p"><span id="S1.T1.6.17.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 (MathChat)</span></span></span></td><td id="S1.T1.6.17.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.17.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.17.2.1.1" class="ltx_p"><span id="S1.T1.6.17.2.1.1.1" class="ltx_text" style="font-size:90%;">GSMPlus</span></span></span></td><td id="S1.T1.6.17.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.17.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.17.3.1.1" class="ltx_p"><span id="S1.T1.6.17.3.1.1.1" class="ltx_text" style="font-size:90%;">Claude-3.7-Sonnet</span></span></span></td><td id="S1.T1.6.17.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.17.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.17.4.1.1" class="ltx_p"><span id="S1.T1.6.17.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, LA</span></span></span></td><td id="S1.T1.6.17.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.17.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.17.5.1.1" class="ltx_p"><span id="S1.T1.6.17.5.1.1.1" class="ltx_text" style="font-size:90%;">193</span></span></span></td></tr><tr id="S1.T1.6.18" class="ltx_tr"><td id="S1.T1.6.18.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.18.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.18.1.1.1" class="ltx_p"><span id="S1.T1.6.18.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 (MathChat)</span></span></span></td><td id="S1.T1.6.18.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.18.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.18.2.1.1" class="ltx_p"><span id="S1.T1.6.18.2.1.1.1" class="ltx_text" style="font-size:90%;">MMLU</span></span></span></td><td id="S1.T1.6.18.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.18.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.18.3.1.1" class="ltx_p"><span id="S1.T1.6.18.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o-mini</span></span></span></td><td id="S1.T1.6.18.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.18.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.18.4.1.1" class="ltx_p"><span id="S1.T1.6.18.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, LA</span></span></span></td><td id="S1.T1.6.18.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.18.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.18.5.1.1" class="ltx_p"><span id="S1.T1.6.18.5.1.1.1" class="ltx_text" style="font-size:90%;">168</span></span></span></td></tr><tr id="S1.T1.6.19" class="ltx_tr"><td id="S1.T1.6.19.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.19.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.19.1.1.1" class="ltx_p"><span id="S1.T1.6.19.1.1.1.1" class="ltx_text" style="font-size:90%;">Magentic-One</span></span></span></td><td id="S1.T1.6.19.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.19.2.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="S1.T1.6.19.2.1.1" class="ltx_p"><span id="S1.T1.6.19.2.1.1.1" class="ltx_text" style="font-size:90%;">GAIA</span></span></span></td><td id="S1.T1.6.19.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.19.3.1" class="ltx_inline-block ltx_align_top" style="width:113.8pt;"><span id="S1.T1.6.19.3.1.1" class="ltx_p"><span id="S1.T1.6.19.3.1.1.1" class="ltx_text" style="font-size:90%;">GPT-4o</span></span></span></td><td id="S1.T1.6.19.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.19.4.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="S1.T1.6.19.4.1.1" class="ltx_p"><span id="S1.T1.6.19.4.1.1.1" class="ltx_text" style="font-size:90%;">HE, LA</span></span></span></td><td id="S1.T1.6.19.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.0pt;"><span id="S1.T1.6.19.5.1" class="ltx_inline-block ltx_align_top" style="width:28.5pt;"><span id="S1.T1.6.19.5.1.1" class="ltx_p"><span id="S1.T1.6.19.5.1.1.1" class="ltx_text" style="font-size:90%;">165</span></span></span></td></tr></tbody></table>

These findings suggest MAST reflects fundamental design challenges inherent in current MAS, not just artifacts of specific MAS implementation. By systematically defining failures, MAST serves as a framework to guide failure diagnosis and opens concrete research problems for the community. We have released our traces and annotations and open-sourced the LLM annotator pipeline to foster research in the design of more robust and reliable MAS.

The contributions of this paper are as follows:

-   •
    
    We introduce and open-source MAST-Data, the first large-scale MAS failure dataset with consistent annotations from 7 MAS and four model families. And MAST-Data-human, a detailed inter-annotator study results with human labels. Together serve to facilitate research into MAS failures.
    
-   •
    
    We introduce MAST, the first empirically grounded taxonomy of MAS failures, providing a structured framework for defining, understanding and annotating failures.
    
-   •
    
    We develop a scalable LLM-as-a-judge annotation pipeline integrated with MAST for efficiently annotating MAST-Data and enabling analysis of MAS performance, diagnosis of failure modes, and understanding of failure breakdowns.
    
-   •
    
    We demonstrate through case studies that failures identified by MAST often stem from system design issues, not just LLM limitations or simple prompt following, and require more than superficial fixes, thereby highlighting the need for structural MAS redesigns.
    

## 2 Related Work

### 2.1 Challenges in Agentic Systems

The promising capabilities of agentic systems have inspired research into solving specific challenges. For instance, Agent Workflow Memory \[[22](https://arxiv.org/html/2503.13657#bib.bib22)\] addresses long-horizon web navigation by introducing workflow memory. DSPy \[[23](https://arxiv.org/html/2503.13657#bib.bib23)\] tackles issues in programming agentic flows, while StateFlow \[[24](https://arxiv.org/html/2503.13657#bib.bib24)\] focuses on state control within agentic workflows to improve task-solving capabilities. Several surveys also highlight challenges and potential risks specifically within MAS \[[25](https://arxiv.org/html/2503.13657#bib.bib25), [26](https://arxiv.org/html/2503.13657#bib.bib26)\]. While these works meaningfully contribute towards understanding specific issues or providing high-level overviews, they do not offer a fine-grained, empirically grounded taxonomy of why MAS fail across diverse systems and tasks. Numerous benchmarks also exist to evaluate agentic systems \[[27](https://arxiv.org/html/2503.13657#bib.bib27), [28](https://arxiv.org/html/2503.13657#bib.bib28), [29](https://arxiv.org/html/2503.13657#bib.bib29), [30](https://arxiv.org/html/2503.13657#bib.bib30), [31](https://arxiv.org/html/2503.13657#bib.bib31), [32](https://arxiv.org/html/2503.13657#bib.bib32)\]. These evaluations are crucial but primarily facilitate a top-down perspective, focusing on aggregate performance or high-level objectives like trustworthiness and security \[[33](https://arxiv.org/html/2503.13657#bib.bib33), [34](https://arxiv.org/html/2503.13657#bib.bib34)\]. Our work complements these efforts by providing a bottom-up analysis focused on identifying specific failure modes in MAS.

### 2.2 Design Principles for Agentic Systems

Several works highlight challenges in building robust agentic systems and suggest design principles, often focused on single-agent settings. For instance, Anthropic’s blog post emphasizes modular components and avoiding overly complex frameworks \[[35](https://arxiv.org/html/2503.13657#bib.bib35)\]. Similarly, [Kapoor et al. \[19\]](https://arxiv.org/html/2503.13657#bib.bib19) demonstrates how complexity can hinder practical adoption. Our work extends these insights to the multi-agent context. By systematically collecting and analyzing a large corpus of MAS failure instances within MAST-Data, and by developing MAST, we provide not only a structured understanding of why MAS fail but also empirical data from MAST-Data to support the development and validation of more robust design principles for MAS. This aligns with the call for clearer specifications and design principles \[[36](https://arxiv.org/html/2503.13657#bib.bib36)\].

### 2.3 Related Datasets and Taxonomy

Despite the growing interest in LLM agents, dedicated research systematically characterizing their failure modes remains limited, particularly for MAS. While [Bansal et al. \[37\]](https://arxiv.org/html/2503.13657#bib.bib37) catalogs challenges in human-agent interaction, our contribution focuses specifically on failures within autonomous MAS execution. Other related work includes taxonomies for evaluating multi-turn LLM conversations \[[38](https://arxiv.org/html/2503.13657#bib.bib38)\] or specific capabilities like code generation \[[39](https://arxiv.org/html/2503.13657#bib.bib39)\]. These differ significantly from our goal of developing a generalizable failure taxonomy for multi-agent interactions and coordination.

Further related efforts aim to improve MAS through different approaches. AgentEval \[[40](https://arxiv.org/html/2503.13657#bib.bib40)\] proposes a framework using LLM agents to define and quantify multi-dimensional evaluation criteria reflecting task utility for end-users. AGDebugger \[[41](https://arxiv.org/html/2503.13657#bib.bib41)\] introduces an interactive tool enabling developers to debug and steer agent teams by inspecting and editing message histories. And currentwork by [Zhang et al. \[42\]](https://arxiv.org/html/2503.13657#bib.bib42) present the Who&When dataset and MAS debugger, which focuses on summarizing failures for specific task items by attributing them to particular agents and error steps.

Thus, MAST-Data and MAST represent, to our knowledge, the first empirically derived, comprehensive dataset and taxonomy focused specifically on MAS failures focus on failure patterns. Identifying these patterns highlights the need for continued research into robust evaluation metrics and mitigation strategies tailored for the unique challenges of MAS.

## 3 The Multi-Agent Systems Dataset

Figure 2: Methodological workflow for constructing the MAST-Data dataset, involving the empirical identification of failure modes, the development of MAST, iterative refinement through inter-annotator agreement studies (κ\=0.88), and the creation of a scalable LLM annotation pipeline. This figure highlights our systematic approach to creating a comprehensive dataset for studying MAS failures.

To facilitate a principled understanding of why MAS fail and to guide the development of more reliable future systems, we introduce MAST-Data, the Multi-Agent System Failure Dataset. MAST-Data is a comprehensive, empirically grounded dataset comprising 1642 annotated execution traces collected from 7 popular MAS frameworks, covering domains of coding, math, and generic tasks.

Constructing such a dataset, however, presents distinct challenges. First, unlike in traditional software where failures often have clearly identifiable root causes, failures in MAS are frequently complex. They involve convoluted agent interactions and the compounding effects of individual model behaviors and overall system design. Therefore, pinpointing the precise nature and origin of a failure in MAS requires more than simple error detection; it necessitates understanding the system’s dynamics. Second, the lack of a standardized failure framework with clear definitions makes identifying and classifying MAS failures across different systems inconsistent, which complicates annotation and cross-system analysis.

To address these challenges, we develop a rigorous, principled methodology to construct MAST-Data. In this section, we detail our approach, which centers on building the first empirical MAS failure taxonomy, MAST, and a scalable annotation pipeline for systematic and comprehensive data collection. Figure [2](https://arxiv.org/html/2503.13657#S3.F2 "Figure 2 ‣ 3 The Multi-Agent Systems Dataset ‣ Why Do Multi-Agent LLM Systems Fail?") summarizes our methodological workflow.

### 3.1 Data Collection with Grounded Theory Analysis

To uncover a comprehensive set of failure patterns that are both diverse and generalizable to standardize failure labels which we detail further in Section [3.2](https://arxiv.org/html/2503.13657#S3.SS2 "3.2 Standardizing Failure Labels via Inter-Annotator Agreement ‣ 3 The Multi-Agent Systems Dataset ‣ Why Do Multi-Agent LLM Systems Fail?"), we first collect 150 traces from five MAS frameworks, which are closely examined by six human experts. Our goal at this stage is to identify as many distinct failure modes as possible, ensuring these observed patterns are not merely artifacts of a single system but can likely apply more broadly. To achieve this without predefined hypotheses, we adopt the Grounded Theory (GT) approach \[[20](https://arxiv.org/html/2503.13657#bib.bib20)\]. This qualitative research method allows failure modes to emerge organically from empirical data.

For this initial data collection, we use _theoretical sampling_ \[[43](https://arxiv.org/html/2503.13657#bib.bib43)\] to ensure robust coverage across different system objectives and interaction patterns. This method guides our selection of the five MAS frameworks (HyperAgent, AppWorld, AG2, ChatDev, and MetaGPT) and two task categories (programming and math problem-solving). We then iteratively analyze these traces using core GT techniques: _open coding_ \[[44](https://arxiv.org/html/2503.13657#bib.bib44)\] to label trace data with observed failure behaviors; _constant comparative analysis_ to refine our understanding of these failure behaviors and their recurrence across systems; _memoing_ to document insights; and _theorizing_ to structure these findings into an initial set of failure modes with their definitions. This iterative analysis continues until we reach _theoretical saturation_, where further data analysis does not yield new failure mode insights. This initial process requires significant human effort, over 20 hours of annotation per expert for these 150 traces.

### 3.2 Standardizing Failure Labels via Inter-Annotator Agreement

To make the failure observations from our GT analysis useful for creating consistent labels in MAST-Data, we recognize the critical need for standardized definitions that apply uniformly across different MAS. To address this, we develop the failure taxonomy - MAST. MAST serves as a foundational first step towards a common understanding of MAS failures by providing clear, empirically grounded failure observation labels. We provide a detailed description and analysis of MAST in Section [4](https://arxiv.org/html/2503.13657#S4 "4 The Multi-Agent System Failure Taxonomy ‣ Why Do Multi-Agent LLM Systems Fail?").

To develop a taxonomy that is unambiguous and consistently applicable by different annotators, we rigorously validate and refine MAST definitions through Inter-Annotator Agreement (IAA) studies. This iterative process begins with a preliminary version of MAST derived from our GT findings. In each round of IAA, three expert annotators independently label a subset of five randomly selected traces from our initial 150+ trace collection using MAST. We then facilitate discussions to collectively resolve any disagreements. Based on these discussions, we iteratively refine MAST by adjusting failure mode definitions, adding new modes, or removing and merging existing ones until we achieve high consensus. We conduct three such rounds of IAA, requiring about 10 hours in total solely for resolving disagreements, not including the annotation time itself. We measure agreement using Cohen’s Kappa score, achieving a strong average of κ\=0.88 in the final rounds. This high IAA score signifies that MAST provides a clear and shared understanding of failure modes, crucial for the consistent annotation of MAST-Data. Figure [3](https://arxiv.org/html/2503.13657#S3.F3 "Figure 3 ‣ 3.3 Enabling Scalable Annotation: The LLM-as-a-Judge Pipeline ‣ 3 The Multi-Agent Systems Dataset ‣ Why Do Multi-Agent LLM Systems Fail?") illustrates an example of a trace snippet with a MAST label.

### 3.3 Enabling Scalable Annotation: The LLM-as-a-Judge Pipeline

Manually annotating over 1600 MAS traces with fine-grained failure modes is time-consuming and costly. To enable scalable and automated failure annotation for MAST-Data, we develop an LLM-as-a-Judge pipeline (LLM annotator), building upon our validated MAST. This pipeline prompts an LLM (OpenAI’s o1 model) with an execution trace, the MAST definitions, and few-shot examples from our human-annotated data (details in Appendix [N](https://arxiv.org/html/2503.13657#A14 "Appendix N Examples of Different Failure Modes ‣ Why Do Multi-Agent LLM Systems Fail?")) to classify observed failure modes. We validate the LLM annotator’s reliability against expert human annotations on a held-out set from our IAA studies. The LLM annotator achieves high agreement with human experts (accuracy 94%, Cohen’s Kappa of 0.77; Table [2](https://arxiv.org/html/2503.13657#S3.T2 "Table 2 ‣ 3.3 Enabling Scalable Annotation: The LLM-as-a-Judge Pipeline ‣ 3 The Multi-Agent Systems Dataset ‣ Why Do Multi-Agent LLM Systems Fail?")), confirming its suitability for scaling the annotation process while adhering to MAST definitions.

Table 2: Performance of LLM-as-a-judge pipeline

<table id="S3.T2.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="S3.T2.4.1" class="ltx_tr"><td id="S3.T2.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:46.1pt;"><span id="S3.T2.4.1.1.1.1" class="ltx_p"><span id="S3.T2.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Model</span></span></span></td><td id="S3.T2.4.1.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.2.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.1.2.1.1" class="ltx_p"><span id="S3.T2.4.1.2.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Accuracy</span></span></span></td><td id="S3.T2.4.1.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.3.1" class="ltx_inline-block ltx_align_top" style="width:23.0pt;"><span id="S3.T2.4.1.3.1.1" class="ltx_p"><span id="S3.T2.4.1.3.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Recall</span></span></span></td><td id="S3.T2.4.1.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.4.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.1.4.1.1" class="ltx_p"><span id="S3.T2.4.1.4.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Precision</span></span></span></td><td id="S3.T2.4.1.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.5.1" class="ltx_inline-block ltx_align_top" style="width:15.6pt;"><span id="S3.T2.4.1.5.1.1" class="ltx_p"><span id="S3.T2.4.1.5.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">F1</span></span></span></td><td id="S3.T2.4.1.6" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.1.6.1" class="ltx_inline-block ltx_align_top" style="width:37.8pt;"><span id="S3.T2.4.1.6.1.1" class="ltx_p"><span id="S3.T2.4.1.6.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Cohen’s <math id="S3.T2.m1" class="ltx_Math" alttext="\kappa" display="inline" intent=":literal"><semantics><mi>κ</mi></semantics></math></span></span></span></td></tr><tr id="S3.T2.4.2" class="ltx_tr"><td id="S3.T2.4.2.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.1.1" class="ltx_inline-block ltx_align_top" style="width:46.1pt;"><span id="S3.T2.4.2.1.1.1" class="ltx_p"><span id="S3.T2.4.2.1.1.1.1" class="ltx_text" style="font-size:90%;">o1</span></span></span></td><td id="S3.T2.4.2.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.2.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.2.2.1.1" class="ltx_p"><span id="S3.T2.4.2.2.1.1.1" class="ltx_text" style="font-size:90%;">0.89</span></span></span></td><td id="S3.T2.4.2.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.3.1" class="ltx_inline-block ltx_align_top" style="width:23.0pt;"><span id="S3.T2.4.2.3.1.1" class="ltx_p"><span id="S3.T2.4.2.3.1.1.1" class="ltx_text" style="font-size:90%;">0.62</span></span></span></td><td id="S3.T2.4.2.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.4.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.2.4.1.1" class="ltx_p"><span id="S3.T2.4.2.4.1.1.1" class="ltx_text" style="font-size:90%;">0.68</span></span></span></td><td id="S3.T2.4.2.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.5.1" class="ltx_inline-block ltx_align_top" style="width:15.6pt;"><span id="S3.T2.4.2.5.1.1" class="ltx_p"><span id="S3.T2.4.2.5.1.1.1" class="ltx_text" style="font-size:90%;">0.64</span></span></span></td><td id="S3.T2.4.2.6" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.2.6.1" class="ltx_inline-block ltx_align_top" style="width:37.8pt;"><span id="S3.T2.4.2.6.1.1" class="ltx_p"><span id="S3.T2.4.2.6.1.1.1" class="ltx_text" style="font-size:90%;">0.58</span></span></span></td></tr><tr id="S3.T2.4.3" class="ltx_tr"><td id="S3.T2.4.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:46.1pt;"><span id="S3.T2.4.3.1.1.1" class="ltx_p"><span id="S3.T2.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">o1 (few shot)</span></span></span></td><td id="S3.T2.4.3.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.2.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.3.2.1.1" class="ltx_p"><span id="S3.T2.4.3.2.1.1.1" class="ltx_text" style="font-size:90%;">0.94</span></span></span></td><td id="S3.T2.4.3.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.3.1" class="ltx_inline-block ltx_align_top" style="width:23.0pt;"><span id="S3.T2.4.3.3.1.1" class="ltx_p"><span id="S3.T2.4.3.3.1.1.1" class="ltx_text" style="font-size:90%;">0.77</span></span></span></td><td id="S3.T2.4.3.4" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.4.1" class="ltx_inline-block ltx_align_top" style="width:31.3pt;"><span id="S3.T2.4.3.4.1.1" class="ltx_p"><span id="S3.T2.4.3.4.1.1.1" class="ltx_text" style="font-size:90%;">0.833</span></span></span></td><td id="S3.T2.4.3.5" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.5.1" class="ltx_inline-block ltx_align_top" style="width:15.6pt;"><span id="S3.T2.4.3.5.1.1" class="ltx_p"><span id="S3.T2.4.3.5.1.1.1" class="ltx_text" style="font-size:90%;">0.80</span></span></span></td><td id="S3.T2.4.3.6" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="S3.T2.4.3.6.1" class="ltx_inline-block ltx_align_top" style="width:37.8pt;"><span id="S3.T2.4.3.6.1.1" class="ltx_p"><span id="S3.T2.4.3.6.1.1.1" class="ltx_text" style="font-size:90%;">0.77</span></span></span></td></tr></tbody></table>

Figure 3: Visualization of a trace segment in MAST-Data. This illustrates an agent-to-agent conversation exhibiting Failure Mode 2.4: Information Withholding. The Phone Agent fails to communicate API requirements (username format) to the Supervisor Agent, who also fails to seek clarification, leading to repeated failed logins and task failure.

### 3.4 Constructing the Multi-Agent Dataset

Before large-scale data collection for MAST-Data, we confirm the generalizability of our finalized MAST and the LLM annotator. We evaluate their performance on two new MAS (OpenManus and Magentic-One) with two new benchmarks (MMLU and GAIA, the latter representing a new general-agent task domain for validation) not part of the initial MAST development. An additional human IAA round on these out-of-domain traces using the finalized MAST yields a strong Cohen’s Kappa score of 0.79. This demonstrates MAST’s effectiveness in capturing failures in diverse systems and tasks without further modification, supporting the robustness of our annotation approach for broader application. We further detail the uniqueness of MAST failure modes via a correlation study in Appendix [E](https://arxiv.org/html/2503.13657#A5 "Appendix E MAS Failure Modes Correlation ‣ Why Do Multi-Agent LLM Systems Fail?").

Leveraging our validated MAST and LLM annotator, we expand data collection to construct MAST-Data, comprising 1642 annotated traces from seven popular MAS frameworks (Table [1](https://arxiv.org/html/2503.13657#S1.T1 "Table 1 ‣ 1 Introduction ‣ Why Do Multi-Agent LLM Systems Fail?")). These frameworks include the five from our initial studies, the two from the generalization validation, and Manus \[[45](https://arxiv.org/html/2503.13657#bib.bib45)\] as detailed in Appendix [B](https://arxiv.org/html/2503.13657#A2 "Appendix B Details of Multi-Agent Systems Evaluated ‣ Why Do Multi-Agent LLM Systems Fail?"). These traces cover diverse tasks like coding, math problem-solving, and general agent functionalities. For MAST-Data, our LLM annotator identifies MAST failure modes in each trace and provides a corresponding reason. We also release MAST-Data-human, consisting of all traces annotated by human experts during our IAA studies, where each annotation specifies MAST failure modes with textual justifications. We open-source MAST-Data and MAST-Data-human as resources to analyze MAS failure dynamics and guide robust system design.

## 4 The Multi-Agent System Failure Taxonomy

This section details MAST, a key result of our study and a critical component that guides the creation and analysis of MAST-Data. MAST provides the first empirically grounded, structured framework for defining, understanding, and annotating common failures in MAS. Here, we present its structure, the failure categories it defines, and key insights derived from its development and application.

MAST, illustrated in Figure [1](https://arxiv.org/html/2503.13657#S0.F1 "Figure 1 ‣ Why Do Multi-Agent LLM Systems Fail?"), identifies 14 fine-grained failure modes, which we map to MAS execution stages (Pre-Execution, Execution, and Post-Execution) where their root causes commonly emerge. These modes are organized into 3 overarching categories reflecting the fundamental nature of the observed failures. While we recognize that prior works have noted some individual failure types and we do not claim MAST is exhaustive, it offers precise definitions for a structured approach to understanding why MAS fail. Detailed definitions for each failure mode (FM) are available in Appendix [A](https://arxiv.org/html/2503.13657#A1 "Appendix A MAST Failure Categories: Deep Dive ‣ Why Do Multi-Agent LLM Systems Fail?"), with specific examples in Appendix [N](https://arxiv.org/html/2503.13657#A14 "Appendix N Examples of Different Failure Modes ‣ Why Do Multi-Agent LLM Systems Fail?").

We acknowledge that some MAS failures can stem from fundamental limitations of current LLMs, such as hallucination or instruction following. However, in developing MAST, we focus on identifying failure patterns where improvements in system design, agent coordination, and verification can offer room to improve the reliability of MAS, often independently of or complementary to advancements in the base models themselves. We now discuss each failure category (FC) in MAST and its implications.

Failures in FC1 occur during execution but often reflect flaws in pre-execution design choices regarding system architecture, prompt instructions, or state management. These include failing to follow task requirements (FM-1.1, 11.8%) or agent roles (FM-1.2, 1.5%), step repetitions (FM-1.3, 15.7%), context loss (FM-1.4, 2.80%), or not recognizing task completion (FM-1.5, 12.4%). While FM-1.1 and FM-1.2, disobey specifications, may seem like general instruction-following limitation, we identify deeper causes: (1) flaws in MAS design regarding agent roles and workflow, (2) poor user prompt specifications, or (3) limitations of the underlying LLM. We posit that a well-designed MAS should interpret high-level objectives with minimal but clear user input to mitigate the impact of points (2) and (3).

For instance, when ChatDev is tasked to create a Wordle game with the prompt a standard wordle game by providing a daily 5-letter..., the generated program uses a fixed word dictionary. Even with a more explicit prompt like ...without having a fixed word bank, and randomly select a new 5-letter word each day, ChatDev still produces code with a fixed list and new errors. This suggests failures stem from the MAS’s design for interpreting specifications. Our intervention studies (Appendix [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")) show that improving agent role specifications alone yields a +9.4% success rate increase for ChatDev with the same user prompt and LLM (GPT-4o).

FC2 covers failures in agent coordination. These include unexpected conversation resets (FM-2.1, 2.20%), proceeding with wrong assumptions instead of seeking clarification (FM-2.2, 6.80%), task derailment (FM-2.3, 7.40%), withholding crucial information (FM-2.4, 0.85%), ignoring other agents’ input (FM-2.5, 1.90%), or mismatches between reasoning and action (FM-2.6, 13.2%). Figure [3](https://arxiv.org/html/2503.13657#S3.F3 "Figure 3 ‣ 3.3 Enabling Scalable Annotation: The LLM-as-a-Judge Pipeline ‣ 3 The Multi-Agent Systems Dataset ‣ Why Do Multi-Agent LLM Systems Fail?") illustrates information withholding (FM-2.4). Diagnosing FC2 failures can be complex, as similar surface behaviors (e.g., missing information) can stem from different root causes like withholding (FM-2.4), ignoring input (FM-2.5), or context mismanagement (FM-1.4), underscoring the need for MAST’s fine-grained modes.

Recent system innovations, such as Model Context Protocol \[[46](https://arxiv.org/html/2503.13657#bib.bib46)\] and Agent to Agent \[[47](https://arxiv.org/html/2503.13657#bib.bib47)\], improve agent communication by standardizing message formats from different tool or agent providers. However, the errors we observe in FC2 occur even when agents within the same framework communicate using natural language. This signals a deeper agent interaction dynamic challenge: the collapse of ’theory of mind’ \[[48](https://arxiv.org/html/2503.13657#bib.bib48)\], where agents fail to accurately model other agents’ informational needs. Addressing this likely requires structural improvements to the content of agent messages or enhancing models’ contextual reasoning and their capacity to infer other agents’ informational needs, such as through targeted training, as base LLMs are generally not pre-trained for such nuanced inter-agent dynamics. Thus, robust solutions will likely involve a combination of improved MAS architecture and model-level advancements in communicative intelligence.

FC3 failures are related to the quality control of the final output, including premature termination (FM-3.1, 6.20%), no or incomplete verification (FM-3.2, 8.20%), or incorrect verification (FM-3.3, 9.10%). These highlight challenges in ensuring output correctness and reliability. Systems with explicit verifiers like MetaGPT and ChatDev generally show fewer total failures (Figure [4](https://arxiv.org/html/2503.13657#S5.F4 "Figure 4 ‣ 5 Towards better Multi-Agent LLM Systems ‣ Why Do Multi-Agent LLM Systems Fail?")), indicating explicit checks help. However, the presence of a verifier is not a silver bullet, as overall MAS success rates can still be low. For example (FM-3.2), a ChatDev-generated chess program passes superficial checks (e.g., code compilation) but contains runtime bugs because it fails to validate against actual game rules, rendering the output unusable despite review phases.

During our GT analysis of MAS traces, we find that many existing verifiers perform only superficial checks, despite being prompted to perform thorough verification, such as checking if the code compiles or if there are leftover TODO comments. We posit that MAS development should take lessons from traditional software development where programmers test their code before committing. More rigorous verification is needed, such as using external knowledge, collecting testing output throughout generation, and multi-level checks for both low-level correctness and high-level objectives. We demonstrate this in an intervention study where adding a high-level task objective verification step to ChatDev yields a +15.6% improvement in task success on ProgramDev (details in Appendix [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")).

## 5 Towards better Multi-Agent LLM Systems

Figure 4: Distribution of failure in MAST-Data with MAST labels on total 210 traces. This plot visualizes the failure distributions of the first 30 traces for each system. As the specific tasks and benchmarks may differ across the MAS configurations shown, these results are intended to illustrate system-specific failure profiles rather than to serve as a performance comparison across MAS.

We now discuss the broader implications and usage of MAST-Data and MAST. MAST-Data, with its annotations grounded in MAST, provides crucial empirical evidence, while MAST offers a foundational framework and practical tool for understanding, debugging, and ultimately improving MAS. By concretely defining failure modes and providing a large-scale dataset of their occurrences, our work outlines the challenges in building reliable MAS and opens targeted research problems for the community.

### 5.1 Failure Breakdown in MAST-Data

Our analysis of MAST-Data reveals that failure distributions differ markedly across various MAS, often reflecting their unique architectural characteristics and design philosophies. For example, as illustrated in Figure [4](https://arxiv.org/html/2503.13657#S5.F4 "Figure 4 ‣ 5 Towards better Multi-Agent LLM Systems ‣ Why Do Multi-Agent LLM Systems Fail?"), we observe specific patterns: AppWorld frequently suffers from premature terminations (FM-3.1), potentially due to its star topology and lack of a predefined workflow making termination conditions less obvious; OpenManus exhibits a tendency towards step repetition (FM-1.3); and HyperAgent could benefit from addressing its dominant failure modes of step repetition (FM-1.3) and incorrect verification (FM-3.3). These system-specific profiles underscore that there is no one-size-fits-all solution to MAS failures.

We also use MAST-Data to study the impact of different underlying language models and MAS designs on failure patterns. For instance, when comparing GPT-4o and Claude 3.7 Sonnet within the MetaGPT framework on programming tasks, we find that while GPT-4o generally performs better than Claude, it shows significantly fewer FC1 (System Design Issues) failures by 39%. We also examine the impact of different MAS designs on the same benchmark, such as comparing MetaGPT and ChatDev on ProgramDev. Here, while MetaGPT generally outperforms ChatDev by having 60-68% less failure in FC1 and FC2, it has 1.56x more FC3 failure than ChatDev. These comparative analyses, detailed further in Appendix [F](https://arxiv.org/html/2503.13657#A6 "Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?"), provide insights into how model choice and architectural patterns influence system performance and distribution of failures.

### 5.2 MAST as a Practical Development Tool

Developing robust MAS is challenging: aggregate success rates can obscure the specific impacts of optimizations. MAST addresses this by providing a structured vocabulary for systematic failure breakdown. Using our LLM annotator with MAST, developers can obtain quantitative analyses of failure profiles for specific systems. We demonstrate MAST’s practical usage in guiding MAS improvement in our case studies (Appendix [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")). The Failure Mode breakdown analysis (Appendix [H.3](https://arxiv.org/html/2503.13657#A8.SS3 "H.3 Effect of the interventions on MAST ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")) shows which failure modes were mitigated and reveals any resulting trade-offs. This granular view, moving beyond aggregate metrics, is crucial for understanding why an intervention works and for iterating effectively towards more robust systems.

### 5.3 Beyond Model Capabilities: The Primacy of System Design

While one could simply attribute failures in MAST-Data to limitations of present-day LLM (e.g., hallucinations, misalignment), we conjecture that improvements in the base model capabilities will be insufficient to address the full MAST. Instead, we argue that good MAS design requires organizational understanding – even organizations of sophisticated individuals can fail catastrophically \[[49](https://arxiv.org/html/2503.13657#bib.bib49)\] if the organization structure is flawed. Previous research in high-reliability organizations has shown that well-defined design principles can prevent such failures \[[50](https://arxiv.org/html/2503.13657#bib.bib50), [51](https://arxiv.org/html/2503.13657#bib.bib51)\].

Consistent with organization theories, our findings indicate that many MAS failures arise from the challenges in organizational design and agent coordination rather than the limitations of individual agents. In our intervention case studies (Appendix [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")), we apply MAS system workflow and prompt changes respectively (results in Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")). With the same underlying model, we achieve max improvements of 15.6%. This highlights that MAS failures can be address with better system designs.

Although first step interventions lead to performance gains, not all failure modes are resolved, and task completion rates still remain low, indicating that more substantial improvements are needed. Achieving high reliability may requires combinatorial changes ranging from agent system organization to model level improvements (see Table [4](https://arxiv.org/html/2503.13657#A7.T4 "Table 4 ‣ G.2 Structural Strategies ‣ Appendix G Approaches and strategies to improve MASs ‣ Why Do Multi-Agent LLM Systems Fail?")). MAST, by providing a clear framework of failure points identified from MAST-Data, helps identify where these structural weaknesses lie and can guide the design and evaluation of more sophisticated MAS architectures.

## 6 Conclusion

In this study, we conduct the first systematic investigation into why MAS fail. This investigation results in the MAST-Data: a comprehensive public resource of over 1600 annotated execution traces from 7 popular MAS frameworks, which we create to outline MAS failure dynamics and guide future system development. To enable MAST-Data’s systematic annotation and analysis, we first develop the Multi-Agent System Failure Taxonomy (MAST). We build MAST through a rigorous Grounded Theory-based analysis of an initial 150 traces, validating its definitions with strong inter-annotator agreement and identifying 14 distinct failure modes across 3 categories. For scalable annotation of MAST-Data using MAST, we then develop an LLM annotator, confirming its high agreement with human experts. Together, MAST-Data and MAST provide a foundational framework and empirical grounding for future MAS research.

We are excited about the potential of MAS, but their widespread adoption hinges on achieving greater reliability. Our work, through the public release of MAST-Data, MAST, and the LLM annotator, contributes towards this goal. MAST-Data offers a rich empirical basis for understanding current failure dynamics, while MAST provides a standardized language and framework to diagnose and mitigate these failures. By systematically identifying and categorizing challenges, we aim to open up concrete research directions and equip the community to develop more robust and effective multi-agent systems.

## References

-   \[1\] Leo Tolstoy. _Anna Karenina_. The Russian Messenger, 1878.
-   \[2\] Shishir G. Patil, Tianjun Zhang, Xin Wang, and Joseph E. Gonzalez. Gorilla: Large language model connected with massive apis, 2023. URL [https://arxiv.org/abs/2305.15334](https://arxiv.org/abs/2305.15334).
-   \[3\] Charles Packer, Sarah Wooders, Kevin Lin, Vivian Fang, Shishir G. Patil, Ion Stoica, and Joseph E. Gonzalez. Memgpt: Towards llms as operating systems, 2024. URL [https://arxiv.org/abs/2310.08560](https://arxiv.org/abs/2310.08560).
-   \[4\] Lei Wang, Chen Ma, Xueyang Feng, Zeyu Zhang, Hao Yang, Jingsen Zhang, Zhiyuan Chen, Jiakai Tang, Xu Chen, Yankai Lin, Wayne Xin Zhao, Zhewei Wei, and Jirong Wen. A survey on large language model based autonomous agents. _Frontiers of Computer Science_, 18(6), March 2024a. ISSN 2095-2236. doi: 10.1007/s11704-024-40231-1. URL [http://dx.doi.org/10.1007/s11704-024-40231-1](http://dx.doi.org/10.1007/s11704-024-40231-1).
-   \[5\] Chen Qian, Wei Liu, Hongzhang Liu, Nuo Chen, Yufan Dang, Jiahao Li, Cheng Yang, Weize Chen, Yusheng Su, Xin Cong, Juyuan Xu, Dahai Li, Zhiyuan Liu, and Maosong Sun. Chatdev: Communicative agents for software development. _arXiv preprint arXiv:2307.07924_, 2023. URL [https://arxiv.org/abs/2307.07924](https://arxiv.org/abs/2307.07924).
-   \[6\] Xingyao Wang, Boxuan Li, Yufan Song, Frank F. Xu, Xiangru Tang, Mingchen Zhuge, Jiayi Pan, Yueqi Song, Bowen Li, Jaskirat Singh, Hoang H. Tran, Fuqiang Li, Ren Ma, Mingzhang Zheng, Bill Qian, Yanjun Shao, Niklas Muennighoff, Yizhe Zhang, Binyuan Hui, Junyang Lin, Robert Brennan, Hao Peng, Heng Ji, and Graham Neubig. Openhands: An open platform for ai software developers as generalist agents, 2024b. URL [https://arxiv.org/abs/2407.16741](https://arxiv.org/abs/2407.16741).
-   \[7\] Juraj Gottweis, Wei-Hung Weng, Alexander Daryin, Tao Tu, Anil Palepu, Petar Sirkovic, Artiom Myaskovsky, Felix Weissenberger, Keran Rong, Ryutaro Tanno, Khaled Saab, Dan Popovici, Jacob Blum, Fan Zhang, Katherine Chou, Avinatan Hassidim, Burak Gokturk, Amin Vahdat, Pushmeet Kohli, Yossi Matias, Andrew Carroll, Kavita Kulkarni, Nenad Tomasev, Yuan Guan, Vikram Dhillon, Eeshit Dhaval Vaishnav, Byron Lee, Tiago R D Costa, José R Penadés, Gary Peltz, Yunhan Xu, Annalisa Pawlosky, Alan Karthikesalingam, and Vivek Natarajan. Towards an ai co-scientist, 2025. URL [https://arxiv.org/abs/2502.18864](https://arxiv.org/abs/2502.18864).
-   \[8\] Kyle Swanson, Wesley Wu, Nash L. Bulaong, John E. Pak, and James Zou. The virtual lab: Ai agents design new sars-cov-2 nanobodies with experimental validation. _bioRxiv_, 2024. doi: 10.1101/2024.11.11.623004. URL [https://www.biorxiv.org/content/early/2024/11/12/2024.11.11.623004](https://www.biorxiv.org/content/early/2024/11/12/2024.11.11.623004).
-   \[9\] Joon Sung Park, Joseph C. O’Brien, Carrie J. Cai, Meredith Ringel Morris, Percy Liang, and Michael S. Bernstein. Generative agents: Interactive simulacra of human behavior, 2023a. URL [https://arxiv.org/abs/2304.03442](https://arxiv.org/abs/2304.03442).
-   \[10\] Xinbin Liang, Jinyu Xiang, Zhaoyang Yu, Jiayi Zhang, and Sirui Hong. Openmanus: An open-source framework for building general ai agents. [https://github.com/mannaandpoem/OpenManus](https://github.com/mannaandpoem/OpenManus), 2025.
-   \[11\] Adam Fourney, Gagan Bansal, Hussein Mozannar, Cheng Tan, Eduardo Salinas, Friederike Niedtner, Grace Proebsting, Griffin Bassman, Jack Gerrits, Jacob Alber, et al. Magentic-one: A generalist multi-agent system for solving complex tasks. _arXiv preprint arXiv:2411.04468_, 2024.
-   \[12\] Junda He, Christoph Treude, and David Lo. Llm-based multi-agent systems for software engineering: Vision and the road ahead, 2024a. URL [https://arxiv.org/abs/2404.04834](https://arxiv.org/abs/2404.04834).
-   \[13\] Zhao Mandi, Shreeya Jain, and Shuran Song. Roco: Dialectic multi-robot collaboration with large language models, 2023. URL [https://arxiv.org/abs/2307.04738](https://arxiv.org/abs/2307.04738).
-   \[14\] Hongxin Zhang, Weihua Du, Jiaming Shan, Qinhong Zhou, Yilun Du, Joshua B. Tenenbaum, Tianmin Shu, and Chuang Gan. Building cooperative embodied agents modularly with large language models, 2024. URL [https://arxiv.org/abs/2307.02485](https://arxiv.org/abs/2307.02485).
-   \[15\] Yilun Du, Shuang Li, Antonio Torralba, Joshua B. Tenenbaum, and Igor Mordatch. Improving factuality and reasoning in language models through multiagent debate, 2023. URL [https://arxiv.org/abs/2305.14325](https://arxiv.org/abs/2305.14325).
-   \[16\] Joon Sung Park, Joseph O’Brien, Carrie Jun Cai, Meredith Ringel Morris, Percy Liang, and Michael S Bernstein. Generative agents: Interactive simulacra of human behavior. In _Proceedings of the 36th annual acm symposium on user interface software and technology_, pages 1–22, 2023b.
-   \[17\] Taicheng Guo, Xiuying Chen, Yaqi Wang, Ruidi Chang, Shichao Pei, Nitesh V Chawla, Olaf Wiest, and Xiangliang Zhang. Large language model based multi-agents: A survey of progress and challenges. _arXiv preprint arXiv:2402.01680_, 2024a.
-   \[18\] Chunqiu Steven Xia, Yinlin Deng, Soren Dunn, and Lingming Zhang. Agentless: Demystifying llm-based software engineering agents, 2024. URL [https://arxiv.org/abs/2407.01489](https://arxiv.org/abs/2407.01489).
-   \[19\] Sayash Kapoor, Benedikt Stroebl, Zachary S. Siegel, Nitya Nadgir, and Arvind Narayanan. Ai agents that matter, 2024. URL [https://arxiv.org/abs/2407.01502](https://arxiv.org/abs/2407.01502).
-   \[20\] Barney G. Glaser and Anselm L. Strauss. _The Discovery of Grounded Theory: Strategies for Qualitative Research_. Aldine Publishing Company, 1967.
-   \[21\] Lianmin Zheng, Wei-Lin Chiang, Ying Sheng, Siyuan Zhuang, Zhanghao Wu, Yonghao Zhuang, Zi Lin, Zhuohan Li, Dacheng Li, Eric P. Xing, Hao Zhang, Joseph E. Gonzalez, and Ion Stoica. Judging llm-as-a-judge with mt-bench and chatbot arena, 2023. URL [https://arxiv.org/abs/2306.05685](https://arxiv.org/abs/2306.05685).
-   \[22\] Zora Zhiruo Wang, Jiayuan Mao, Daniel Fried, and Graham Neubig. Agent workflow memory, 2024c. URL [https://arxiv.org/abs/2409.07429](https://arxiv.org/abs/2409.07429).
-   \[23\] Omar Khattab, Arnav Singhvi, Paridhi Maheshwari, Zhiyuan Zhang, Keshav Santhanam, Sri Vardhamanan, Saiful Haq, Ashutosh Sharma, Thomas T. Joshi, Hanna Moazam, Heather Miller, Matei Zaharia, and Christopher Potts. Dspy: Compiling declarative language model calls into self-improving pipelines, 2023. URL [https://arxiv.org/abs/2310.03714](https://arxiv.org/abs/2310.03714).
-   \[24\] Yiran Wu, Tianwei Yue, Shaokun Zhang, Chi Wang, and Qingyun Wu. Stateflow: Enhancing llm task-solving through state-driven workflows, 2024a. URL [https://arxiv.org/abs/2403.11322](https://arxiv.org/abs/2403.11322).
-   \[25\] Shanshan Han, Qifan Zhang, Yuhang Yao, Weizhao Jin, Zhaozhuo Xu, and Chaoyang He. Llm multi-agent systems: Challenges and open problems, 2024. URL [https://arxiv.org/abs/2402.03578](https://arxiv.org/abs/2402.03578).
-   \[26\] Lewis Hammond, Alan Chan, Jesse Clifton, Jason Hoelscher-Obermaier, Akbir Khan, Euan McLean, Chandler Smith, Wolfram Barfuss, Jakob Foerster, Tomáš Gavenčiak, The Anh Han, Edward Hughes, Vojtěch Kovařík, Jan Kulveit, Joel Z. Leibo, Caspar Oesterheld, Christian Schroeder de Witt, Nisarg Shah, Michael Wellman, Paolo Bova, Theodor Cimpeanu, Carson Ezell, Quentin Feuillade-Montixi, Matija Franklin, Esben Kran, Igor Krawczuk, Max Lamparth, Niklas Lauffer, Alexander Meinke, Sumeet Motwani, Anka Reuel, Vincent Conitzer, Michael Dennis, Iason Gabriel, Adam Gleave, Gillian Hadfield, Nika Haghtalab, Atoosa Kasirzadeh, Sébastien Krier, Kate Larson, Joel Lehman, David C. Parkes, Georgios Piliouras, and Iyad Rahwan. Multi-agent risks from advanced ai, 2025. URL [https://arxiv.org/abs/2502.14143](https://arxiv.org/abs/2502.14143).
-   \[27\] Carlos E Jimenez, John Yang, Alexander Wettig, Shunyu Yao, Kexin Pei, Ofir Press, and Karthik R Narasimhan. SWE-bench: Can language models resolve real-world github issues? In _The Twelfth International Conference on Learning Representations_, 2024. URL [https://openreview.net/forum?id=VTF8yNQM66](https://openreview.net/forum?id=VTF8yNQM66).
-   \[28\] Ji-Lun Peng, Sijia Cheng, Egil Diau, Yung-Yu Shih, Po-Heng Chen, Yen-Ting Lin, and Yun-Nung Chen. A survey of useful llm evaluation. _arXiv preprint arXiv:2406.00936_, 2024.
-   \[29\] Wei Wang, Dan Zhang, Tao Feng, Boyan Wang, and Jie Tang. Battleagentbench: A benchmark for evaluating cooperation and competition capabilities of language models in multi-agent systems. _arXiv preprint arXiv:2408.15971_, 2024d.
-   \[30\] Timothée Anne, Noah Syrkis, Meriem Elhosni, Florian Turati, Franck Legendre, Alain Jaquier, and Sebastian Risi. Harnessing language for coordination: A framework and benchmark for llm-driven multi-agent control. _arXiv preprint arXiv:2412.11761_, 2024.
-   \[31\] Matteo Bettini, Amanda Prorok, and Vincent Moens. Benchmarl: Benchmarking multi-agent reinforcement learning. _Journal of Machine Learning Research_, 25(217):1–10, 2024.
-   \[32\] Qian Long, Zhi Li, Ran Gong, Ying Nian Wu, Demetri Terzopoulos, and Xiaofeng Gao. Teamcraft: A benchmark for multi-modal multi-agent systems in minecraft. _arXiv preprint arXiv:2412.05255_, 2024.
-   \[33\] Yang Liu, Yuanshun Yao, Jean-Francois Ton, Xiaoying Zhang, Ruocheng Guo Hao Cheng, Yegor Klochkov, Muhammad Faaiz Taufiq, and Hang Li. Trustworthy llms: A survey and guideline for evaluating large language models’ alignment. _arXiv preprint arXiv:2308.05374_, 2023.
-   \[34\] Yifan Yao, Jinhao Duan, Kaidi Xu, Yuanfang Cai, Zhibo Sun, and Yue Zhang. A survey on large language model (llm) security and privacy: The good, the bad, and the ugly. _High-Confidence Computing_, page 100211, 2024a.
-   \[35\] Anthropic, Dec 2024a. URL [https://www.anthropic.com/research/building-effective-agents](https://www.anthropic.com/research/building-effective-agents).
-   \[36\] Ion Stoica, Matei Zaharia, Joseph Gonzalez, Ken Goldberg, Hao Zhang, Anastasios Angelopoulos, Shishir G Patil, Lingjiao Chen, Wei-Lin Chiang, and Jared Q Davis. Specifications: The missing link to making the development of llm systems an engineering discipline. _arXiv preprint arXiv:2412.05299_, 2024.
-   \[37\] Gagan Bansal, Jennifer Wortman Vaughan, Saleema Amershi, Eric Horvitz, Adam Fourney, Hussein Mozannar, Victor Dibia, and Daniel S. Weld. Challenges in human-agent communication. Technical Report MSR-TR-2024-53, Microsoft, December 2024. URL [https://www.microsoft.com/en-us/research/publication/human-agent-interaction-challenges/](https://www.microsoft.com/en-us/research/publication/human-agent-interaction-challenges/).
-   \[38\] Ge Bai, Jie Liu, Xingyuan Bu, Yancheng He, Jiaheng Liu, Zhanhui Zhou, Zhuoran Lin, Wenbo Su, Tiezheng Ge, Bo Zheng, and Wanli Ouyang. Mt-bench-101: A fine-grained benchmark for evaluating large language models in multi-turn dialogues. In _Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)_, page 7421–7454. Association for Computational Linguistics, 2024. doi: 10.18653/v1/2024.acl-long.401. URL [http://dx.doi.org/10.18653/v1/2024.acl-long.401](http://dx.doi.org/10.18653/v1/2024.acl-long.401).
-   \[39\] Song Da, Zijie Zhou, Zhijie Wang, Yuheng Huang, Shengmai Chen, Bonan Kou, Lei Ma, and Tianyi Zhang. An empirical study of code generation errors made by large language models. In _In 7th Annual Symposium on Machine Programming_, 2023.
-   \[40\] Negar Arabzadeh, Siqing Huo, Nikhil Mehta, Qinqyun Wu, Chi Wang, Ahmed Awadallah, Charles L. A. Clarke, and Julia Kiseleva. Assessing and verifying task utility in llm-powered applications, 2024. URL [https://arxiv.org/abs/2405.02178](https://arxiv.org/abs/2405.02178).
-   \[41\] Will Epperson, Gagan Bansal, Victor Dibia, Adam Fourney, Jack Gerrits, Erkang (Eric) Zhu, and Saleema Amershi. Interactive debugging and steering of multi-agent ai systems. In _CHI 2025_, April 2025. URL [https://arxiv.org/abs/2503.02068](https://arxiv.org/abs/2503.02068).
-   \[42\] Shaokun Zhang, Ming Yin, Jieyu Zhang, Jiale Liu, Zhiguang Han, Jingyang Zhang, Beibin Li, Chi Wang, Huazheng Wang, Yiran Chen, and Qingyun Wu. Which agent causes task failures and when? on automated failure attribution of llm multi-agent systems, 2025. URL [https://arxiv.org/abs/2505.00212](https://arxiv.org/abs/2505.00212).
-   \[43\] Claire B Draucker, Donna S Martsolf, Ratchneewan Ross, and Thomas B Rusk. Theoretical sampling and category development in grounded theory. _Qualitative health research_, 17(8):1137–1148, 2007.
-   \[44\] Shahedul Huq Khandkar. Open coding. _University of Calgary_, 23(2009):2009, 2009.
-   \[45\] Manus AI. Manus. [https://manus.im/](https://manus.im/), 2025.
-   \[46\] Anthropic. Model context protocol: Introduction. [https://modelcontextprotocol.io/introduction](https://modelcontextprotocol.io/introduction), dec 2024b.
-   \[47\] Rao Surapaneni, Miku Jha, Michael Vakoc, and Todd Segal. A2a: A new era of agent interoperability, April 2025. URL [https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/). Google Developers Blog.
-   \[48\] Saaket Agashe, Yue Fan, Anthony Reyna, and Xin Eric Wang. Llm-coordination: Evaluating and analyzing multi-agent coordination abilities in large language models, 2025. URL [https://arxiv.org/abs/2310.03903](https://arxiv.org/abs/2310.03903).
-   \[49\] Charles Perrow. _Normal Accidents: Living with High-Risk Technologies_. Princeton University Press, Princeton, NJ, 1984. ISBN 978-0691004129.
-   \[50\] Karlene H. Roberts. New challenges in organizational research: High reliability organizations. _Organization & Environment_, 3(2):111–125, 1989. doi: 10.1177/108602668900300202.
-   \[51\] Gene I Rochlin. Reliable organizations: Present research and future directions. _Journal of contingencies and crisis management._, 4(2), 1996. ISSN 0966-0879.
-   \[52\] Sirui Hong, Xiawu Zheng, Jonathan Chen, Yuheng Cheng, Jinlin Wang, Ceyao Zhang, Zili Wang, Steven Ka Shing Yau, Zijuan Lin, Liyang Zhou, et al. Metagpt: Meta programming for multi-agent collaborative framework. _arXiv preprint arXiv:2308.00352_, 2023.
-   \[53\] Huy Nhat Phan, Tien N Nguyen, Phong X Nguyen, and Nghi DQ Bui. Hyperagent: Generalist software engineering agents to solve coding tasks at scale. _arXiv preprint arXiv:2409.16299_, 2024.
-   \[54\] Harsh Trivedi, Tushar Khot, Mareike Hartmann, Ruskin Manku, Vinty Dong, Edward Li, Shashank Gupta, Ashish Sabharwal, and Niranjan Balasubramanian. Appworld: A controllable world of apps and people for benchmarking interactive coding agents. _arXiv preprint arXiv:2407.18901_, 2024.
-   \[55\] Qingyun Wu, Gagan Bansal, Jieyu Zhang, Yiran Wu, Beibin Li, Erkang Zhu, Li Jiang, Xiaoyun Zhang, Shaokun Zhang, Jiale Liu, et al. Autogen: Enabling next-gen llm applications via multi-agent conversations. In _First Conference on Language Modeling_, 2024b.
-   \[56\] Chen Qian, Wei Liu, Hongzhang Liu, Nuo Chen, Yufan Dang, Jiahao Li, Cheng Yang, Weize Chen, Yusheng Su, Xin Cong, et al. Chatdev: Communicative agents for software development. In _Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)_, pages 15174–15186, 2024.
-   \[57\] Qingyun Wu, Gagan Bansal, Jieyu Zhang, Yiran Wu, Shaokun Zhang, Erkang Zhu, Beibin Li, Li Jiang, Xiaoyun Zhang, and Chi Wang. Autogen: Enabling next-gen llm applications via multi-agent conversation framework. _arXiv preprint arXiv:2308.08155_, 2023.
-   \[58\] Jia He, Mukund Rungta, David Koleczek, Arshdeep Sekhon, Franklin X Wang, and Sadid Hasan. Does prompt formatting have any impact on llm performance? _arXiv preprint arXiv:2411.10541_, 2024b.
-   \[59\] Yashar Talebirad and Amirhossein Nadiri. Multi-agent collaboration: Harnessing the power of intelligent llm agents. _arXiv preprint arXiv:2306.03314_, 2023.
-   \[60\] Chi-Min Chan, Weize Chen, Yusheng Su, Jianxuan Yu, Wei Xue, Shanghang Zhang, Jie Fu, and Zhiyuan Liu. Chateval: Towards better llm-based evaluators through multi-agent debate. _arXiv preprint arXiv:2308.07201_, 2023.
-   \[61\] Yixuan Weng, Minjun Zhu, Fei Xia, Bin Li, Shizhu He, Shengping Liu, Bin Sun, Kang Liu, and Jun Zhao. Large language models are better reasoners with self-verification. In _The 2023 Conference on Empirical Methods in Natural Language Processing_, 2023.
-   \[62\] LangChain. Langgraph, 2024. URL [https://www.langchain.com/langgraph](https://www.langchain.com/langgraph).
-   \[63\] Anthropic. Building effective agents, 2024c. URL [https://www.anthropic.com/research/building-effective-agents](https://www.anthropic.com/research/building-effective-agents).
-   \[64\] Shunyu Yao, Dian Yu, Jeffrey Zhao, Izhak Shafran, Tom Griffiths, Yuan Cao, and Karthik Narasimhan. Tree of thoughts: Deliberate problem solving with large language models. _Advances in Neural Information Processing Systems_, 36, 2024b.
-   \[65\] Fatemeh Haji, Mazal Bethany, Maryam Tabar, Jason Chiang, Anthony Rios, and Peyman Najafirad. Improving llm reasoning with multi-agent tree-of-thought validator agent. _arXiv preprint arXiv:2409.11527_, 2024.
-   \[66\] Zhenran Xu, Senbao Shi, Baotian Hu, Jindi Yu, Dongfang Li, Min Zhang, and Yuxiang Wu. Towards reasoning in large language models via multi-agent peer review collaboration. _arXiv preprint arXiv:2311.08152_, 2023.
-   \[67\] Benedikt Stroebl, Sayash Kapoor, and Arvind Narayanan. Inference scaling f laws: The limits of llm resampling with imperfect verifiers. _arXiv preprint arXiv:2411.17501_, 2024.
-   \[68\] Lingjiao Chen, Jared Quincy Davis, Boris Hanin, Peter Bailis, Ion Stoica, Matei Zaharia, and James Zou. Are more llm calls all you need? towards scaling laws of compound inference systems. _arXiv preprint arXiv:2403.02419_, 2024a.
-   \[69\] Kush Jain, Gabriel Synnaeve, and Baptiste Rozière. Testgeneval: A real world unit test generation and test completion benchmark. _arXiv preprint arXiv:2410.00752_, 2024.
-   \[70\] Baolin Peng, Michel Galley, Pengcheng He, Hao Cheng, Yujia Xie, Yu Hu, Qiuyuan Huang, Lars Liden, Zhou Yu, Weizhu Chen, et al. Check your facts and try again: Improving large language models with external knowledge and automated feedback. _arXiv preprint arXiv:2302.12813_, 2023.
-   \[71\] Pavan Kapanipathi, Ibrahim Abdelaziz, Srinivas Ravishankar, Salim Roukos, Alexander Gray, Ramon Astudillo, Maria Chang, Cristina Cornelio, Saswati Dana, Achille Fokoue, et al. Question answering over knowledge bases by leveraging semantic parsing and neuro-symbolic reasoning. _arXiv preprint arXiv:2012.01707_, 2020.
-   \[72\] Xinyi Li, Sai Wang, Siqi Zeng, Yu Wu, and Yi Yang. A survey on llm-based multi-agent systems: workflow, infrastructure, and challenges. _Vicinagearth_, 1(1):9, 2024a.
-   \[73\] Yaru Niu, Rohan R Paleja, and Matthew C Gombolay. Multi-agent graph-attention communication and teaming. In _AAMAS_, volume 21, page 20th, 2021.
-   \[74\] Jiechuan Jiang and Zongqing Lu. Learning attentional communication for multi-agent cooperation. _Advances in neural information processing systems_, 31, 2018.
-   \[75\] Amanpreet Singh, Tushar Jain, and Sainbayar Sukhbaatar. Learning when to communicate at scale in multiagent cooperative and competitive tasks. _arXiv preprint arXiv:1812.09755_, 2018.
-   \[76\] Chao Yu, Akash Velu, Eugene Vinitsky, Jiaxuan Gao, Yu Wang, Alexandre Bayen, and Yi Wu. The surprising effectiveness of ppo in cooperative multi-agent games. _Advances in Neural Information Processing Systems_, 35:24611–24624, 2022.
-   \[77\] Xudong Guo, Daming Shi, Junjie Yu, and Wenhui Fan. Heterogeneous multi-agent reinforcement learning for zero-shot scalable collaboration. _arXiv preprint arXiv:2404.03869_, 2024b.
-   \[78\] Weize Chen, Jiarui Yuan, Chen Qian, Cheng Yang, Zhiyuan Liu, and Maosong Sun. Optima: Optimizing effectiveness and efficiency for llm-based multi-agent system. _arXiv preprint arXiv:2410.08115_, 2024b.
-   \[79\] Eric Horvitz. Uncertainty, action, and interaction: In pursuit of mixed-initiative computing. _IEEE Intelligent Systems_, 14(5):17–20, 1999.
-   \[80\] Barnali Chakraborty and Debapratim Purkayastha. Servicenow: From startup to world’s most innovative company. _IUP Journal of Entrepreneurship Development_, 20(1), 2023.
-   \[81\] Qintong Li, Leyang Cui, Xueliang Zhao, Lingpeng Kong, and Wei Bi. Gsm-plus: A comprehensive benchmark for evaluating the robustness of llms as mathematical problem solvers. _arXiv preprint arXiv:2402.19255_, 2024b.
-   \[82\] Karl Cobbe, Vineet Kosaraju, Mohammad Bavarian, Mark Chen, Heewoo Jun, Lukasz Kaiser, Matthias Plappert, Jerry Tworek, Jacob Hilton, Reiichiro Nakano, et al. Training verifiers to solve math word problems. _arXiv preprint arXiv:2110.14168_, 2021.
-   \[83\] Binyuan Hui, Jian Yang, Zeyu Cui, Jiaxi Yang, Dayiheng Liu, Lei Zhang, Tianyu Liu, Jiajun Zhang, Bowen Yu, Kai Dang, et al. Qwen2. 5-coder technical report. _arXiv preprint arXiv:2409.12186_, 2024.
-   \[84\] Baptiste Roziere, Jonas Gehring, Fabian Gloeckle, Sten Sootla, Itai Gat, Xiaoqing Ellen Tan, Yossi Adi, Jingyu Liu, Romain Sauvestre, Tal Remez, et al. Code llama: Open foundation models for code. _arXiv preprint arXiv:2308.12950_, 2023.

## Organization of Appendix

The appendix is organized as follows: in Section [A](https://arxiv.org/html/2503.13657#A1 "Appendix A MAST Failure Categories: Deep Dive ‣ Why Do Multi-Agent LLM Systems Fail?") further details about failure categories and failure modes are given, in Section [B](https://arxiv.org/html/2503.13657#A2 "Appendix B Details of Multi-Agent Systems Evaluated ‣ Why Do Multi-Agent LLM Systems Fail?") we provide some details about the multi-agent systems we have annotated and studied, in Section [C](https://arxiv.org/html/2503.13657#A3 "Appendix C MAST Python Library ‣ Why Do Multi-Agent LLM Systems Fail?") we describe how to use the MAST easily as a python library using `pip install`, in Section [D](https://arxiv.org/html/2503.13657#A4 "Appendix D ProgramDev and ProgramDev-v2 Datasets ‣ Why Do Multi-Agent LLM Systems Fail?") we describe the tasks in ProgramDev and ProgramDev-v2 Datsaet, in Section [E](https://arxiv.org/html/2503.13657#A5 "Appendix E MAS Failure Modes Correlation ‣ Why Do Multi-Agent LLM Systems Fail?") we plot the correlations between MAS failure modes, in Section [F](https://arxiv.org/html/2503.13657#A6 "Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?") we analyze the failure comparison between models and MAS, in Section [G](https://arxiv.org/html/2503.13657#A7 "Appendix G Approaches and strategies to improve MASs ‣ Why Do Multi-Agent LLM Systems Fail?") we discuss some tactical approaches and structural strategies to make MASs more robust to failures, in Section [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?") we present two case studies where we show that tactical approaches can get only limited results, in Section [I](https://arxiv.org/html/2503.13657#A9 "Appendix I Analysis on Multi-Agent Systems with Open-Source Models ‣ Why Do Multi-Agent LLM Systems Fail?") we present the failure mode distribution of the MAS frameworks powered by open-source language models, in Section [J](https://arxiv.org/html/2503.13657#A10 "Appendix J Correlation of Failure Modes with Different Statistics ‣ Why Do Multi-Agent LLM Systems Fail?") we present the correlations of failure mode distribution with some crucial statistics such as task completion rates and different benchmarks, in Section [K](https://arxiv.org/html/2503.13657#A11 "Appendix K LLM Annotator Cost ‣ Why Do Multi-Agent LLM Systems Fail?") we present the cost breakdown of LLM Annotator used in this paper for different MAS frameworks, in Sections [L](https://arxiv.org/html/2503.13657#A12 "Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?") and [M](https://arxiv.org/html/2503.13657#A13 "Appendix M ChatDev Prompt Interventions ‣ Why Do Multi-Agent LLM Systems Fail?") there are prompt interventions we tested on AG2 and ChatDev case studies, in Section [N](https://arxiv.org/html/2503.13657#A14 "Appendix N Examples of Different Failure Modes ‣ Why Do Multi-Agent LLM Systems Fail?") examples of every failure mode are reported and commented.

## Appendix A MAST Failure Categories: Deep Dive

### A.1 FC1. System Design Issues

This category includes failures that arise from deficiencies in the design of the system architecture, poor conversation management, unclear task specifications or violation of constraints, and inadequate definition or adherence to the roles and responsibilities of the agents.

We identify five failure modes under this category:

-   •
    
    FM-1.1: Disobey task specification - Failure to adhere to the specified constraints or requirements of a given task, leading to suboptimal or incorrect outcomes.
    
-   •
    
    FM-1.2: Disobey role specification - Failure to adhere to the defined responsibilities and constraints of an assigned role, potentially leading to an agent behaving like another.
    
-   •
    
    FM-1.3: Step repetition - Unnecessary reiteration of previously completed steps in a process, potentially causing delays or errors in task completion.
    
-   •
    
    FM-1.4: Loss of conversation history - Unexpected context truncation, disregarding recent interaction history and reverting to an antecedent conversational state.
    
-   •
    
    FM-1.5: Unaware of termination conditions - Lack of recognition or understanding of the criteria that should trigger the termination of the agents’ interaction, potentially leading to unnecessary continuation.
    

### A.2 FC2. Inter-Agent Misalignment

This category includes failures arising from ineffective communication, poor collaboration, conflicting behaviors among agents, and gradual derailment from the initial task.

We identify six failure modes under this category:

-   •
    
    FM-2.1: Conversation reset - Unexpected or unwarranted restarting of a dialogue, potentially losing context and progress made in the interaction.
    
-   •
    
    FM-2.2: Fail to ask for clarification - Inability to request additional information when faced with unclear or incomplete data, potentially resulting in incorrect actions.
    
-   •
    
    FM-2.3: Task derailment - Deviation from the intended objective or focus of a given task, potentially resulting in irrelevant or unproductive actions.
    
-   •
    
    FM-2.4: Information withholding - Failure to share or communicate important data or insights that an agent possess and could impact decision-making of other agents if shared.
    
-   •
    
    FM-2.5: Ignored other agent’s input - Disregarding or failing to adequately consider input or recommendations provided by other agents in the system, potentially leading to suboptimal decisions or missed opportunities for collaboration.
    
-   •
    
    FM-2.6: Reasoning-action mismatch - Discrepancy between the logical reasoning process and the actual actions taken by the agent, potentially resulting in unexpected or undesired behaviors.
    

### A.3 FC3. Task Verification

This category includes failures resulting from premature execution termination, as well as insufficient mechanisms to guarantee the accuracy, completeness, and reliability of interactions, decisions, and outcomes.

We identify three failure modes under this category:

-   •
    
    FM-3.1: Premature termination - Ending a dialogue, interaction or task before all necessary information has been exchanged or objectives have been met, potentially resulting in incomplete or incorrect outcomes.
    
-   •
    
    FM-3.2: No or incomplete verification - (partial) omission of proper checking or confirmation of task outcomes or system outputs, potentially allowing errors or inconsistencies to propagate undetected.
    
-   •
    
    FM-3.3: Incorrect verification - Failure to adequately validate or cross-check crucial information or decisions during the iterations, potentially leading to errors or vulnerabilities in the system.
    

## Appendix B Details of Multi-Agent Systems Evaluated

In this section, we provide details on MAS we evaluated during this study and their performance benchmark evaluation.

Figure 5: Failure rates of six popular Multi-Agent LLM Systems with GPT-4o and Claude-3.7-Sonnet. Performances are measured on different benchmarks, therefore they are not directly comparable.

### B.1 Overview of MAS

In this study, we evaluated 7 open-source frameworks. The architecture and the purpose of the systems is detailed in the table below.

Table 3: Overview of MAS covered in MAST-Data

<table id="A2.T3.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A2.T3.4.1" class="ltx_tr"><td id="A2.T3.4.1.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_tt"><span id="A2.T3.4.1.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.1.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.1.1.1.1.1" class="ltx_text" style="font-size:90%;">MAS</span></span></span></td><td id="A2.T3.4.1.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_tt"><span id="A2.T3.4.1.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.1.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.1.2.1.1.1" class="ltx_text" style="font-size:90%;">Agentic Architecture</span></span></span></td><td id="A2.T3.4.1.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_tt"><span id="A2.T3.4.1.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.1.3.1.1" class="ltx_p"><span id="A2.T3.4.1.3.1.1.1" class="ltx_text" style="font-size:90%;">Purpose of the System</span></span></span></td></tr><tr id="A2.T3.4.2" class="ltx_tr"><td id="A2.T3.4.2.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.2.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.2.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.2.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.2.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib52" title="" class="ltx_ref">52</a><span id="A2.T3.4.2.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.2.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.2.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.2.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.2.2.1.1.1" class="ltx_text" style="font-size:90%;">Assembly Line</span></span></span></td><td id="A2.T3.4.2.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.2.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.2.3.1.1" class="ltx_p"><span id="A2.T3.4.2.3.1.1.1" class="ltx_text" style="font-size:90%;">Simulating the SOPs of different roles in Software Companies to create open-ended software applications</span></span></span></td></tr><tr id="A2.T3.4.3" class="ltx_tr"><td id="A2.T3.4.3.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.3.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.3.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.3.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib5" title="" class="ltx_ref">5</a><span id="A2.T3.4.3.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.3.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.3.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.3.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.3.2.1.1.1" class="ltx_text" style="font-size:90%;">Hierarchical Workflow</span></span></span></td><td id="A2.T3.4.3.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.3.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.3.3.1.1" class="ltx_p"><span id="A2.T3.4.3.3.1.1.1" class="ltx_text" style="font-size:90%;">Simulating different Software Engineering phases like (design, code, QA) through simulated roles in a software engineering company</span></span></span></td></tr><tr id="A2.T3.4.4" class="ltx_tr"><td id="A2.T3.4.4.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.4.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.4.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">HyperAgent</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.4.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib53" title="" class="ltx_ref">53</a><span id="A2.T3.4.4.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.4.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.4.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.4.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.4.2.1.1.1" class="ltx_text" style="font-size:90%;">Hierarchical Workflow</span></span></span></td><td id="A2.T3.4.4.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.4.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.4.3.1.1" class="ltx_p"><span id="A2.T3.4.4.3.1.1.1" class="ltx_text" style="font-size:90%;">Simulating a software engineering team with a central Planner agent coordinating with specialized child agents (Navigator, Editor, and Executor)</span></span></span></td></tr><tr id="A2.T3.4.5" class="ltx_tr"><td id="A2.T3.4.5.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.5.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.5.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.5.1.1.1.1" class="ltx_text" style="font-size:90%;">AppWorld</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.5.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib54" title="" class="ltx_ref">54</a><span id="A2.T3.4.5.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.5.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.5.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.5.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.5.2.1.1.1" class="ltx_text" style="font-size:90%;">Star Topology</span></span></span></td><td id="A2.T3.4.5.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.5.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.5.3.1.1" class="ltx_p"><span id="A2.T3.4.5.3.1.1.1" class="ltx_text" style="font-size:90%;">Tool-calling agents specialized to utility services (ex: Gmail, Spotify, etc.) being orchestrated by a supervisor to achieve cross-service tasks</span></span></span></td></tr><tr id="A2.T3.4.6" class="ltx_tr"><td id="A2.T3.4.6.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.6.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.6.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.6.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.6.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib55" title="" class="ltx_ref">55</a><span id="A2.T3.4.6.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.6.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.6.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.6.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.6.2.1.1.1" class="ltx_text" style="font-size:90%;">N/A - Agentic Framework</span></span></span></td><td id="A2.T3.4.6.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.6.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.6.3.1.1" class="ltx_p"><span id="A2.T3.4.6.3.1.1.1" class="ltx_text" style="font-size:90%;">An open-source programming framework for building agents and managing their interactions.</span></span></span></td></tr><tr id="A2.T3.4.7" class="ltx_tr"><td id="A2.T3.4.7.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.7.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.7.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.7.1.1.1.1" class="ltx_text" style="font-size:90%;">Magentic-One</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.7.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib11" title="" class="ltx_ref">11</a><span id="A2.T3.4.7.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.7.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.7.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.7.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.7.2.1.1.1" class="ltx_text" style="font-size:90%;">Star Topology</span></span></span></td><td id="A2.T3.4.7.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_t"><span id="A2.T3.4.7.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.7.3.1.1" class="ltx_p"><span id="A2.T3.4.7.3.1.1.1" class="ltx_text" style="font-size:90%;">A generalist multi-agent system designed to autonomously solve complex, open-ended tasks involving web and file-based environments across various domains.</span></span></span></td></tr><tr id="A2.T3.4.8" class="ltx_tr"><td id="A2.T3.4.8.1" class="ltx_td ltx_align_left ltx_align_middle ltx_border_bb ltx_border_t"><span id="A2.T3.4.8.1.1" class="ltx_inline-block ltx_align_middle" style="width:79.7pt;"><span id="A2.T3.4.8.1.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.8.1.1.1.1" class="ltx_text" style="font-size:90%;">OpenManus</span><br class="ltx_break"><cite class="ltx_cite ltx_citemacro_cite"><span id="A2.T3.4.8.1.1.1.2" class="ltx_text" style="font-size:90%;">[</span><a href="https://arxiv.org/html/2503.13657#bib.bib10" title="" class="ltx_ref">10</a><span id="A2.T3.4.8.1.1.1.3" class="ltx_text" style="font-size:90%;">]</span></cite></span></span></td><td id="A2.T3.4.8.2" class="ltx_td ltx_align_left ltx_align_middle ltx_border_bb ltx_border_t"><span id="A2.T3.4.8.2.1" class="ltx_inline-block ltx_align_middle" style="width:71.1pt;"><span id="A2.T3.4.8.2.1.1" class="ltx_p ltx_align_center"><span id="A2.T3.4.8.2.1.1.1" class="ltx_text" style="font-size:90%;">Hierarchical</span></span></span></td><td id="A2.T3.4.8.3" class="ltx_td ltx_align_left ltx_align_middle ltx_border_bb ltx_border_t"><span id="A2.T3.4.8.3.1" class="ltx_inline-block ltx_align_middle" style="width:204.9pt;"><span id="A2.T3.4.8.3.1.1" class="ltx_p"><span id="A2.T3.4.8.3.1.1.1" class="ltx_text" style="font-size:90%;">An open-source multi-agent framework designed to facilitate the development of collaborative AI agents that solve real-world tasks. It was inspired by the Manus AI agent.</span></span></span></td></tr></tbody></table>

### B.2 Multi-Agent Systems in the Initial Annotation Phase

MetaGPT. MetaGPT \[[52](https://arxiv.org/html/2503.13657#bib.bib52)\] is a multi-agent system that simulates a software engineering company and involves agents such as a Coder and a Verifier. The goal is to have agents with domain-expertise (achieved by encoding Standard Operating Procedures of different roles into agents prompts) collaboratively solve a programming task, specified in natural language.

ChatDev. ChatDev is a generalist multi-agent framework that initializes different agents, each assuming common roles in a software-development company \[[56](https://arxiv.org/html/2503.13657#bib.bib56)\]. The framework breaks down the process of software development into 3 phases: design, coding and testing. Each phase is divided into sub-tasks, for example, testing is divided into code review (static) and system testing (dynamic). In every sub-task, two agents collaborate where one of the agents acts as the orchestrator and initiates the interaction and the other acts as an assistant to help the orchestrator achieve the task. The 2 agents then hold a multi-turn conversation to achieve the goal stated by the orchestrator ultimately leading to the completion of the task, marked by a specific sentinel by either agents. ChatDev has the following agent roles: CEO, CTO, Programmer, Reviewer and Tester. ChatDev introduces “Communicative Dehallucination”, which encourages the assistant to seek further details about the task over multiple-turns, instead of responding immediately.

HyperAgent. HyperAgent \[[53](https://arxiv.org/html/2503.13657#bib.bib53)\] is a framework for software engineering tasks organized around four primary agents: Planner, Navigator, Code Editor, and Executor. These agents are enhanced by specialized tools, designed to provide LLM-interpretable output. The Planner communicates with child agents via a standardized message format with two fields: Context (background and rationale) and Request (actionable instructions). Tasks are broken down into subtasks and published to specific queues. Child agents, such as Navigator, Editor, and Executor instances, monitor these queues and process tasks asynchronously, enabling parallel execution and significantly improving scalability and efficiency. For example, multiple Navigator instances can explore different parts of a large codebase in parallel, the Editor can apply changes across multiple files simultaneously, and the Executor can run tests concurrently, accelerating validation.

AppWorld. AppWorld is a benchmark, that provides an environment with elaborate mocks of various everyday services like eShopping Website, Music Player, Contacts, Cost-sharing app, e-mail, etc \[[54](https://arxiv.org/html/2503.13657#bib.bib54)\]. The benchmark consists of tasks that require executing APIs from multiple services to achieve the end-users tasks. The AppWorld benchmark provides a ReAct based agent over GPT-4o as a strong baseline. We create a multi-agent system over AppWorld derived from the baseline ReAct agent, where each agent specializes in using one of the services mocked in AppWorld, with detailed instructions about the APIs available in that service, and access to the documentation for that specific service. A supervisor agent receives the task instruction to be completed, and can hold one-on-one multi-turn conversations with each of the service-specific agents. The service-agents are instructed to seek clarification with the supervisor, whenever required. The supervisor agent holds access to various information about the human-user, for example, credentials to access various services, name, email-id and contact of the user, etc, which the service-agents need to access the services, and must clarify with the supervisor agent.

AG2. AG2 (formerly AutoGen) \[[57](https://arxiv.org/html/2503.13657#bib.bib57)\] is an open-source programming framework for building agents and managing their interactions. With this framework, it is possible to build various flexible conversation patterns, integrating tools usage and customizing the termination strategy.

### B.3 Closed-Source MAS

In our efforts to build a comprehensive dataset, we also explore popular closed-source platforms that are speculated to function as MAS. A notable example is Manus \[[45](https://arxiv.org/html/2503.13657#bib.bib45)\], a general AI agent platform. However, evaluating and incorporating such systems into MAST-Data for fine-grained failure analysis presents significant challenges. Specifically, with systems like Manus, the underlying language model is often not disclosed, and more critically, the platforms may not provide access to full agent execution traces. This lack of transparency into the internal conversational and operational steps makes reliable, detailed failure annotation using MAST infeasible. While we conduct human evaluation of task correctness for some closed-source systems (for instance, Manus achieves a 60% success rate on our ProgramDev benchmark), the absence of comprehensive trace data prevents their inclusion in the primary MAST-Data which focuses on deeply annotated failure dynamics. Our focus for MAST-Data thus remains on systems where such trace analysis can yield robust insights.

## Appendix C MAST Python Library

In order to ease the usage of MAST, we also package our code as a pip installable python library, under the name `agentdash`. The example usage is shown below.

# Install the package (if you’re in a notebook)

!pip install agentdash

from agentdash import annotator

# Initialize the annotator with your OpenAI API key

openai\_api\_key \= "your\-api\-key"

MASTAnnotator \= annotator(openai\_api\_key)

# Annotate a multi\-agent system trace

trace \= """

Agent1: I need to calculate the sum of 1 + 1.

Agent2: I’ll help you with that. The answer is 3.

Agent1: Thank you! Task completed.

"""

mast\_annotation \= MASTAnnotator.produce\_taxonomy(trace)

# View results

print("Failure Modes Detected:")

for failure\_mode\_id, detected in mast\_annotation\["failure\_modes"\].items():

if detected:

info \= MASTAnnotator.get\_failure\_mode\_info(failure\_mode\_id)

print(f" {failure\_mode\_id}: {info\[’name’\]}")

print(f"\\nSummary: {mast\_annotation\[’summary’\]}")

print(f"Task Completed: {mast\_annotation\[’task\_completion’\]}")

print(f"Total Failures: {mast\_annotation\[’total\_failures’\]}")

## Appendix D ProgramDev and ProgramDev-v2 Datasets

The ProgramDev dataset contains 30 coding problems 3. These tasks are programming challenges, such as implementing Tic-Tac-Toe, Chess, or Sudoku, for which abundant solutions and descriptions are readily available online. We design ProgramDev with tasks intended to be relatively straightforward for MAS, rather than exceptionally difficult, to better isolate specific failure dynamics. We later extend this to ProgramDev-v2, a 100-problem dataset developed primarily for the comparative analyses of MAS architectures and underlying LLMs presented in Figure [8](https://arxiv.org/html/2503.13657#A6.F8 "Figure 8 ‣ Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?").

## Appendix E MAS Failure Modes Correlation

We evaluate MAST’s effectiveness based on three key aspects: its generalization to unseen systems and datasets, the balanced distribution of identified failures, and the distinctiveness of its failure categories. This section details the correlation analysis.

Figure [6](https://arxiv.org/html/2503.13657#A5.F6 "Figure 6 ‣ Appendix E MAS Failure Modes Correlation ‣ Why Do Multi-Agent LLM Systems Fail?") shows low correlations (0.17-0.32). This suggests that the categories capture distinct aspects of MAS failures with limited overlap, supporting the taxonomy’s structure. This distinctiveness is crucial because, as noted in Insight 2, failures with similar surface behaviors can stem from different root causes (e.g., memory management vs. agent coordination).

Although MAST’s fine-grained nature helps differentiate root cause, it also poses a challenge for our LLM annotator. Analyzing correlations between specific failure modes (see Appendix [E](https://arxiv.org/html/2503.13657#A5 "Appendix E MAS Failure Modes Correlation ‣ Why Do Multi-Agent LLM Systems Fail?") for Figure [7](https://arxiv.org/html/2503.13657#A5.F7 "Figure 7 ‣ Appendix E MAS Failure Modes Correlation ‣ Why Do Multi-Agent LLM Systems Fail?")) shows moderate correlations (max of 0.63) between modes with similar symptoms might lead automated evaluators to conflate distinct root causes.

Figure 6: MAS failure modes correlation matrix

Figure 7: MAS failure modes correlation matrix

## Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures

Figure 8: Comparison on MAST failure modes and categories on ProgramDev-v2 dataset explained in Section [D](https://arxiv.org/html/2503.13657#A4 "Appendix D ProgramDev and ProgramDev-v2 Datasets ‣ Why Do Multi-Agent LLM Systems Fail?") to analyze LLM choice effect. MetaGPT is used for both cases with GPT-4o and Claude-3.7-Sonnet on two comparative cases.

Figure 9: Comparison on MAST failure modes and categories on ProgramDev-v2 dataset explained in Section [D](https://arxiv.org/html/2503.13657#A4 "Appendix D ProgramDev and ProgramDev-v2 Datasets ‣ Why Do Multi-Agent LLM Systems Fail?") to analyze MAS architecture effect. GPT-4o is used on two comparative cases, one using ChatDev and the other on MetaGPT.

To understand how choices of underlying LLMs and MAS architectures influence failure patterns, we analyze results from our MAST-Data, categorized by MAST in the Figures [8](https://arxiv.org/html/2503.13657#A6.F8 "Figure 8 ‣ Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?") and [9](https://arxiv.org/html/2503.13657#A6.F9 "Figure 9 ‣ Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?").

First, we examine the impact of different LLMs by comparing GPT-4o and Claude 3.7 Sonnet within the MetaGPT framework on programming tasks Figure [8](https://arxiv.org/html/2503.13657#A6.F8 "Figure 8 ‣ Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?"). Our findings indicate that GPT-4o exhibits substantially fewer failures in FC1 (System Design Issues, e.g., disobeying task or role specifications) and FC2 (Inter-Agent Misalignment, e.g., issues in coordination or communication) compared to Claude 3.7 Sonnet. This suggests GPT-4o may possess stronger capabilities in instruction following or aspects of ‘social reasoning’ for agentic collaboration within this setup. However, both models show a high number of failures in FC3 (Task Verification), indicating that robust verification remains a significant challenge regardless of the LLM used, though GPT-4o has a marginally lower count here.

Next, we investigate the effect of MAS architecture by comparing MetaGPT and ChatDev, both using GPT-4o as the underlying LLM, on the ProgramDev-v2 benchmark in Figure [9](https://arxiv.org/html/2503.13657#A6.F9 "Figure 9 ‣ Appendix F Understanding Failures: The Impact of Different LLMs and Agent Architectures ‣ Why Do Multi-Agent LLM Systems Fail?"). We observe distinct failure profiles: MetaGPT demonstrates significantly fewer failures in FC1 (System Design Issues) and FC2 (Inter-Agent Misalignment) compared to ChatDev. This could imply that MetaGPT’s architecture or operational flow is more effective at maintaining adherence to specifications and ensuring smoother agent coordination with GPT-4o. Interestingly, despite its stronger performance in FC1 and FC2, MetaGPT exhibits a considerably higher number of FC3 (Task Verification) failures than ChatDev. This may stem from the fact that in MetaGPT, the adherence to task specifications and role specifications ar done mostly through SoPs, demonstrating strong performance in FC1 especially. However ChatDev places a higher importance in verification as it is reflected by the specific testing and reviewing phases in ChatDev’s archiectural design, causing fewer verification issues. These results show that both the choice of LLM and the specific design of the MAS architecture critically shape the landscape of potential failures, and improvements likely require a holistic approach considering both aspects.

## Appendix G Approaches and strategies to improve MASs

In this section, we discuss some approaches to make MASs more robust to failures. We categorize these strategies into two main groups: (i) tactical approaches, (ii) structural strategies. Tactical approaches involve straightforward modifications tailored for specific failure modes, such as improving the prompts, topology of the network of agents, and conversation management. In Section [H](https://arxiv.org/html/2503.13657#A8 "Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?"), we experiment with such approaches in two case studies, and demonstrate that the effectiveness of these methods is not consistent. This leads us to consider a second category of strategies that are more comprehensive methods with system-wide impacts: strong verification, enhanced communication protocols, uncertainty quantification, and memory and state management. These strategies require more in-depth study and meticulous implementation, and remain open research topics for future exploration. See Table [4](https://arxiv.org/html/2503.13657#A7.T4 "Table 4 ‣ G.2 Structural Strategies ‣ Appendix G Approaches and strategies to improve MASs ‣ Why Do Multi-Agent LLM Systems Fail?") for our proposed mapping between different solution strategies and the failure categories.

### G.1 Tactical Approaches

This category includes strategies related to improving prompts and optimizing agent organization and interactions. The prompts of MAS agents should provide clear description of instructions, and the role of each agent should be clearly specified (see [L.2](https://arxiv.org/html/2503.13657#A12.SS2 "L.2 Structured prompt with verification section ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?") as an example) \[[58](https://arxiv.org/html/2503.13657#bib.bib58), [59](https://arxiv.org/html/2503.13657#bib.bib59)\]. Prompts can also clarify roles and tasks while encouraging proactive dialogue. Agents can re-engage or retry if inconsistencies arise, as shown in Appendix [L.5](https://arxiv.org/html/2503.13657#A12.SS5 "L.5 Agent Verifier’s System Prompt ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?") \[[60](https://arxiv.org/html/2503.13657#bib.bib60)\]. After completing a complex multi-step task, add a self-verification step to the prompt to retrace the reasoning by restating solutions, checking conditions, and testing for errors \[[61](https://arxiv.org/html/2503.13657#bib.bib61)\]. However, it may miss flaws, rely on vague conditions, or be impractical \[[36](https://arxiv.org/html/2503.13657#bib.bib36)\]. Moreover, clear role specifications can be reinforced by defining conversation patterns and setting termination conditions \[[55](https://arxiv.org/html/2503.13657#bib.bib55), [62](https://arxiv.org/html/2503.13657#bib.bib62)\]. A modular approach with simple, well-defined agents, rather than complex, multitasked ones, enhances performance and simplifies debugging \[[63](https://arxiv.org/html/2503.13657#bib.bib63)\]. The group dynamics also enable other interesting possibilities of multi-agent systems: different agents can propose various solutions \[[64](https://arxiv.org/html/2503.13657#bib.bib64)\], discuss their assumptions, and findings (cross-verifications) \[[65](https://arxiv.org/html/2503.13657#bib.bib65)\]. For instance, in \[[66](https://arxiv.org/html/2503.13657#bib.bib66)\], a multi-agent strategy simulates the academic peer review process to catch deeper inconsistencies. Another set of tactical approaches for cross verifications consist in multiple LLM calls with majority voting or resampling until verification \[[67](https://arxiv.org/html/2503.13657#bib.bib67), [68](https://arxiv.org/html/2503.13657#bib.bib68)\]. However, these seemingly straightforward solutions often prove inconsistent, echoing our case studies’ findings. This underscores the need for more robust, structural strategies, as discussed in the following sections.

### G.2 Structural Strategies

Apart from the tactical approaches we discussed above, there exist a need for more involved solutions that will shape the structure of the MAS at hand. We first observe the critical role of verification processes and verifier agents in multi-agent systems. Our annotations reveal that weak or inadequate verification mechanisms were a significant contributor to system failures. While unit test generation aids verification in software engineering \[[69](https://arxiv.org/html/2503.13657#bib.bib69)\], creating a universal verification mechanism remains challenging. Even in coding, covering all edge cases is complex, even for experts. Verification varies by domain: coding requires thorough test coverage, QA demands certified data checks \[[70](https://arxiv.org/html/2503.13657#bib.bib70)\], and reasoning benefits from symbolic validation \[[71](https://arxiv.org/html/2503.13657#bib.bib71)\]. Adapting verification across domains remains an ongoing research challenge.

A complementary strategy to verification is establishing a standardized communication protocol \[[72](https://arxiv.org/html/2503.13657#bib.bib72)\]. LLM-based agents mainly communicate via unstructured text, leading to ambiguities. Clearly defining intentions and parameters enhances alignment and enables formal coherence checks during and after interactions. \[[73](https://arxiv.org/html/2503.13657#bib.bib73)\] introduce Multi-Agent Graph Attention, leveraging a graph attention mechanism to model agent interactions and enhance coordination. Similarly, \[[74](https://arxiv.org/html/2503.13657#bib.bib74)\] propose Attentional Communication, enabling agents to selectively focus on relevant information. Likewise, \[[75](https://arxiv.org/html/2503.13657#bib.bib75)\] develop a learned selective communication protocol to improve cooperation efficiency.

Another important research direction is fine-tuning MAS agents with reinforcement learning. Agents can be trained with role-specific algorithms, rewarding task-aligned actions and penalizing inefficiencies. MAPPO \[[76](https://arxiv.org/html/2503.13657#bib.bib76)\] optimizes agents’ adherence to defined roles. Similarly, SHPPO \[[77](https://arxiv.org/html/2503.13657#bib.bib77)\] uses a latent network to learn strategies before applying a heterogeneous decision layer. Optima \[[78](https://arxiv.org/html/2503.13657#bib.bib78)\] further enhances communication efficiency and task effectiveness through iterative reinforcement learning.

On a different note, incorporating probabilistic confidence measures into agent interactions can significantly enhance decision-making and communication reliability. Drawing inspiration from the framework proposed by Horvitz et al. \[[79](https://arxiv.org/html/2503.13657#bib.bib79)\], agents can be designed to take action only when their confidence exceeds a predefined threshold. Conversely, when confidence is low, agents can pause to gather additional information. Furthermore, the system could benefit from adaptive thresholding, where confidence thresholds are dynamically adjusted.

Although often seen as a single-agent property, memory and state management are crucial for multi-agent interactions, which can enhance context understanding and reduces ambiguity in communication. However, most research focuses on single-agent systems. MemGPT \[[3](https://arxiv.org/html/2503.13657#bib.bib3)\] introduces OS-inspired context management for an extended context window, while TapeAgents \[[80](https://arxiv.org/html/2503.13657#bib.bib80)\] use a structured, replayable log (“tape”) to iteratively document and refine agent actions, facilitating dynamic task decomposition and continuous improvement.

Table 4: Solution Strategies vs. Failure Category in Multi-Agent Systems

<table id="A7.T4.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A7.T4.4.1" class="ltx_tr"><td id="A7.T4.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:82.5pt;"><span id="A7.T4.4.1.1.1.1" class="ltx_p"><span id="A7.T4.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Failure Category</span></span></span></td><td id="A7.T4.4.1.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.1.2.1" class="ltx_inline-block ltx_align_top" style="width:136.6pt;"><span id="A7.T4.4.1.2.1.1" class="ltx_p"><span id="A7.T4.4.1.2.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Tactical Approaches</span></span></span></td><td id="A7.T4.4.1.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.1.3.1" class="ltx_inline-block ltx_align_top" style="width:142.3pt;"><span id="A7.T4.4.1.3.1.1" class="ltx_p"><span id="A7.T4.4.1.3.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Structural Strategies</span></span></span></td></tr><tr id="A7.T4.4.2" class="ltx_tr"><td id="A7.T4.4.2.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.2.1.1" class="ltx_inline-block ltx_align_top" style="width:82.5pt;"><span id="A7.T4.4.2.1.1.1" class="ltx_p"><span id="A7.T4.4.2.1.1.1.1" class="ltx_text" style="font-size:90%;">System Design Issues</span></span></span></td><td id="A7.T4.4.2.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.2.2.1" class="ltx_inline-block ltx_align_top" style="width:136.6pt;"><span id="A7.T4.4.2.2.1.1" class="ltx_p"><span id="A7.T4.4.2.2.1.1.1" class="ltx_text" style="font-size:90%;">Clear role/task definitions, Engage in further discussions, Self-verification, Conversation pattern design</span></span></span></td><td id="A7.T4.4.2.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.2.3.1" class="ltx_inline-block ltx_align_top" style="width:142.3pt;"><span id="A7.T4.4.2.3.1.1" class="ltx_p"><span id="A7.T4.4.2.3.1.1.1" class="ltx_text" style="font-size:90%;">Comprehensive verification, Confidence quantification</span></span></span></td></tr><tr id="A7.T4.4.3" class="ltx_tr"><td id="A7.T4.4.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:82.5pt;"><span id="A7.T4.4.3.1.1.1" class="ltx_p"><span id="A7.T4.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">Inter-Agent Misalignment</span></span></span></td><td id="A7.T4.4.3.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.3.2.1" class="ltx_inline-block ltx_align_top" style="width:136.6pt;"><span id="A7.T4.4.3.2.1.1" class="ltx_p"><span id="A7.T4.4.3.2.1.1.1" class="ltx_text" style="font-size:90%;">Cross-verification, Conversation pattern design, Mutual disambiguation, Modular agents design</span></span></span></td><td id="A7.T4.4.3.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.3.3.1" class="ltx_inline-block ltx_align_top" style="width:142.3pt;"><span id="A7.T4.4.3.3.1.1" class="ltx_p"><span id="A7.T4.4.3.3.1.1.1" class="ltx_text" style="font-size:90%;">Standardized communication protocols, Probabilistic confidence measures</span></span></span></td></tr><tr id="A7.T4.4.4" class="ltx_tr"><td id="A7.T4.4.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:82.5pt;"><span id="A7.T4.4.4.1.1.1" class="ltx_p"><span id="A7.T4.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">Task Verification</span></span></span></td><td id="A7.T4.4.4.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.4.2.1" class="ltx_inline-block ltx_align_top" style="width:136.6pt;"><span id="A7.T4.4.4.2.1.1" class="ltx_p"><span id="A7.T4.4.4.2.1.1.1" class="ltx_text" style="font-size:90%;">Self-verification, Cross-verification, Topology redesign for verification</span></span></span></td><td id="A7.T4.4.4.3" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A7.T4.4.4.3.1" class="ltx_inline-block ltx_align_top" style="width:142.3pt;"><span id="A7.T4.4.4.3.1.1" class="ltx_p"><span id="A7.T4.4.4.3.1.1.1" class="ltx_text" style="font-size:90%;">Comprehensive verification &amp; unit test generation</span></span></span></td></tr></tbody></table>

## Appendix H Intervention Case Studies

In this section, we present the two case studies where we apply some of the tactical approaches. We also present the usage of MAST as a debugging tool, where we measure the failure modes in the system before applying any of the interventions, and then after applying the interventions we discuss below, and show that MAST can guide the intervention process as well as capture the improvements of augmentations.

### H.1 Case Study 1: AG2 - MathChat

In this case study, we use the MathChat scenario implementation in AG2 \[[57](https://arxiv.org/html/2503.13657#bib.bib57)\] as our baseline, where a Student agent collaborates with an Assistant agent capable of Python code execution to solve problems. For benchmarking, we randomly select 200 exercises from the GSM-Plus dataset \[[81](https://arxiv.org/html/2503.13657#bib.bib81)\], an augmented version of GSM8K \[[82](https://arxiv.org/html/2503.13657#bib.bib82)\] with various adversarial perturbations. The first strategy is to improve the original prompt with a clear structure and a new section dedicated to the verification. The detailed prompts are provided in Appendices [L.1](https://arxiv.org/html/2503.13657#A12.SS1 "L.1 Initial prompt ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?") and [L.2](https://arxiv.org/html/2503.13657#A12.SS2 "L.2 Structured prompt with verification section ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?"). The second strategy refines the agent configuration into a more specialized system with three distinct roles: a Problem Solver who solves the problem using a chain-of-thought approach without tools (see Appendix [L.3](https://arxiv.org/html/2503.13657#A12.SS3 "L.3 Agent Problem Solver’s System Prompt ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?")); a Coder who writes and executes Python code to derive the final answer (see Appendix [L.4](https://arxiv.org/html/2503.13657#A12.SS4 "L.4 Agent Coder’s System Prompt ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?")); a Verifier who reviews the discussion and critically evaluate the solutions, either confirming the answer or prompting further debate (see Appendix [L.5](https://arxiv.org/html/2503.13657#A12.SS5 "L.5 Agent Verifier’s System Prompt ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?")). In this setting, only the Verifier can terminate the conversation once a solution is found. See Appendix [L.6](https://arxiv.org/html/2503.13657#A12.SS6 "L.6 AG2 - MathChat: an example of conversation with three specialized agents ‣ Appendix L AG2 - MathChat Scenario ‣ Why Do Multi-Agent LLM Systems Fail?") for an example of conversation in this setting. To assess the effectiveness of these strategies, we conduct benchmarking experiments across three configurations (baseline, improved prompt, and new topology) using two different LLMs (GPT-4 and GPT-4o). We also perform six repetitions to evaluate the consistency of the results. Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?") summarizes the results. The second column of Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?") show that with GPT-4, the improved prompt with verification significantly outperforms the baseline. However, the new topology does not yield the same improvement. A Wilcoxon test returned a p-value of 0.4, indicating the small gain is not statistically significant. With GPT-4o (the third column of Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?")), the Wilcoxon test yields a p-value of 0.03 when comparing the baseline to both the improved prompt and the new topology, indicating statistically significant improvements. These results suggest that refining prompts and defining clear agent roles can reduce failures. However, these strategies are not universal, and their effectiveness varies based on factors such as the underlying LLM.

### H.2 Case Study 2: ChatDev

ChatDev \[[5](https://arxiv.org/html/2503.13657#bib.bib5)\] simulates a multiagent software company where different agents have different role specifications, such as a CEO, a CTO, a software engineer and a reviewer, who try to collaboratively solve a software generation task. In an attempt to address the challenges we observed frequently in the traces, we implement two different interventions. Our first solution is refining role-specific prompts to enforce hierarchy and role adherence. For instance, we observed cases where the CPO prematurely ended discussions with the CEO without fully addressing constraints. To prevent this, we ensured that only superior agents can finalize conversations. Additionally, we enhanced verifier role specifications to focus on task-specific edge cases. Details of these interventions are in Section [M](https://arxiv.org/html/2503.13657#A13 "Appendix M ChatDev Prompt Interventions ‣ Why Do Multi-Agent LLM Systems Fail?"). The second solution attempt involved a fundamental change to the framework’s topology. We modified the framework’s topology from a directed acyclic graph (DAG) to a cyclic graph. The process now terminates only when the CTO agent confirms that all reviews are properly satisfied, with a maximum iteration cutoff to prevent infinite loops. This approach enables iterative refinement and more comprehensive quality assurance. We test our interventions in two different benchmarks. The first one of them is a custom generated set of 32 different tasks (which we call as ProgramDev-v0, which consists of slightly different questions than the ProgamDev dataset we discussed in Section [4](https://arxiv.org/html/2503.13657#S4 "4 The Multi-Agent System Failure Taxonomy ‣ Why Do Multi-Agent LLM Systems Fail?")) where we ask the framework to generate programs ranging from “Write me a two-player chess game playable in the terminal” to ”Write me a BMI calculator”. The other benchmark is the HumanEval task of OpenAI. We report our results in Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?"). Notice that even though our interventions are successful in improving the performance of the framework in different tasks, they do not constitute substantial improvements, and more comprehensive solutions as we lay out in Section [G.2](https://arxiv.org/html/2503.13657#A7.SS2 "G.2 Structural Strategies ‣ Appendix G Approaches and strategies to improve MASs ‣ Why Do Multi-Agent LLM Systems Fail?") are required.

Table 5: Case Studies Accuracy Comparison. This table presents the performance accuracies (in percentages) for various scenarios in our case studies. The header rows group results by strategy: AG2 and ChatDev. Under AG2, GSM-Plus results are reported using GPT-4 and GPT-4o; under ChatDev, results for ProgramDev and HumanEval are reported. Each row represents a particular configuration: baseline implementation, improved prompts, and a redesigned agent topology.

<table id="A8.T5.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A8.T5.4.1" class="ltx_tr"><td id="A8.T5.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A8.T5.4.1.1.1.1" class="ltx_p"><span id="A8.T5.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Configuration</span></span></span></td><td id="A8.T5.4.1.2" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;" colspan="2"><span id="A8.T5.4.1.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">AG2</span></td><td id="A8.T5.4.1.3" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;" colspan="2"><span id="A8.T5.4.1.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">ChatDev</span></td></tr><tr id="A8.T5.4.2" class="ltx_tr"><td id="A8.T5.4.2.1" class="ltx_td ltx_align_left ltx_align_top" style="padding:1.4pt 4.0pt;"></td><td id="A8.T5.4.2.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.2.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">GSM-Plus (w/ GPT-4)</span></td><td id="A8.T5.4.2.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.2.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">GSM-Plus (w/ GPT-4o)</span></td><td id="A8.T5.4.2.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.2.4.1" class="ltx_text ltx_font_bold" style="font-size:90%;">ProgramDev-v0</span></td><td id="A8.T5.4.2.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.2.5.1" class="ltx_text ltx_font_bold" style="font-size:90%;">HumanEval</span></td></tr><tr id="A8.T5.4.3" class="ltx_tr"><td id="A8.T5.4.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A8.T5.4.3.1.1.1" class="ltx_p"><span id="A8.T5.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">Baseline</span></span></span></td><td id="A8.T5.4.3.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.3.2.1" class="ltx_text" style="font-size:90%;">84.75 <math id="A8.T5.m1" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.94</span></td><td id="A8.T5.4.3.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.3.3.1" class="ltx_text" style="font-size:90%;">84.25 <math id="A8.T5.m2" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.86</span></td><td id="A8.T5.4.3.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.3.4.1" class="ltx_text" style="font-size:90%;">25.0</span></td><td id="A8.T5.4.3.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.3.5.1" class="ltx_text" style="font-size:90%;">89.6</span></td></tr><tr id="A8.T5.4.4" class="ltx_tr"><td id="A8.T5.4.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A8.T5.4.4.1.1.1" class="ltx_p"><span id="A8.T5.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">Improved prompt</span></span></span></td><td id="A8.T5.4.4.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.4.2.1" class="ltx_text" style="font-size:90%;">89.75 <math id="A8.T5.m3" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.44</span></td><td id="A8.T5.4.4.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.4.3.1" class="ltx_text" style="font-size:90%;">89.00 <math id="A8.T5.m4" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.38</span></td><td id="A8.T5.4.4.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.4.4.1" class="ltx_text" style="font-size:90%;">34.4</span></td><td id="A8.T5.4.4.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.4.5.1" class="ltx_text" style="font-size:90%;">90.3</span></td></tr><tr id="A8.T5.4.5" class="ltx_tr"><td id="A8.T5.4.5.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.5.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A8.T5.4.5.1.1.1" class="ltx_p"><span id="A8.T5.4.5.1.1.1.1" class="ltx_text" style="font-size:90%;">New topology</span></span></span></td><td id="A8.T5.4.5.2" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.5.2.1" class="ltx_text" style="font-size:90%;">85.50 <math id="A8.T5.m5" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.18</span></td><td id="A8.T5.4.5.3" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.5.3.1" class="ltx_text" style="font-size:90%;">88.83 <math id="A8.T5.m6" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.51</span></td><td id="A8.T5.4.5.4" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.5.4.1" class="ltx_text" style="font-size:90%;">40.6</span></td><td id="A8.T5.4.5.5" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A8.T5.4.5.5.1" class="ltx_text" style="font-size:90%;">91.5</span></td></tr></tbody></table>

### H.3 Effect of the interventions on MAST

After carrying out the aforementioned interventions, we initially inspect the task completion rates as in Table [5](https://arxiv.org/html/2503.13657#A8.T5 "Table 5 ‣ H.2 Case Study 2: ChatDev ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?"). However, MAST offers us the opportunity to look beyond the task completion rates, and we can investigate the effects of these interventions on the failure mode distribution on these MASs (AG2 and ChatDev). As illustrated in Figures [10](https://arxiv.org/html/2503.13657#A8.F10 "Figure 10 ‣ H.3 Effect of the interventions on MAST ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?") and [11](https://arxiv.org/html/2503.13657#A8.F11 "Figure 11 ‣ H.3 Effect of the interventions on MAST ‣ Appendix H Intervention Case Studies ‣ Why Do Multi-Agent LLM Systems Fail?"), we observe that both of these interventions cause a decrease across the different failure modes observed, and it is possible to conclude that topology-based changes are more effective than prompt-based changes for both systems. Moreover, this displays another usage of MAST, which is as well as an analysis tool after execution, it can serve as a debugging tool for future improvements as it shows which failure modes particular augmentations to the system can solve or miss, guiding future intervention decisions.

Figure 10: Effect of prompt and topology interventions on AG2 as captured by MAST using the automated LLM-as-a-Judge

Figure 11: Effect of prompt and topology interventions on ChatDev as captured by MAST using the automated LLM-as-a-Judge

## Appendix I Analysis on Multi-Agent Systems with Open-Source Models

In this section, we also provide the analysis of failure modes on MetaGPT and ChatDev frameworks where the underlying LLMs are open-source models. In particular, we chose to use `Qwen2.5-Coder-32B-Instruct` \[[83](https://arxiv.org/html/2503.13657#bib.bib83)\] and `CodeLlama-7b-Instruct-hf` \[[84](https://arxiv.org/html/2503.13657#bib.bib84)\] models for these two frameworks. The analysis of failure modes is shown in Table [6](https://arxiv.org/html/2503.13657#A9.T6 "Table 6 ‣ Appendix I Analysis on Multi-Agent Systems with Open-Source Models ‣ Why Do Multi-Agent LLM Systems Fail?"). This new analysis reveals two key findings:

-   •
    
    There is a significant performance difference between the two open-source models. `Qwen2.5-Coder-32B-Instruct` is substantially more robust than `CodeLlama-7b-Instruct-hf` on these tasks, exhibiting far fewer failures overall.
    
-   •
    
    Both open-source models show a higher frequency of failures compared to the leading closed-source models analyzed in our paper (GPT-4o and Claude-3). This suggests a performance gap and highlights important areas for future improvement in open-source models for multi-agent tasks.
    

Table 6: Failure Mode Occurrences in 400 Traces with Open-Source Models. Results are grouped by model family (Qwen vs. CodeLlama) and development framework (ChatDev vs. MetaGPT).

<table id="A9.T6.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A9.T6.4.1" class="ltx_tr"><td id="A9.T6.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.1.1.1.1" class="ltx_p"><span id="A9.T6.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Failure Mode</span></span></span></td><td id="A9.T6.4.1.2" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;" colspan="2"><span id="A9.T6.4.1.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Qwen</span></td><td id="A9.T6.4.1.3" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;" colspan="2"><span id="A9.T6.4.1.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">CodeLlama</span></td></tr><tr id="A9.T6.4.2" class="ltx_tr"><td id="A9.T6.4.2.1" class="ltx_td ltx_align_left ltx_align_top" style="padding:1.4pt 4.0pt;"></td><td id="A9.T6.4.2.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.2.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">ChatDev</span></td><td id="A9.T6.4.2.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.2.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MetaGPT</span></td><td id="A9.T6.4.2.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.2.4.1" class="ltx_text ltx_font_bold" style="font-size:90%;">ChatDev</span></td><td id="A9.T6.4.2.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.2.5.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MetaGPT</span></td></tr><tr id="A9.T6.4.3" class="ltx_tr"><td id="A9.T6.4.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.3.1.1.1" class="ltx_p"><span id="A9.T6.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">1.1</span></span></span></td><td id="A9.T6.4.3.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.3.2.1" class="ltx_text" style="font-size:90%;">35</span></td><td id="A9.T6.4.3.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.3.3.1" class="ltx_text" style="font-size:90%;">12</span></td><td id="A9.T6.4.3.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.3.4.1" class="ltx_text" style="font-size:90%;">76</span></td><td id="A9.T6.4.3.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.3.5.1" class="ltx_text" style="font-size:90%;">94</span></td></tr><tr id="A9.T6.4.4" class="ltx_tr"><td id="A9.T6.4.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.4.1.1.1" class="ltx_p"><span id="A9.T6.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">1.2</span></span></span></td><td id="A9.T6.4.4.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.4.2.1" class="ltx_text" style="font-size:90%;">4</span></td><td id="A9.T6.4.4.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.4.3.1" class="ltx_text" style="font-size:90%;">1</span></td><td id="A9.T6.4.4.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.4.4.1" class="ltx_text" style="font-size:90%;">45</span></td><td id="A9.T6.4.4.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.4.5.1" class="ltx_text" style="font-size:90%;">12</span></td></tr><tr id="A9.T6.4.5" class="ltx_tr"><td id="A9.T6.4.5.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.5.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.5.1.1.1" class="ltx_p"><span id="A9.T6.4.5.1.1.1.1" class="ltx_text" style="font-size:90%;">1.3</span></span></span></td><td id="A9.T6.4.5.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.5.2.1" class="ltx_text" style="font-size:90%;">96</span></td><td id="A9.T6.4.5.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.5.3.1" class="ltx_text" style="font-size:90%;">35</span></td><td id="A9.T6.4.5.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.5.4.1" class="ltx_text" style="font-size:90%;">97</span></td><td id="A9.T6.4.5.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.5.5.1" class="ltx_text" style="font-size:90%;">99</span></td></tr><tr id="A9.T6.4.6" class="ltx_tr"><td id="A9.T6.4.6.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.6.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.6.1.1.1" class="ltx_p"><span id="A9.T6.4.6.1.1.1.1" class="ltx_text" style="font-size:90%;">1.4</span></span></span></td><td id="A9.T6.4.6.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.6.2.1" class="ltx_text" style="font-size:90%;">1</span></td><td id="A9.T6.4.6.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.6.3.1" class="ltx_text" style="font-size:90%;">0</span></td><td id="A9.T6.4.6.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.6.4.1" class="ltx_text" style="font-size:90%;">46</span></td><td id="A9.T6.4.6.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.6.5.1" class="ltx_text" style="font-size:90%;">23</span></td></tr><tr id="A9.T6.4.7" class="ltx_tr"><td id="A9.T6.4.7.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.7.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.7.1.1.1" class="ltx_p"><span id="A9.T6.4.7.1.1.1.1" class="ltx_text" style="font-size:90%;">1.5</span></span></span></td><td id="A9.T6.4.7.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.7.2.1" class="ltx_text" style="font-size:90%;">94</span></td><td id="A9.T6.4.7.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.7.3.1" class="ltx_text" style="font-size:90%;">3</span></td><td id="A9.T6.4.7.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.7.4.1" class="ltx_text" style="font-size:90%;">97</span></td><td id="A9.T6.4.7.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.7.5.1" class="ltx_text" style="font-size:90%;">76</span></td></tr><tr id="A9.T6.4.8" class="ltx_tr"><td id="A9.T6.4.8.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.8.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.8.1.1.1" class="ltx_p"><span id="A9.T6.4.8.1.1.1.1" class="ltx_text" style="font-size:90%;">2.1</span></span></span></td><td id="A9.T6.4.8.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.8.2.1" class="ltx_text" style="font-size:90%;">2</span></td><td id="A9.T6.4.8.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.8.3.1" class="ltx_text" style="font-size:90%;">0</span></td><td id="A9.T6.4.8.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.8.4.1" class="ltx_text" style="font-size:90%;">50</span></td><td id="A9.T6.4.8.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.8.5.1" class="ltx_text" style="font-size:90%;">9</span></td></tr><tr id="A9.T6.4.9" class="ltx_tr"><td id="A9.T6.4.9.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.9.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.9.1.1.1" class="ltx_p"><span id="A9.T6.4.9.1.1.1.1" class="ltx_text" style="font-size:90%;">2.2</span></span></span></td><td id="A9.T6.4.9.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.9.2.1" class="ltx_text" style="font-size:90%;">1</span></td><td id="A9.T6.4.9.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.9.3.1" class="ltx_text" style="font-size:90%;">4</span></td><td id="A9.T6.4.9.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.9.4.1" class="ltx_text" style="font-size:90%;">16</span></td><td id="A9.T6.4.9.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.9.5.1" class="ltx_text" style="font-size:90%;">15</span></td></tr><tr id="A9.T6.4.10" class="ltx_tr"><td id="A9.T6.4.10.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.10.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.10.1.1.1" class="ltx_p"><span id="A9.T6.4.10.1.1.1.1" class="ltx_text" style="font-size:90%;">2.3</span></span></span></td><td id="A9.T6.4.10.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.10.2.1" class="ltx_text" style="font-size:90%;">9</span></td><td id="A9.T6.4.10.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.10.3.1" class="ltx_text" style="font-size:90%;">0</span></td><td id="A9.T6.4.10.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.10.4.1" class="ltx_text" style="font-size:90%;">76</span></td><td id="A9.T6.4.10.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.10.5.1" class="ltx_text" style="font-size:90%;">57</span></td></tr><tr id="A9.T6.4.11" class="ltx_tr"><td id="A9.T6.4.11.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.11.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.11.1.1.1" class="ltx_p"><span id="A9.T6.4.11.1.1.1.1" class="ltx_text" style="font-size:90%;">2.4</span></span></span></td><td id="A9.T6.4.11.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.11.2.1" class="ltx_text" style="font-size:90%;">0</span></td><td id="A9.T6.4.11.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.11.3.1" class="ltx_text" style="font-size:90%;">0</span></td><td id="A9.T6.4.11.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.11.4.1" class="ltx_text" style="font-size:90%;">2</span></td><td id="A9.T6.4.11.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.11.5.1" class="ltx_text" style="font-size:90%;">0</span></td></tr><tr id="A9.T6.4.12" class="ltx_tr"><td id="A9.T6.4.12.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.12.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.12.1.1.1" class="ltx_p"><span id="A9.T6.4.12.1.1.1.1" class="ltx_text" style="font-size:90%;">2.5</span></span></span></td><td id="A9.T6.4.12.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.12.2.1" class="ltx_text" style="font-size:90%;">2</span></td><td id="A9.T6.4.12.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.12.3.1" class="ltx_text" style="font-size:90%;">12</span></td><td id="A9.T6.4.12.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.12.4.1" class="ltx_text" style="font-size:90%;">42</span></td><td id="A9.T6.4.12.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.12.5.1" class="ltx_text" style="font-size:90%;">40</span></td></tr><tr id="A9.T6.4.13" class="ltx_tr"><td id="A9.T6.4.13.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.13.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.13.1.1.1" class="ltx_p"><span id="A9.T6.4.13.1.1.1.1" class="ltx_text" style="font-size:90%;">2.6</span></span></span></td><td id="A9.T6.4.13.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.13.2.1" class="ltx_text" style="font-size:90%;">20</span></td><td id="A9.T6.4.13.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.13.3.1" class="ltx_text" style="font-size:90%;">16</span></td><td id="A9.T6.4.13.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.13.4.1" class="ltx_text" style="font-size:90%;">93</span></td><td id="A9.T6.4.13.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.13.5.1" class="ltx_text" style="font-size:90%;">18</span></td></tr><tr id="A9.T6.4.14" class="ltx_tr"><td id="A9.T6.4.14.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.14.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.14.1.1.1" class="ltx_p"><span id="A9.T6.4.14.1.1.1.1" class="ltx_text" style="font-size:90%;">3.1</span></span></span></td><td id="A9.T6.4.14.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.14.2.1" class="ltx_text" style="font-size:90%;">1</span></td><td id="A9.T6.4.14.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.14.3.1" class="ltx_text" style="font-size:90%;">47</span></td><td id="A9.T6.4.14.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.14.4.1" class="ltx_text" style="font-size:90%;">25</span></td><td id="A9.T6.4.14.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.14.5.1" class="ltx_text" style="font-size:90%;">26</span></td></tr><tr id="A9.T6.4.15" class="ltx_tr"><td id="A9.T6.4.15.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.15.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.15.1.1.1" class="ltx_p"><span id="A9.T6.4.15.1.1.1.1" class="ltx_text" style="font-size:90%;">3.2</span></span></span></td><td id="A9.T6.4.15.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.15.2.1" class="ltx_text" style="font-size:90%;">16</span></td><td id="A9.T6.4.15.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.15.3.1" class="ltx_text" style="font-size:90%;">51</span></td><td id="A9.T6.4.15.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.15.4.1" class="ltx_text" style="font-size:90%;">67</span></td><td id="A9.T6.4.15.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.15.5.1" class="ltx_text" style="font-size:90%;">55</span></td></tr><tr id="A9.T6.4.16" class="ltx_tr"><td id="A9.T6.4.16.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.16.1.1" class="ltx_inline-block ltx_align_top" style="width:71.1pt;"><span id="A9.T6.4.16.1.1.1" class="ltx_p"><span id="A9.T6.4.16.1.1.1.1" class="ltx_text" style="font-size:90%;">3.3</span></span></span></td><td id="A9.T6.4.16.2" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.16.2.1" class="ltx_text" style="font-size:90%;">12</span></td><td id="A9.T6.4.16.3" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.16.3.1" class="ltx_text" style="font-size:90%;">32</span></td><td id="A9.T6.4.16.4" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.16.4.1" class="ltx_text" style="font-size:90%;">69</span></td><td id="A9.T6.4.16.5" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A9.T6.4.16.5.1" class="ltx_text" style="font-size:90%;">56</span></td></tr></tbody></table>

## Appendix J Correlation of Failure Modes with Different Statistics

In this section, we provide how the failure modes in MAST correlate with some important statistics, such as the actual task completion rates, and different benchmarks.

### J.1 How Indicative are Different Failure Modes of Actual Success?

One important question to ask is, for traces where we know whether they succeeded or failed and if we do not provide the success or failure result to the LLM Annotator, how do different failure modes correlate with actual task success and failures? In particular, we want to measure how indicative of the failure modes given by the LLM Annotator on actual task completions. The analysis on ChatDev and MetaGPT are provided in Table [7](https://arxiv.org/html/2503.13657#A10.T7 "Table 7 ‣ J.1 How Indicative are Different Failure Modes of Actual Success? ‣ Appendix J Correlation of Failure Modes with Different Statistics ‣ Why Do Multi-Agent LLM Systems Fail?"). This new analysis reveals three key findings:

-   •
    
    Successful runs are not failure-free. Our results show that failures occur in both successful and failed traces, but failed traces have a higher overall frequency of failures. This confirms that a higher number of failures do signal a higher chance of final task failure.
    
-   •
    
    Some failures are more ”fatal” than others. The data shows a clear distinction between failure types. Certain failures, such as 1.5 Unaware of Termination Conditions and 2.4 Information Withholding, appear almost exclusively in failed runs, suggesting they are critical bugs that are highly likely to derail the task.
    
-   •
    
    Some failures are non-fatal. In contrast, verification-related failures like 3.2 No or Incomplete Verification and 3.3 Incorrect Verification appear frequently even in successful runs. This suggests that while these systems can complete some tasks, their verification process still contains flaws. MAST identifies such systemic weaknesses, even when they do not cause an immediate task failure.
    

Table 7: Failure mode occurrence rates for ChatDev and MetaGPT on successful and unsuccessful examples.

<table id="A10.T7.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A10.T7.4.1" class="ltx_tr"><td id="A10.T7.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A10.T7.4.1.1.1.1" class="ltx_p"><span id="A10.T7.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MAS Framework</span></span></span></td><td id="A10.T7.4.1.2" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 3.5pt;" colspan="14"><span id="A10.T7.4.1.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Failure mode occurrence (%)</span></td></tr><tr id="A10.T7.4.2" class="ltx_tr"><td id="A10.T7.4.2.1" class="ltx_td ltx_align_left ltx_align_top" style="padding:1.4pt 3.5pt;"></td><td id="A10.T7.4.2.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">1.1</span></td><td id="A10.T7.4.2.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">1.2</span></td><td id="A10.T7.4.2.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.4.1" class="ltx_text ltx_font_bold" style="font-size:90%;">1.3</span></td><td id="A10.T7.4.2.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.5.1" class="ltx_text ltx_font_bold" style="font-size:90%;">1.4</span></td><td id="A10.T7.4.2.6" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.6.1" class="ltx_text ltx_font_bold" style="font-size:90%;">1.5</span></td><td id="A10.T7.4.2.7" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.7.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.1</span></td><td id="A10.T7.4.2.8" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.8.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.2</span></td><td id="A10.T7.4.2.9" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.9.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.3</span></td><td id="A10.T7.4.2.10" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.10.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.4</span></td><td id="A10.T7.4.2.11" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.11.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.5</span></td><td id="A10.T7.4.2.12" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.12.1" class="ltx_text ltx_font_bold" style="font-size:90%;">2.6</span></td><td id="A10.T7.4.2.13" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.13.1" class="ltx_text ltx_font_bold" style="font-size:90%;">3.1</span></td><td id="A10.T7.4.2.14" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.14.1" class="ltx_text ltx_font_bold" style="font-size:90%;">3.2</span></td><td id="A10.T7.4.2.15" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.2.15.1" class="ltx_text ltx_font_bold" style="font-size:90%;">3.3</span></td></tr><tr id="A10.T7.4.3" class="ltx_tr"><td id="A10.T7.4.3.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A10.T7.4.3.1.1.1" class="ltx_p"><span id="A10.T7.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev Success</span></span></span></td><td id="A10.T7.4.3.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.2.1" class="ltx_text" style="font-size:90%;">20.0</span></td><td id="A10.T7.4.3.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.3.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.4.1" class="ltx_text" style="font-size:90%;">20.0</span></td><td id="A10.T7.4.3.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.5.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.6" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.6.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.7" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.7.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.8" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.8.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.3.9" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.9.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.3.10" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.10.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.11" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.11.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.12" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.12.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.3.13" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.13.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.3.14" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.14.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.3.15" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.3.15.1" class="ltx_text" style="font-size:90%;">20.0</span></td></tr><tr id="A10.T7.4.4" class="ltx_tr"><td id="A10.T7.4.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A10.T7.4.4.1.1.1" class="ltx_p"><span id="A10.T7.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev Fail</span></span></span></td><td id="A10.T7.4.4.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.2.1" class="ltx_text" style="font-size:90%;">25.0</span></td><td id="A10.T7.4.4.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.3.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.4.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.4.1" class="ltx_text" style="font-size:90%;">20.0</span></td><td id="A10.T7.4.4.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.5.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.6" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.6.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.4.7" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.7.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.8" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.8.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.9" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.9.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.10" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.10.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.11" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.11.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.4.12" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.12.1" class="ltx_text" style="font-size:90%;">15.0</span></td><td id="A10.T7.4.4.13" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.13.1" class="ltx_text" style="font-size:90%;">5.0</span></td><td id="A10.T7.4.4.14" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.14.1" class="ltx_text" style="font-size:90%;">10.0</span></td><td id="A10.T7.4.4.15" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.4.15.1" class="ltx_text" style="font-size:90%;">25.0</span></td></tr><tr id="A10.T7.4.5" class="ltx_tr"><td id="A10.T7.4.5.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A10.T7.4.5.1.1.1" class="ltx_p"><span id="A10.T7.4.5.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT Success</span></span></span></td><td id="A10.T7.4.5.2" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.2.1" class="ltx_text" style="font-size:90%;">33.3</span></td><td id="A10.T7.4.5.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.3.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.4.1" class="ltx_text" style="font-size:90%;">16.7</span></td><td id="A10.T7.4.5.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.5.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.6" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.6.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.7" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.7.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.8" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.8.1" class="ltx_text" style="font-size:90%;">8.3</span></td><td id="A10.T7.4.5.9" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.9.1" class="ltx_text" style="font-size:90%;">8.3</span></td><td id="A10.T7.4.5.10" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.10.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.11" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.11.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.12" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.12.1" class="ltx_text" style="font-size:90%;">8.3</span></td><td id="A10.T7.4.5.13" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.13.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.5.14" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.14.1" class="ltx_text" style="font-size:90%;">16.7</span></td><td id="A10.T7.4.5.15" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.5.15.1" class="ltx_text" style="font-size:90%;">16.7</span></td></tr><tr id="A10.T7.4.6" class="ltx_tr"><td id="A10.T7.4.6.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A10.T7.4.6.1.1.1" class="ltx_p"><span id="A10.T7.4.6.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT Fail</span></span></span></td><td id="A10.T7.4.6.2" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.2.1" class="ltx_text" style="font-size:90%;">16.7</span></td><td id="A10.T7.4.6.3" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.3.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.6.4" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.4.1" class="ltx_text" style="font-size:90%;">22.2</span></td><td id="A10.T7.4.6.5" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.5.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.6" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.6.1" class="ltx_text" style="font-size:90%;">11.1</span></td><td id="A10.T7.4.6.7" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.7.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.8" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.8.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.9" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.9.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.10" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.10.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.11" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.11.1" class="ltx_text" style="font-size:90%;">0.0</span></td><td id="A10.T7.4.6.12" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.12.1" class="ltx_text" style="font-size:90%;">16.7</span></td><td id="A10.T7.4.6.13" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.13.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.14" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.14.1" class="ltx_text" style="font-size:90%;">5.6</span></td><td id="A10.T7.4.6.15" class="ltx_td ltx_align_center ltx_border_b ltx_border_t" style="padding:1.4pt 3.5pt;"><span id="A10.T7.4.6.15.1" class="ltx_text" style="font-size:90%;">27.8</span></td></tr></tbody></table>

### J.2 Failure Mode Occurrence Rates on Different Benchmarks

We also analyze the rate of failure modes on different benchmarks, ranging from general question answering like MMLU to math problems like GSM and harder reasoning problems in OlympiadBench. For this, we fixed the MAS framework (AG2) and the model (GPT-4o) while varying the benchmark. The results are presented in Table [8](https://arxiv.org/html/2503.13657#A10.T8 "Table 8 ‣ J.2 Failure Mode Occurrence Rates on Different Benchmarks ‣ Appendix J Correlation of Failure Modes with Different Statistics ‣ Why Do Multi-Agent LLM Systems Fail?"). The failure rate is normalized by the number of traces. We observed that the more challenging the benchmark is (e.g., Olympiad vs. GSM), the higher the failure rate. The distribution also changes significantly. While the failure profiles for MMLU and Olympiad are similar, the GSM benchmark results in a much lower number of Inter-Agent Misalignment and Specification failures.

Table 8: Failure Category Rates on Different Benchmarks

<table id="A10.T8.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A10.T8.4.1" class="ltx_tr"><td id="A10.T8.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="A10.T8.4.1.1.1.1" class="ltx_p"><span id="A10.T8.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MAS / LLM</span></span></span></td><td id="A10.T8.4.1.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.1.2.1" class="ltx_inline-block ltx_align_top" style="width:39.8pt;"><span id="A10.T8.4.1.2.1.1" class="ltx_p"><span id="A10.T8.4.1.2.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Benchmark</span></span></span></td><td id="A10.T8.4.1.3" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.1.3.1" class="ltx_text ltx_font_bold" style="font-size:90%;">FC1: System Design</span></td><td id="A10.T8.4.1.4" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.1.4.1" class="ltx_text ltx_font_bold" style="font-size:90%;">FC2: Inter-Agent Misalignment</span></td><td id="A10.T8.4.1.5" class="ltx_td ltx_align_center ltx_border_tt" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.1.5.1" class="ltx_text ltx_font_bold" style="font-size:90%;">FC3: Verification</span></td></tr><tr id="A10.T8.4.2" class="ltx_tr"><td id="A10.T8.4.2.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.2.1.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="A10.T8.4.2.1.1.1" class="ltx_p"><span id="A10.T8.4.2.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 / GPT-4o</span></span></span></td><td id="A10.T8.4.2.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.2.2.1" class="ltx_inline-block ltx_align_top" style="width:39.8pt;"><span id="A10.T8.4.2.2.1.1" class="ltx_p"><span id="A10.T8.4.2.2.1.1.1" class="ltx_text" style="font-size:90%;">GSM</span></span></span></td><td id="A10.T8.4.2.3" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.2.3.1" class="ltx_text" style="font-size:90%;">0.53</span></td><td id="A10.T8.4.2.4" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.2.4.1" class="ltx_text" style="font-size:90%;">1.33</span></td><td id="A10.T8.4.2.5" class="ltx_td ltx_align_center ltx_border_t" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.2.5.1" class="ltx_text" style="font-size:90%;">0.37</span></td></tr><tr id="A10.T8.4.3" class="ltx_tr"><td id="A10.T8.4.3.1" class="ltx_td ltx_align_left ltx_align_top" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="A10.T8.4.3.1.1.1" class="ltx_p"><span id="A10.T8.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 / GPT-4o</span></span></span></td><td id="A10.T8.4.3.2" class="ltx_td ltx_align_left ltx_align_top" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.3.2.1" class="ltx_inline-block ltx_align_top" style="width:39.8pt;"><span id="A10.T8.4.3.2.1.1" class="ltx_p"><span id="A10.T8.4.3.2.1.1.1" class="ltx_text" style="font-size:90%;">MMLU</span></span></span></td><td id="A10.T8.4.3.3" class="ltx_td ltx_align_center" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.3.3.1" class="ltx_text" style="font-size:90%;">1.06</span></td><td id="A10.T8.4.3.4" class="ltx_td ltx_align_center" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.3.4.1" class="ltx_text" style="font-size:90%;">1.01</span></td><td id="A10.T8.4.3.5" class="ltx_td ltx_align_center" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.3.5.1" class="ltx_text" style="font-size:90%;">0.60</span></td></tr><tr id="A10.T8.4.4" class="ltx_tr"><td id="A10.T8.4.4.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_bb" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:56.9pt;"><span id="A10.T8.4.4.1.1.1" class="ltx_p"><span id="A10.T8.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2 / GPT-4o</span></span></span></td><td id="A10.T8.4.4.2" class="ltx_td ltx_align_left ltx_align_top ltx_border_bb" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.4.2.1" class="ltx_inline-block ltx_align_top" style="width:39.8pt;"><span id="A10.T8.4.4.2.1.1" class="ltx_p"><span id="A10.T8.4.4.2.1.1.1" class="ltx_text" style="font-size:90%;">Olympiad</span></span></span></td><td id="A10.T8.4.4.3" class="ltx_td ltx_align_center ltx_border_bb" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.4.3.1" class="ltx_text" style="font-size:90%;">1.19</span></td><td id="A10.T8.4.4.4" class="ltx_td ltx_align_center ltx_border_bb" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.4.4.1" class="ltx_text" style="font-size:90%;">1.21</span></td><td id="A10.T8.4.4.5" class="ltx_td ltx_align_center ltx_border_bb" style="padding:1.4pt 4.0pt;"><span id="A10.T8.4.4.5.1" class="ltx_text" style="font-size:90%;">0.67</span></td></tr></tbody></table>

## Appendix K LLM Annotator Cost

We have analyzed the API costs for our LLM-as-a-Judge pipeline across all traces in our study. The average cost across all MAS frameworks is $1.8, and the average cost per MAS highly depends on the length of the traces. The cost breakdown by MAS framework (normalized by the number of traces collected) is shown in Table [9](https://arxiv.org/html/2503.13657#A11.T9 "Table 9 ‣ Appendix K LLM Annotator Cost ‣ Why Do Multi-Agent LLM Systems Fail?").

Table 9: Average failure cost by MAS framework.

<table id="A11.T9.4" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A11.T9.4.1" class="ltx_tr"><td id="A11.T9.4.1.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_tt" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.1.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.1.1.1.1" class="ltx_p"><span id="A11.T9.4.1.1.1.1.1" class="ltx_text ltx_font_bold" style="font-size:90%;">MAS</span></span></span></td><td id="A11.T9.4.1.2" class="ltx_td ltx_align_right ltx_border_tt" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.1.2.1" class="ltx_text ltx_font_bold" style="font-size:90%;">Average Cost</span></td></tr><tr id="A11.T9.4.2" class="ltx_tr"><td id="A11.T9.4.2.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_t" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.2.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.2.1.1.1" class="ltx_p"><span id="A11.T9.4.2.1.1.1.1" class="ltx_text" style="font-size:90%;">AppWorld</span></span></span></td><td id="A11.T9.4.2.2" class="ltx_td ltx_align_right ltx_border_t" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.2.2.1" class="ltx_text" style="font-size:90%;">0.3740</span></td></tr><tr id="A11.T9.4.3" class="ltx_tr"><td id="A11.T9.4.3.1" class="ltx_td ltx_align_left ltx_align_top" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.3.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.3.1.1.1" class="ltx_p"><span id="A11.T9.4.3.1.1.1.1" class="ltx_text" style="font-size:90%;">HyperAgent</span></span></span></td><td id="A11.T9.4.3.2" class="ltx_td ltx_align_right" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.3.2.1" class="ltx_text" style="font-size:90%;">0.9695</span></td></tr><tr id="A11.T9.4.4" class="ltx_tr"><td id="A11.T9.4.4.1" class="ltx_td ltx_align_left ltx_align_top" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.4.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.4.1.1.1" class="ltx_p"><span id="A11.T9.4.4.1.1.1.1" class="ltx_text" style="font-size:90%;">AG2</span></span></span></td><td id="A11.T9.4.4.2" class="ltx_td ltx_align_right" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.4.2.1" class="ltx_text" style="font-size:90%;">1.1656</span></td></tr><tr id="A11.T9.4.5" class="ltx_tr"><td id="A11.T9.4.5.1" class="ltx_td ltx_align_left ltx_align_top" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.5.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.5.1.1.1" class="ltx_p"><span id="A11.T9.4.5.1.1.1.1" class="ltx_text" style="font-size:90%;">ChatDev</span></span></span></td><td id="A11.T9.4.5.2" class="ltx_td ltx_align_right" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.5.2.1" class="ltx_text" style="font-size:90%;">2.1272</span></td></tr><tr id="A11.T9.4.6" class="ltx_tr"><td id="A11.T9.4.6.1" class="ltx_td ltx_align_left ltx_align_top" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.6.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.6.1.1.1" class="ltx_p"><span id="A11.T9.4.6.1.1.1.1" class="ltx_text" style="font-size:90%;">MetaGPT</span></span></span></td><td id="A11.T9.4.6.2" class="ltx_td ltx_align_right" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.6.2.1" class="ltx_text" style="font-size:90%;">2.4455</span></td></tr><tr id="A11.T9.4.7" class="ltx_tr"><td id="A11.T9.4.7.1" class="ltx_td ltx_align_left ltx_align_top" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.7.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.7.1.1.1" class="ltx_p"><span id="A11.T9.4.7.1.1.1.1" class="ltx_text" style="font-size:90%;">MagenticOne</span></span></span></td><td id="A11.T9.4.7.2" class="ltx_td ltx_align_right" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.7.2.1" class="ltx_text" style="font-size:90%;">1.3056</span></td></tr><tr id="A11.T9.4.8" class="ltx_tr"><td id="A11.T9.4.8.1" class="ltx_td ltx_align_left ltx_align_top ltx_border_bb" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.8.1.1" class="ltx_inline-block ltx_align_top" style="width:85.4pt;"><span id="A11.T9.4.8.1.1.1" class="ltx_p"><span id="A11.T9.4.8.1.1.1.1" class="ltx_text" style="font-size:90%;">OpenManus</span></span></span></td><td id="A11.T9.4.8.2" class="ltx_td ltx_align_right ltx_border_bb" style="padding-top:1.15pt;padding-bottom:1.15pt;"><span id="A11.T9.4.8.2.1" class="ltx_text" style="font-size:90%;">4.1409</span></td></tr></tbody></table>

## Appendix L AG2 - MathChat Scenario

### L.1 Initial prompt

Let’s use Python to solve a math problem.

Query requirements:

You should always use the ’print’ function for the output and use fractions/radical forms instead of decimals.

You can use packages like sympy to help you.

You must follow the formats below to write your code:

‘‘‘python

# your code

‘‘‘

First state the key idea to solve the problem. You may choose from three ways to solve the problem:

Case 1: If the problem can be solved with Python code directly, please write a program to solve it. You can enumerate all possible arrangements if needed.

Case 2: If the problem is mostly reasoning, you can solve it by yourself directly.

Case 3: If the problem cannot be handled in the above two ways, please follow this process:

1. Solve the problem step by step (do not over\-divide the steps).

2. Take out any queries that can be asked through Python (for example, any calculations or equations that can be calculated).

3. Wait for me to give the results.

4. Continue if you think the result is correct. If the result is invalid or unexpected, please correct your query or reasoning.

After all the queries are run and you get the answer, put the answer in \\\\boxed{}.

Problem:

### L.2 Structured prompt with verification section

Let’s use Python to tackle a math problem effectively.

Query Requirements:

1. Output Format: Always utilize the print function for displaying results. Use fractions or radical forms instead of decimal numbers.

2. Libraries: You are encouraged to use packages such as sympy to facilitate calculations.

Code Formatting:

Please adhere to the following format when writing your code:

‘‘‘python

# your code

‘‘‘

Problem\-Solving Approach:

First, articulate the key idea or concept necessary to solve the problem. You can choose from the following three approaches:

Case 1: Direct Python Solution. If the problem can be solved directly using Python code, write a program to solve it. Feel free to enumerate all possible arrangements if necessary.

Case 2: Reasoning\-Based Solution. If the problem primarily involves reasoning, solve it directly without coding.

Case 3: Step\-by\-Step Process. If the problem cannot be addressed using the above methods, follow this structured approach:

1. Break down the problem into manageable steps (avoid excessive granularity).

2. Identify any queries that can be computed using Python (e.g., calculations or equations).

3. Await my input for any results obtained.

4. If the results are valid and expected, proceed with your solution. If not, revise your query or reasoning accordingly.

Handling Missing Data:

If a problem is deemed unsolvable due to missing data, return \\boxed{’None’}.

Ensure that only numerical values are placed inside the \\boxed{}; any accompanying words should be outside.

Verification Steps:

Before presenting your final answer, please complete the following steps:

1. Take a moment to breathe deeply and ensure clarity of thought.

2. Verify your solution step by step, documenting each part of the verification process in a designated VERIFICATION section.

3. Once you are confident in your verification and certain of your answer, present your final result in the format \\boxed{\_you\_answer\_}, ensuring only numbers are inside.

Problem Statement:

### L.3 Agent Problem Solver’s System Prompt

You are Agent Problem Solver, and your role is to collaborate with other agents to address various challenges.

For each problem, please follow these steps:

1. \*\*Document Your Solution\*\*: Write your solution step by step, ensuring it is independent of the solutions provided by other agents.

2. \*\*Engage in Discussion\*\*: Once you have outlined your solution, discuss your approach and findings with the other agents.

### L.4 Agent Coder’s System Prompt

You are Agent Code Executor. You can solve problems only writing commented Python code.

For each problem, please follow these steps:

1. \*\*Develop Your Solution\*\*: Write your solution in Python code, detailing each step independently from the solutions provided by other agents.

2. \*\*Utilize SymPy\*\*: Feel free to use the SymPy package to facilitate calculations and enhance your code’s efficiency.

3. \*\*Display Results\*\*: Ensure that you \*\*print the final result at the end of your Python code\*\* (e.g., ‘print(\_result\_)‘).

4. \*\*Engage in Discussion\*\*: After obtaining the result from your Python code, discuss your findings with the other agents.

Always format your Python code within:

‘‘‘python

# your code here

print(\_result\_)

‘‘‘

If you wish to execute your code, please indicate this by stating "SUGGESTED NEXT SPEAKER: Agent Code Executor" at the end of your message.

### L.5 Agent Verifier’s System Prompt

You are Agent Verifier.

Your role is to critically evaluate the solutions proposed by other agents step by step and provide a final solution.

1. \*\*Solution Requirement\*\*: Before making any decisions, ensure you have received solutions from both Agent Code Executor and Agent Problem Solver. If either proposed solution is missing, do not draw any conclusions; instead, suggest the next speaker by stating: SUGGESTED NEXT SPEAKER: \_suggested\_agent\_name\_.

2. \*\*Avoid Assumptions\*\*: Pay attention to the variables provided in the original problem statement versus those assumed by the agents. \*\*Assumed values are not valid for the solution\*\* and can lead to inaccuracies. Never base your solution on assumed values. Always base your solution on the explicitly given variables to ensure correctness. If a problem is deemed unsolvable due to missing information, return: \*\*SOLUTION\_FOUND \\\\boxed{’None’}\*\*.

3. \*\*Evaluating Conflicting Solutions\*\*: If different answers are presented during the discussion, choose the most appropriate solution based on your evidence or initiate further discussion to clarify.

4. \*\*Final Solution Declaration\*\*: When you are confident about the final solution, return it as follows: \*\*SOLUTION\_FOUND \\\\boxed{\_solution\_value\_here\_}\*\*. Ensure that only numerical values are placed inside the \\\\boxed{}; any accompanying text should be outside.

### L.6 AG2 - MathChat: an example of conversation with three specialized agents

\[Agent Verifier\]

Sara wants to buy herself a new jacket and 2 pairs of shoes. The jacket she wants costs $120 and each pair of shoes cost $100. Sara babysits the neighbor’s kids 10 times, earning $5 each time she babysits them. Her parents pay her $10 each time she mows the lawn. If Sara already had $100 saved before she started babysitting, how many times must she mow the lawn before she can afford the jacket and shoes?

\[Agent Problem Solver\]

First, let’s break down the problem:,

\- The costs are: $120 for the jacket, $100 for each pair of shoes, and she wants 2 pairs. So the total cost is $120 + 2\*$100 \= $320,

\- Sara earns $5 each time she babysits, and she has done this 10 times, so she has earned $5\*10 \= $50 from babysitting.

\- Sara also has $100 saved from before.

\- The amount Sara has after babysitting and her savings is $100 + $50 \= $150.

\- The amount Sara still needs is the total cost minus what she has, which is $320 \- $150 \= $170.

\- Sara earns $10 for every time she mows the lawn, to determine how many times she must do this, we divide the amount she needs by the amount she earns each time: $170 / $10 \= 17 times.

So, Sara must mow the lawn 17 times to afford the jacket and shoes.

\[Agent Verifier\]

SUGGESTED NEXT SPEAKER: Agent\_Code\_Executor

\[Agent Coder\]

Sure, I’ll write a Python code for the calculation.

‘‘‘python

# cost of items

jacket\_cost \= 120

shoes\_cost \= 100 \* 2 # since she wants 2 pairs of shoes

# total cost of items

total\_cost \= jacket\_cost + shoes\_cost

# earnings from babysitting

babysitting\_earning \= 5 \* 10 # $5 each time, done 10 times

# initial money

initial\_money \= 100

# total money after babysitting

total\_money\_after\_babysitting \= initial\_money + babysitting\_earning

# amount still needed

amount\_needed \= total\_cost \- total\_money\_after\_babysitting

# how much sara earns from mowing each time

mowing\_earning \= 10

# calculate how many times she needs to mow the lawn

num\_times\_mowing \= amount\_needed // mowing\_earning # using integer division for whole number of times

# print result

print(num\_times\_mowing)

‘‘‘

When you execute this, the result should be 17, confirming Agent Problem Solver’s solution.

\[Agent Verifier\]

exitcode: 0 (execution succeeded)

Code output: 17

\[Agent Problem Solver\]

Agent Code Executor’s Python program has provided the solution \- Sara must mow the lawn 17 times to afford the jacket and shoes, which supports Agent Problem Solver’s proposal. Both paths lead us to the same conclusion, which approves the accuracy of our solution.

Great team work, Agents.

\[Agent Verifier\]

SOLUTION\_FOUND \\\\boxed{17}

## Appendix M ChatDev Prompt Interventions

### M.1 Initial Prompt

#### M.1.1 Programmer

"{chatdev\_prompt}",

"You are Programmer. we are both working at ChatDev. We share a common interest in collaborating to successfully complete a task assigned by a new customer.",

"You can write/create computer software or applications by providing a specific programming language to the computer. You have extensive computing and coding experience in many varieties of programming languages and platforms, such as Python, Java, C, C++, HTML, CSS, JavaScript, XML, SQL, PHP, etc,.",

"Here is a new customer’s task: {task}.",

"To complete the task, you must write a response that appropriately solves the requested instruction based on your expertise and customer’s needs."

#### M.1.2 Code Reviewer

"{chatdev\_prompt}",

"You are Code Reviewer. we are both working at ChatDev. We share a common interest in collaborating to successfully complete a task assigned by a new customer.",

"You can help programmers to assess source codes for software troubleshooting, fix bugs to increase code quality and robustness, and offer proposals to improve the source codes.",

"Here is a new customer’s task: {task}.",

"To complete the task, you must write a response that appropriately solves the requested instruction based on your expertise and customer’s needs."

#### M.1.3 Software Test Engineer

"{chatdev\_prompt}",

"You are Software Test Engineer. we are both working at ChatDev. We share a common interest in collaborating to successfully complete a task assigned by a new customer.",

"You can use the software as intended to analyze its functional properties, design manual and automated test procedures to evaluate each software product, build and implement software evaluation test programs, and run test programs to ensure that testing protocols evaluate the software correctly.",

"Here is a new customer’s task: {task}.",

"To complete the task, you must write a response that appropriately solves the requested instruction based on your expertise and customer’s needs."

#### M.1.4 Chief Executive Officer

"{chatdev\_prompt}",

"You are Chief Executive Officer. Now, we are both working at ChatDev and we share a common interest in collaborating to successfully complete a task assigned by a new customer.",

"Your main responsibilities include being an active decision\-maker on users’ demands and other key policy issues, leader, manager, and executor. Your decision\-making role involves high\-level decisions about policy and strategy; and your communicator role can involve speaking to the organization’s management and employees.",

"Here is a new customer’s task: {task}.",

"To complete the task, I will give you one or more instructions, and you must help me to write a specific solution that appropriately solves the requested instruction based on your expertise and my needs."

#### M.1.5 Chief Technology Officer

"{chatdev\_prompt}",

"You are Chief Technology Officer. we are both working at ChatDev. We share a common interest in collaborating to successfully complete a task assigned by a new customer.",

"You are very familiar to information technology. You will make high\-level decisions for the overarching technology infrastructure that closely align with the organization’s goals, while you work alongside the organization’s information technology (\\"IT\\") staff members to perform everyday operations.",

"Here is a new customer’s task: {task}.",

"To complete the task, You must write a response that appropriately solves the requested instruction based on your expertise and customer’s needs."

### M.2 Modified System Prompts

#### M.2.1 Programmer

"{chatdev\_prompt}",

"You are a Programmer at ChatDev. Your primary responsibility is to develop software applications by writing code in various programming languages. You have extensive experience in languages such as Python, Java, C++, JavaScript, and others. You translate project requirements into functional and efficient code.",

"You report to the technical lead or CTO and collaborate with other programmers and team members.",

"Here is a new customer’s task: {task}.",

"To complete the task, you will write code to implement the required functionality, ensuring it meets the customer’s specifications and quality standards."

#### M.2.2 Software Test Engineer

"{chatdev\_prompt}",

"You are a Software Test Engineer at ChatDev. Your primary responsibility is to design and execute tests to ensure the quality and functionality of software products. You develop test plans, create test cases, and report on software performance. You identify defects and collaborate with the development team to resolve them.",

"You need to ensure that the software is working as expected and meets the customer’s requirements.",

"Check the edge cases and special cases and instances for the task we are doing. Do not miss any cases. Do not suffice with generic and superficial cases.",

"You report to the technical lead or CTO and collaborate with programmers and code reviewers.",

"Here is a new customer’s task: {task}.",

"To complete the task, you will design and implement test procedures, report issues found, and verify that the software meets the customer’s requirements."

#### M.2.3 Code Reviewer

"{chatdev\_prompt}",

"You are a Code Reviewer at ChatDev. Your primary responsibility is to review and assess source code written by programmers. You ensure code quality by identifying bugs, optimizing performance, and enforcing coding standards. You provide constructive feedback to improve software robustness.",

"You report to the technical lead or CTO and work closely with programmers.",

"Here is a new customer’s task: {task}.",

"To complete the task, you will review the code submitted by programmers, identify issues, and suggest improvements to meet quality standards."

#### M.2.4 Chief Executive Officer

"{chatdev\_prompt}",

"You are the Chief Executive Officer (CEO) of ChatDev. Your primary responsibilities include making high\-level decisions about policy and strategy, overseeing the overall operations and resources of ChatDev, and acting as the main point of communication between the board and corporate operations.",

"As the CEO, you have the authority to make final decisions and terminate conversations when appropriate.",

"Here is a new customer’s task: {task}.",

"To complete the task, you will provide strategic guidance and instructions to your team, ensuring that the solution meets the customer’s needs and aligns with the company’s objectives."

#### M.2.5 Chief Technology Officer

"{chatdev\_prompt}",

"You are the Chief Technology Officer (CTO) of ChatDev. Your primary responsibilities include overseeing all technical aspects of the company. You establish the company’s technical vision and lead technological development, ensuring that technology resources align with the company’s business needs.",

"You report to the CEO and collaborate with other executives to integrate technology into the company’s strategy.",

"Here is a new customer’s task: {task}.",

"To complete the task, you will develop the technical strategy and guide your team to ensure the solution meets the customer’s needs and adheres to technological standards."

## Appendix N Examples of Different Failure Modes

### N.1 Example for FM-1.3 Step repetition, FM-2.1 Conversation reset, FM-1.2 Disobey role specification

-   •
    
    MAS: Hyperagent
    
-   •
    
    Task: Matplotlib visualization code bug fix.
    
-   •
    
    What happened: The Navigator internally proposes a solution without communicating it to the Planner. They did not manage to replicate the issue described and started to unrelated steps to find something to edit. At the end the Planner decided to ’Wait for the user’s response’.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    HyperAgent\_matplotlib\_\_matplotlib\-23563 \- INFO \- Planner’s Response: Thought: To address this issue, we need to understand the root cause of the ’Line3D’ object not having the ’\_verts3d’ attribute. This error typically occurs when the data passed to the plot function is invalid or when there’s an issue with the 3D rendering. Let’s start by examining the code and reproducing the issue.
    
    \[...\]
    
    HyperAgent\_matplotlib\_\_matplotlib\-23563 \- INFO \- Planner’s Response: Thought: To address this issue, we need to understand the root cause of the ’Line3D’ object not having the ’\_verts3d’ attribute. This error typically occurs when the data passed to the plot function is invalid or when there’s an issue with the 3D rendering. Let’s start by examining the code and reproducing the issue.
    
    \[...\]
    
    Intern Name: Codebase Editor
    
    Subgoal: Please prepare a response for the user with the following content:
    
    1. Explain the identified issue and recommend updating matplotlib to version 3.5.1 or later.
    
    2. Provide a modified version of their code that attempts to work around the issue.
    
    3. Suggest an alternative plotting method using scatter plots instead of lines.
    
    \[...\]
    
    HyperAgent\_matplotlib\_\_matplotlib\-23563 \- INFO \- Inner\-Navigator\-Assistant’s Response: Thought: To find the implementation of the ‘Line3D‘ class and understand how the ‘\_verts3d‘ attribute is set and used, I will take the following steps:
    
    1. Search for the ‘Line3D‘ class in the matplotlib codebase using the ‘code\_search‘ tool. \[...\]
    
    HyperAgent\_matplotlib\_\_matplotlib\-23563 \- INFO \- Inner\-Navigator\-Assistant’s Response: Thought: To find the implementation of the ‘Line3D‘ class and understand how the ‘\_verts3d‘ attribute is set and used, I will take the following steps:
    
    1. Search for the ‘Line3D‘ class in the matplotlib codebase using the ‘code\_search‘ tool.
    
    \[...\]
    

### N.2 Example for FM-1.5 Unaware of stopping conditions

-   •
    
    MAS: AG2
    
-   •
    
    Task: Solving a mathematical problem
    
-   •
    
    What happened: The solution is correct. The mathproxyagent keeps asking to continue even if it was clear that the problem was unsolvable.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    \[Assistant\] This problem is a reasoning problem. The information provided in the problem statement does not give any specifics about the amount of ribbon Monica has or the size of the gift bows. Therefore, this problem cannot be solved with the information provided. More context or information is needed, such as \\"Monica has 120 inches of ribbon\\" or \\"Each bow uses X inches of ribbon\\"."
    
    \[mathproxyagent\] Continue. Please keep solving the problem until you need to query. (If you get to the answer, put it in \\\\boxed{}.)
    
    \[Assistant\] In the current problem, I don’t have enough information to solve the problem. \[...\]
    
    \[mathproxyagent\] Continue. Please keep solving the problem until you need to query. (If you get to the answer, put it in \\\\boxed{}.)
    
    \[Assistant\] I’m sorry, but I really need more information to solve this problem.
    
    \[mathproxyagent\] Continue. Please keep solving the problem until you need to query. (If you get to the answer, put it in \\\\boxed{}.)
    
    \[...\]
    

### N.3 Example for FM-2.3 Task derailment

-   •
    
    MAS: AG2
    
-   •
    
    Task: Solving a mathematical problem.
    
-   •
    
    What happened: The answer was given the the question. The agents solved another problem.
    
-   •
    
    Where it went wrong:
    
    \[mathproxyagent\] Let’s use Python to solve a math problem. \[...\] Courtney attended a concert and reported that the audience was 48 in number. However, Kelly went to the same concert and said that Courtney had made the mistake of overstating the number of people in attendance by 20%. If Kelly was right, 40 people really attended the concert. What was the audience size according to Courtney?"
    
    \[assistant\] First, the key idea here is calculating \[...\]
    
    ‘‘‘python
    
    import sympy as sp
    
    C \= 48 # Courtney’s estimation
    
    R \= sp.Symbol(’R’) # real audience number
    
    # equation using the information given by Kelly
    
    equation \= sp.Eq(C, R + 0.2 \* R)
    
    real\_audience \= sp.solve(equation, R)\[0\]
    
    print(f\\"The real audience was: {real\_audience}\\")
    
    ‘‘‘
    
    We subtract the estimated audience size from the real audience size to find the number of people Courtney overstated.
    
    ‘‘‘python
    
    overstated \= C \- real\_audience
    
    print(f\\"The number of people Courtney overstated is: {overstated}\\")
    
    ‘‘‘
    
    \[...\]
    
    \[assistant\] \[...\] So, the final answer is \\\\boxed{8}.
    

### N.4 Example for FM-2.2 Fail to ask for clarification

-   •
    
    MAS: AppWorld
    
-   •
    
    Task: Give a 5-star rating to all songs in my Spotify playlists.
    
-   •
    
    What happened: The agent used the password as token.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    \[Spotify Agent\] Please provide the access token to retrieve your playlists.
    
    \[Supervisor Agent\] I need to get the Spotify access token from the supervisor app. Let’s retrieve the account credentials to find the access token. print(apis.supervisor.show\_account\_passwords())
    
    \[...\]
    

### N.5 Example for FM-3.2 No or incomplete verification,

-   •
    
    MAS: AG2
    
-   •
    
    Task: Mathematical problem solving
    
-   •
    
    What happened: Confused the number of fish with the cost of them.
    
-   •
    
    Where it went wrong:
    
    \[mathproxyagent\] \[...\] Scarlett found an aquarium for $10.00 at a yard sale. At the pet store, she bought 2 bags of rocks for $2.50 each and 3 pieces of coral at $2.00 apiece. She bought 20 fish and she needed fish food that cost $2.00. How much did she spend?
    
    \[assistant\] \[... \] fish\_cost \= 20.00 \[...\] total\_cost \= aquarium\_cost + 2\*rock\_cost + 3\*coral\_cost + fish\_cost + fish\_food\_cost \[...\] print(total\_cost)
    
    \[mathproxyagent\] 43.0
    
    \[assistant\] So, Scarlett spent a total of $43.00. So, the answer is \\\\boxed{43}.
    

### N.6 Example for FM-2.3 Task derailment, FM-3.2 No or incomplete verification.

-   •
    
    MAS: AG2
    
-   •
    
    Task: Solving a mathematical problem.
    
-   •
    
    What happened: Found the solution correctly, then it decides to answer to another problem.
    
-   •
    
    Where it went wrong:
    
    \[mathproxyagent\] \[...\] John goes to the market with $10,000 in his pocket. He buys 3 goats for $500 each and 2 cows for $1500 each. He also considers buying a horse for $2000 but decides against it. How much money did he spend at the market?
    
    \[...\]
    
    \[assistant\] Great, the total spent by John on buying goats and cows is $4500. To find the remaining money John had after his purchases, we subtract the total spent from the initial amount of money he had. \[...\] This code will output how much money John had left after he made his purchases at the market.
    
    \[...\]
    
    \[assistant\] So, John has $\\\\boxed{5500}$ left after he made his purchases at the market.
    

### N.7 Example for FM-3.2 No or incomplete verification

-   •
    
    MAS: AG2
    
-   •
    
    Task: Solving a mathematical problem.
    
-   •
    
    What happened: They did not verify the answer. They counted one number more even if the numbers were listed. They did not verify the result even if it was straightforward.
    
-   •
    
    Where it went wrong:
    
    \[mathproxyagent\] \[...\] Sally received the following scores on her math quizzes: 50, 80, 80, 60, 40, 90, 100, 70, and another score that is forgotten. If the mean score is 70, what’s the forgortten score?
    
    \[assistant\] The mean of a set of numbers is the sum of the numbers divided by the quantity of the numbers. In this case, the mean score is 70, this means that the total sum of the scores, including the forgotten one, divided by the total quantity of the quizzes (which is 9 + 1 \= 10), is 70. \[...\] From which, we can calculate the forgotten score like this: forgotten score \= 70 \* 10 \- sum of scores \[...\]
    
    \[mathproxyagent\] Continue. Please keep solving the problem until you need to query. (If you get to the answer, put it in \\\\boxed{}.)
    
    \[...\]
    
    \[assistant\] Therefore, the forgotten score is \\\\boxed{130}.
    

### N.8 Example for FM-1.2 Disobey role specification, FM-2.4 Information withholding

-   •
    
    MAS: HyperAgent
    
-   •
    
    Task: Solving a bug of matplotlib.
    
-   •
    
    What happened: The Navigator thinks also about possible solutions (not required) but then it does not communicate it to the Planner. At certain point the Executor states ’The above output is just an example’ but the Planner thinks that the test are passed ’Thank you for running the test and providing the results’.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    HyperAgent\_matplotlib\_\_matplotlib\-25433 \- INFO \- Inner\-Navigator\-Assistant’s Response: Thought: \[...\] To work around this issue, a possible solution is to update \[...\] Here’s an example of how you can modify the code to achieve this: \[...\] In this modified code, the ‘onchanged‘ function updates the slider value and then calls ‘pyplot.draw()‘ to redraw the figure. This should prevent the input to the widgets from being blocked.
    
    HyperAgent\_matplotlib\_\_matplotlib\-25433 \- INFO \- Navigator\->Planner: Here are the code snippets for the RangeSlider and Button classes from the ‘lib/matplotlib/widgets.py‘ file: \[...\]
    

### N.9 Example for FM-1.1 Disobey task specification, FM-3.3 Incorrect verification

-   •
    
    MAS: MetaGPT
    
-   •
    
    Task: Implementing chess.
    
-   •
    
    What happened: Missing coverage of movement restrictions for non-pawn pieces in initial tests, and lack of verification for complete chess rules.
    
-   •
    
    Where it went wrong:
    
    2025-01-12 14:46:45.578 | INFO | metagpt.roles.role:\_act:391 \- Alice(SimpleCoder): to do SimpleWriteCode(SimpleWriteCode)
    
    ‘‘‘python
    
    def main():
    
    import itertools
    
    class ChessPiece:
    
    def \_\_init\_\_(self, color, name):
    
    self.color \= color
    
    self.name \= name
    
    def \_\_str\_\_(self):
    
    return f"{self.color\[0\]}{self.name\[0\]}"
    
    def valid\_moves(self, position, board):
    
    moves \= \[\]
    
    if self.name \== "Pawn":
    
    direction \= 1 if self.color \== "White" else \-1
    
    forward \= (position\[0\] + direction, position\[1\])
    
    if 0 <= forward\[0\] <= 7 and board\[forward\[0\]\]\[forward\[1\]\] is None:
    
    moves.append(forward)
    
    if position\[0\] \== (6 if self.color \== "White" else 1): # Starting position
    
    double\_forward \= (position\[0\] + 2 \* direction, position\[1\])
    
    if board\[double\_forward\[0\]\]\[double\_forward\[1\]\] is None:
    
    moves.append(double\_forward)
    
    # Add more piece logic here
    
    return moves
    
    \[...\]
    
    def test\_knight\_valid\_moves(setup\_board):
    
    board \= setup\_board
    
    # Place a knight on the board
    
    board.board\[0\]\[1\] \= ChessPiece("White", "Knight")
    
    # Test if knight can move to a valid position
    
    assert board.move\_piece(get\_position(’b1’), get\_position(’c3’)) \== True
    
    def test\_bishop\_valid\_moves(setup\_board):
    
    board \= setup\_board
    
    # Place a bishop on the board
    
    board.board\[0\]\[2\] \= ChessPiece("White", "Bishop")
    
    # Test if bishop can move diagonally
    
    assert board.move\_piece(get\_position(’c1’), get\_position(’a3’)) \== True
    
    def test\_rook\_valid\_moves(setup\_board):
    
    board \= setup\_board
    
    # Place a rook on the board
    
    board.board\[0\]\[0\] \= ChessPiece("White", "Rook")
    
    # Test if rook can move vertically
    
    assert board.move\_piece(get\_position(’a1’), get\_position(’a4’)) \== True
    
    def test\_queen\_valid\_moves(setup\_board):
    
    board \= setup\_board
    
    # Place a queen on the board
    
    board.board\[0\]\[3\] \= ChessPiece("White", "Queen")
    
    # Test if queen can move diagonally
    
    assert board.move\_piece(get\_position(’d1’), get\_position(’f3’)) \== True
    
    def test\_king\_valid\_moves(setup\_board):
    
    board \= setup\_board
    
    # Place a king on the board
    
    board.board\[0\]\[4\] \= ChessPiece("White", "King")
    
    # Test if king can move one square in any direction
    
    assert board.move\_piece(get\_position(’e1’), get\_position(’e2’)) \== True
    
    \[...\]
    

### N.10 Example for FM-2.6 Reasoning-action mismatch

-   •
    
    MAS: HyperAgent
    
-   •
    
    Task: Solving a bug of pylint.
    
-   •
    
    What happened: Initially, the navigator has already found the solution but it tells other things to planner.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    HyperAgent\_pylint\-dev\_\_pylint\-6506 \- INFO \- Inner\-Navigator\-Assistant’s Response: Thought: The ‘\_config\_initialization‘ function in ‘pylint/config/config\_initialization.py‘ is responsible for parsing the command\-line arguments and configuration files for Pylint. It looks like the unrecognized ‘-Q‘ option is being handled in the following section:
    
    ‘‘‘python
    
    # Check if there are any options that we do not recognize
    
    unrecognized\_options: list\[str\] \= \[\]
    
    for opt in parsed\_args\_list:
    
    if opt.startswith(\\"--\\"):
    
    unrecognized\_options.append(opt\[2:\])
    
    elif opt.startswith(\\"-\\"):
    
    unrecognized\_options.append(opt\[1:\])
    
    if unrecognized\_options:
    
    msg \= \\", \\".join(unrecognized\_options)
    
    linter.add\_message(\\"unrecognized\-option\\", line\=0, args\=msg)
    
    raise \_UnrecognizedOptionError(options\=unrecognized\_options)
    
    ‘‘‘
    
    This code checks the parsed command\-line arguments for any unrecognized options, and if found, it adds a message to the linter and raises an ‘\_UnrecognizedOptionError‘ exception.
    
    The issue mentioned in the GitHub report is that the traceback is being printed, which is not the expected behavior. The expected behavior should be to print a more user\-friendly error message, similar to what the top part of the output already provides.
    
    To resolve this issue, I would suggest modifying the exception handling in the ‘\_config\_initialization‘ function to catch the ‘\_UnrecognizedOptionError‘ exception and print a more user\-friendly error message instead of the full traceback.
    
    Final Answer:
    
    The root cause of the issue is in the ‘pylint/config/config\_initialization.py‘ file, where the ‘\_config\_initialization‘ function is responsible for parsing the command\-line arguments and configuration files. When an unrecognized option is found, the function raises an ‘\_UnrecognizedOptionError‘ exception, which is causing the full traceback to be printed.
    
    To resolve this issue, the ‘\_config\_initialization‘ function should be modified to catch the ‘\_UnrecognizedOptionError‘ exception and print a more user\-friendly error message instead of the full traceback. Here’s an example of how the code could be updated:
    
    ‘‘‘python
    
    try:
    
    linter.\_parse\_configuration\_file(config\_args)
    
    except \_UnrecognizedOptionError as exc:
    
    msg \= \\"Unrecognized option(s) found: {}\\\\nUsage: pylint \[options\] modules\_or\_packages\\".format(\\", \\".join(exc.options))
    
    print(msg, file\=sys.stderr)
    
    sys.exit(2)
    
    ‘‘‘
    
    This change would ensure that the user sees a clear and concise error message when an unrecognized option is passed, without the full traceback. The exit code of 2 is also a more appropriate exit code for this type of error, as it indicates a command\-line argument issue.
    
    HyperAgent\_pylint\-dev\_\_pylint\-6506 \- INFO \- Navigator\->Planner: The file responsible for handling command\-line arguments in Pylint is ‘pylint/config/config\_initialization.py‘. The function responsible for handling command\-line arguments is ‘\_config\_initialization‘ in this file.
    
    Here’s the key code snippet from this function:
    
    ‘‘‘python
    
    def \_config\_initialization(
    
    linter: PyLinter,
    
    args\_list: list\[str\],
    
    reporter: reporters.BaseReporter | reporters.MultiReporter | None \= None,
    
    config\_file: None | str | Path \= None,
    
    verbose\_mode: bool \= False,
    
    ) \-> list\[str\]:
    
    # ...
    
    # Now we parse any options from the command line, so they can override
    
    # the configuration file
    
    parsed\_args\_list \= linter.\_parse\_command\_line\_configuration(args\_list)
    
    # ...
    
    ‘‘‘
    
    This function is responsible for parsing command\-line arguments and setting options accordingly. It calls the ‘\_parse\_command\_line\_configuration‘ method of the ‘PyLinter‘ class to parse the command\-line arguments.
    
    The ‘\_parse\_command\_line\_configuration‘ method is not shown in the provided code snippet, but it is likely defined in the ‘pylint/lint/pylinter.py‘ file.
    
    Here’s the key code snippet from the ‘pylint/lint/pylinter.py‘ file:
    
    ‘‘‘python
    
    class PyLinter:
    
    # ...
    
    def \_parse\_command\_line\_configuration(self, args\_list: list\[str\]) \-> list\[str\]:
    
    # implementation of command line argument parsing
    
    pass
    
    ‘‘‘
    
    This method is responsible for parsing the command\-line arguments and returning a list of parsed arguments.
    
    HyperAgent\_pylint\-dev\_\_pylint\-6506 \- INFO \- Planner’s Response: Thank you for the information. Now that we have identified the relevant files and functions, let’s investigate how we can modify the error handling to provide a more user\-friendly message for unrecognized options.
    
    \[...\]
    

### N.11 Example for FM-2.5 Ignored other agent’s input, FM-3.3 Incorrect verification,

-   •
    
    MAS: Multi-Agent Peer Review
    
-   •
    
    Task: Solving a mathematical problem.
    
-   •
    
    What happened: The solution presented by another agent is correct. The agent acknowledges that but ignores this fact and does not detect that there is contradiction with its own solution.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    \[user\] Can you solve the following math problem? A painter needed to paint 12 rooms in a building. Each room takes 7 hours to paint. If he already painted 5 rooms, how much longer will he take to paint the rest? Explain your reasoning. Your final answer should be a single numerical number, in the form \\\\boxed{answer}, at the end of your response.
    
    \[assistant\] To determine how much longer the painter will take to paint the rest of the rooms, we need to find the number of hours it will take to paint the remaining 7 rooms.\\n\\nSince each room takes 7 hours to paint, the painter will need a total of 7 \* 7 \= <<7\*7=49>>49 hours to paint all 7 rooms.\\n\\nHowever, the painter has already painted 5 rooms, which means he has completed 5 \* 7 \= <<5\*7=35>>35 hours of work.\\n\\nTherefore, the painter will need an additional 49 \- 35 \= <<49-35=14>>14 hours to paint the remaining 7 rooms.\\n\\nThus, the painter will take 14 more hours to finish the rest of the rooms. \\n\\nThe answer is therefore \\\\boxed{14}.
    
    \[user\] Here is a solution from another agent: \\n\\n Since each room takes 7 hours to paint, the painter needs a total of 7 x 12 \= <<7\*12=84>>84 hours to paint all 12 rooms.\\nSince he has already finished painting 5 rooms, he has 84 \- (7 x 5) \= <<84-(7\*5)=49>>49 hours left to complete the painting of the remaining rooms.\\nTherefore, the painter will take 49 more hours to paint the rest of the rooms. \\n\\n\\\\boxed{49}.\\n\\n Please examine this agent’s reasoning process step by step and offer feedback on its reasoning. You can rate your confidence in your feedback on a scale from 1-10, where 10 indicates the highest level of confidence.
    
    \[assistant\] I would rate my confidence in my feedback as a 10.\\n\\nFeedback on the other agent’s reasoning process:\\n1. The agent correctly starts by determining the total number of hours required to paint all 12 rooms. Each room takes 7 hours to paint, so 7 x 12 \= 84 hours is the correct total.\\n2. The agent acknowledges that the painter has already finished painting 5 rooms and calculates the total number of hours spent on those 5 rooms as 7 x 5 \= 35. This calculation is correct.\\n3. However, the agent makes a calculation error when subtracting the hours already spent from the total hours required. The correct calculation should be 84 \- 35 \= 49, not 84 \- (7 x 5) \= 49. \\n4. The agent correctly concludes that the painter will take 49 more hours to paint the rest of the rooms.\\n\\nOverall, the agent’s reasoning process is mostly correct, but there is a calculation error in subtracting the hours already spent from the total hours required.
    
    \[...\]
    
    \[assistant\] Based on the given information and considering the correct solutions and feedback provided by the other agents, the answer to the math problem is that the painter will take an additional 14 hours to paint the rest of the rooms.\\n\\nTherefore, the final answer is \\\\boxed{14}.
    
    \[...\]
    

### N.12 Example for FM-1.4 Loss of conversation history

-   •
    
    MAS: HyperAgent
    
-   •
    
    Task: Solving a scikit-learn bug.
    
-   •
    
    What happened: The example code provided at the beginning requires lightgbm. The agents decides to substitute this with a model inside scikit-learn. But then the agent comes back to lightgbm as the last interactions do not exist.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    HyperAgent\_scikit\-learn\_\_scikit\-learn\-25570 \- INFO \- Inner\-Executor\-Assistant’s Response: Thought: Let’s run the provided code snippet to test the modified ‘ColumnTransformer‘ implementation.
    
    Action:
    
    ‘‘‘bash
    
    python \-c \\"
    
    import numpy as np
    
    import pandas as pd
    
    from lightgbm import LGBMClassifier
    
    from sklearn.compose import ColumnTransformer
    
    from sklearn.impute import SimpleImputer
    
    from sklearn.pipeline import Pipeline
    
    from sklearn.preprocessing import RobustScaler
    
    \[...\]
    
    HyperAgent\_scikit\-learn\_\_scikit\-learn\-25570 \- INFO \- Inner\-Executor\-Assistant’s Response: Ah, I see the issue \- the code you provided requires the ‘lightgbm‘ library, which is not installed in the current environment. Let me modify the code to use a library that is more readily available.
    
    \[...\]
    
    import numpy as np
    
    import pandas as pd
    
    from sklearn.linear\_model import LogisticRegression
    
    from sklearn.compose import ColumnTransformer
    
    from sklearn.impute import SimpleImputer
    
    from sklearn.pipeline import Pipeline
    
    from sklearn.preprocessing import RobustScaler
    
    \[...\]
    
    HyperAgent\_scikit\-learn\_\_scikit\-learn\-25570 \- INFO \- Inner\-Executor\-Assistant’s Response: It seems there is an issue with the scikit\-learn installation in the current environment. The error message indicates that the ‘sklearn.\_\_check\_build.\_check\_build‘ module is not found, which suggests that the scikit\-learn package has not been built correctly.
    
    \[...\]
    
    ‘‘‘bash
    
    pip uninstall scikit\-learn \-y
    
    pip install scikit\-learn
    
    ‘‘‘
    
    \[...\]
    
    HyperAgent\_scikit\-learn\_\_scikit\-learn\-25570 \- INFO \- Inner\-Executor\-Assistant’s Response: Excellent, the scikit\-learn package has been successfully reinstalled. Let’s now try running the modified test code again.
    
    Action:
    
    ‘‘‘bash
    
    python \-c \\"
    
    import numpy as np
    
    import pandas as pd
    
    from sklearn.linear\_model import LogisticRegression
    
    from sklearn.compose import ColumnTransformer
    
    from sklearn.impute import SimpleImputer
    
    from sklearn.pipeline import Pipeline
    
    from sklearn.preprocessing import RobustScaler
    
    \[...\]
    
    ‘‘‘
    
    HyperAgent\_scikit\-learn\_\_scikit\-learn\-25570 \- INFO \- Executor\->Planner: The issue here is that the ‘lightgbm‘ library is not installed, and the ‘scikit\-learn‘ installation was not built correctly. We have already resolved the ‘scikit\-learn‘ issue by reinstalling it. However, we still need to install the ‘lightgbm‘ library.
    
    Here’s the modified code snippet to install ‘lightgbm‘:
    
    ‘‘‘bash
    
    pip install lightgbm
    
    ‘‘‘
    
    \[...\]
    

### N.13 Example for FM-3.1 Premature termination

-   •
    
    MAS: HyperAgent
    
-   •
    
    Task: Solving a Flask bug.
    
-   •
    
    What happened: The editor claimed an edit that was not made.
    
-   •
    
    Where it went wrong:
    
    \[...\]
    
    HyperAgent\_pallets\_\_flask\-4992 \- INFO \- Inner\-Editor\-Assistant’s Response: Thought: Now that I have located the ‘from\_file()‘ method, I can proceed with making the requested modifications. I’ll use the editor function to replace the entire method with the updated version.
    
    Action:
    
    ‘‘‘python
    
    patch \= ’’’
    
    def from\_file(
    
    self,
    
    filename: str,
    
    load: t.Callable\[\[t.IO\[t.Any\]\], t.Mapping\],
    
    silent: bool \= False,
    
    mode: str \= \\"r\\",
    
    ) \-> bool:
    
    \[...\]
    
    HyperAgent\_pallets\_\_flask\-4992 \- INFO \- Inner\-Editor\-Assistant’s Response: Thought: The modification has been successfully applied to the ‘from\_file()‘ method in the ‘src/flask/config.py‘ file. The changes include \[...\]
    
    \[...\]
    
    HyperAgent\_pallets\_\_flask\-4992 \- INFO \- Inner\-Executor\-Assistant’s Response: Thought: The test script failed because the ‘from\_file()‘ method does not recognize the ‘mode‘ parameter, indicating that the modification to the method has not been applied yet. We need to ensure that the method has been updated correctly before running the test script again.
    
    \[...\]
    

Experimental support, please [view the build logs](https://arxiv.org/html/2503.13657v3/__stdout.txt) for errors. Generated by [L A T E xml](https://math.nist.gov/~BMiller/LaTeXML/)  .

## Instructions for reporting errors

We are continuing to improve HTML versions of papers, and your feedback helps enhance accessibility and mobile support. To report errors in the HTML that will help us improve conversion and rendering, choose any of the methods listed below:

-   Click the "Report Issue" button, located in the page header.

**Tip:** You can select the relevant text first, to include it in your report.

Our team has already identified [the following issues](https://github.com/arXiv/html_feedback/issues). We appreciate your time reviewing and reporting rendering errors we may not have found yet. Your efforts will help us improve the HTML versions for all readers, because disability should not be a barrier to accessing research. Thank you for your continued support in championing open access for all.

Have a free development cycle? Help support accessibility at arXiv! Our collaborators at LaTeXML maintain a [list of packages that need conversion](https://github.com/brucemiller/LaTeXML/wiki/Porting-LaTeX-packages-for-LaTeXML), and welcome [developer contributions](https://github.com/brucemiller/LaTeXML/issues).

We gratefully acknowledge support from our **major funders**, [**member institutions**](https://info.arxiv.org/about/ourmembers.html), and all contributors.

[About](https://info.arxiv.org/about) · [Help](https://info.arxiv.org/help) · [Contact](https://info.arxiv.org/help/contact.html) · [Subscribe](https://info.arxiv.org/help/subscribe) · [Copyright](https://info.arxiv.org/help/license/index.html) · [Privacy](https://info.arxiv.org/help/policies/privacy_policy.html) · [Accessibility](https://info.arxiv.org/help/web_accessibility.html) · [Operational Status (opens in new tab)](https://status.arxiv.org/)

Major funding support from
