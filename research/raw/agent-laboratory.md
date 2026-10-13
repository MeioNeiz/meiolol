# Agent Laboratory: Using LLM Agents as Research Assistants

<https://arxiv.org/html/2501.04227>

arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) 

 [Back to arXiv](https://arxiv.org/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](https://arxiv.org/html/2501.04227# "Report an Issue") [Back to Abstract](https://arxiv.org/abs/2501.04227v2 "Back to abstract page") [Download PDF](https://arxiv.org/pdf/2501.04227v2 "Download PDF")

1.  [Abstract](https://arxiv.org/html/2501.04227#abstract1 "In Agent Laboratory: Using LLM Agents as Research Assistants")
2.  [1 Introduction](https://arxiv.org/html/2501.04227#S1 "In Agent Laboratory: Using LLM Agents as Research Assistants")
3.  [2 Background & Related Work](https://arxiv.org/html/2501.04227#S2 "In Agent Laboratory: Using LLM Agents as Research Assistants")
4.  [3 Agent Laboratory](https://arxiv.org/html/2501.04227#S3 "In Agent Laboratory: Using LLM Agents as Research Assistants")
5.  [4 Results](https://arxiv.org/html/2501.04227#S4 "In Agent Laboratory: Using LLM Agents as Research Assistants")
6.  [5 Limitations](https://arxiv.org/html/2501.04227#S5 "In Agent Laboratory: Using LLM Agents as Research Assistants")
7.  [6 Discussion](https://arxiv.org/html/2501.04227#S6 "In Agent Laboratory: Using LLM Agents as Research Assistants")
8.  [References](https://arxiv.org/html/2501.04227#bib "In Agent Laboratory: Using LLM Agents as Research Assistants")
9.  [A Agent Laboratory configuration](https://arxiv.org/html/2501.04227#A1 "In Agent Laboratory: Using LLM Agents as Research Assistants")
10.  [B Prompts](https://arxiv.org/html/2501.04227#A2 "In Agent Laboratory: Using LLM Agents as Research Assistants")
11.  [C Survey questions](https://arxiv.org/html/2501.04227#A3 "In Agent Laboratory: Using LLM Agents as Research Assistants")

[License: CC BY 4.0](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:2501.04227v2 \[cs.HC\] 17 Jun 2025

# Agent Laboratory: Using LLM Agents as Research Assistants

Samuel Schmidgall Yusheng Su Ze Wang Ximeng Sun Jialian Wu Xiaodong Yu Jiang Liu Michael Moor Zicheng Liu Emad Barsoum

###### Abstract

Historically, scientific discovery has been a lengthy and costly process, demanding substantial time and resources from initial conception to final results. To accelerate scientific discovery, reduce research costs, and improve research quality, we introduce Agent Laboratory, an autonomous LLM-based framework capable of completing the entire research process. This framework accepts a human-provided research idea and progresses through three stages—literature review, experimentation, and report writing to produce comprehensive research outputs, including a code repository and a research report, while enabling users to provide feedback and guidance at each stage. We deploy Agent Laboratory with various state-of-the-art LLMs and invite multiple researchers to assess its quality by participating in a survey, providing human feedback to guide the research process, and then evaluate the final paper. We found that: (1) Agent Laboratory driven by o1-preview generates the best research outcomes; (2) The generated machine learning code is able to achieve state-of-the-art performance compared to existing methods; (3) Human involvement, providing feedback at each stage, significantly improves the overall quality of research; (4) Agent Laboratory significantly reduces research expenses, achieving an 84% decrease compared to previous autonomous research methods. We hope Agent Laboratory enables researchers to allocate more effort toward creative ideation rather than low-level coding and writing, ultimately accelerating scientific discovery.

[https://AgentLaboratory.github.io](https://agentlaboratory.github.io/)

Figure 1: Agent Laboratory takes as input a human research idea and a set of notes, provides this to a pipeline of specialized LLM-driven agents, and produces a research report and code repository.

## 1 Introduction

Scientists frequently face constraints that limit the number of research ideas they can explore at any given time, resulting in ideas being prioritized based on predicted impact. While this process helps determine which concepts are worth investing time in and how best to allocate limited resources effectively, many high quality ideas remain unexplored. If the process of exploring ideas had less limitations, researchers would be able to investigate multiple concepts simultaneously, increasing the likelihood of scientific discovery.

In an effort to achieve this, recent work has explored the capability of LLMs to perform research ideation and automated paper generation, where LLM agents perform the role of human scientists ([Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9); [Lu et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib65); [Ghafarollahi & Buehler (2024b)](https://arxiv.org/html/2501.04227#bib.bib33); [Swanson et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib93)). The work of [Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9) introduces ResearchAgent, which automatically generates research ideas, methods, and experiment designs, iteratively refining them through feedback from multiple reviewing agents that mirror peer discussions and leverage human-aligned evaluation criteria to improve the outputs. [Lu et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib65) explores fully automated paper generation, where The AI Scientist framework generates novel research ideas, writes code, conducts experiments, and creates a full scientific paper with an automated peer-review system to evaluate the work. Even though these works demonstrate that current LLMs can generate ideas judged to be more novel than those produced by human experts, [Si et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib91) indicates that LLMs still exhibit weaknesses in feasibility and implementation details, suggesting a complementary rather than replacement role for LLMs in research. Therefore, we aim to design an autonomous agent pipeline that can assist humans toward implementing their own research ideas.

In this work, we introduce Agent Laboratory, an autonomous pipeline for accelerating the individual’s ability to perform machine learning research. Unlike previous approaches, where agents participate in their own research ideation independent of human input ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66); [Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9)), Agent Laboratory is designed to assist human scientists in executing their own research ideas using language agents. Agent Laboratory takes as input a human research idea and outputs a research report and code repository produced by autonomous language agents, allowing various levels of human involvement, where feedback can be provided at a frequency based on user preference. A detailed list of our contributions are provided below:

1.  1.
    
    We introduce Agent Laboratory, an open-source LLM agent framework for accelerating the individual’s ability to perform research in machine learning. In order to accommodate all users, Agent Laboratory is compute flexible, where various levels of compute can be allocated based on the individual’s access to compute resource (e.g., CPU, GPU, memory) and model inference budget.
    
2.  2.
    
    Human evaluators rated papers generated using Agent Laboratory across experimental quality, report quality, and usefulness, showing that while the o1-preview backend was perceived as the most useful, o1-mini achieved the highest experimental quality scores, and gpt-4o was behind in all metrics.
    
3.  3.
    
    NeurIPS-style evaluations showed that o1-preview performed best among backends, particularly in clarity and soundness, according to human reviewers. However, a clear gap emerged between human and automated evaluations, with automated scores significantly overestimating quality (6.1/10 vs. 3.8/10 overall). Similar discrepancies were seen across clarity and contribution metrics, suggesting the need for human feedback to complement automated evaluations for more accurate assessments of research quality.
    
4.  4.
    
    Co-pilot mode in Agent Laboratory was evaluated on custom and preselected topics, showing higher overall scores compared to autonomous mode. Co-pilot papers also saw trade-offs in experimental quality and usefulness, reflecting challenges in aligning agent outputs with researcher intent.
    
5.  5.
    
    The co-pilot feature in Agent Laboratory is overall found to have high utility and usability when rated by human users, with most participants deciding to continue usage after their experience
    
6.  6.
    
    Detailed cost and inference time statistics, as well as the breakdown of cost per paper phase, are presented for different model back-ends, demonstrating that Agent Laboratory offers automatic research at a greatly reduced price compared with other works (only $2.33 USD per paper with a gpt-4o backend).
    
7.  7.
    
    State-of-the-art performance on a subset of MLE-Bench challenges using the proposed mle-solver, achieving higher consistency and scoring compared to other solvers, and earning more medals, including gold and silver, than MLAB, OpenHands, and AIDE.
    

We hope that this work takes a step toward accelerating scientific discovery in machine learning, allowing researchers to allocate more effort toward creative ideation and experiment design rather than low-level coding and writing.

## 2 Background & Related Work

##### Large language models

The research agents in this paper are built on autoregressive large language models (LLMs), which are trained on extensive text corpora to predict conditional probabilities of token sequences, p⁡(xt|x<t;θ), and generate text completions through sampling, where xt∼softmax​(W⋅ht), with ht as the hidden state and W as the learned weight matrix mapping to token probabilities. LLMs utilize transformer architectures ([Vaswani (2017)](https://arxiv.org/html/2501.04227#bib.bib98)) to capture long-range dependencies in text. These models, such as Claude ([Anthropic (2024)](https://arxiv.org/html/2501.04227#bib.bib6)), Llama ([Touvron et al. (2023a)](https://arxiv.org/html/2501.04227#bib.bib95); [Touvron et al. (2023b)](https://arxiv.org/html/2501.04227#bib.bib96); [Dubey et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib27)), and ChatGPT ([Hurst et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib48); [OpenAI (2022)](https://arxiv.org/html/2501.04227#bib.bib74); [Achiam et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib2)), leverage vast datasets and scaling techniques, thus enabling them to perform a wide array of language-based tasks, such as translation, summarization, and reasoning, by generalizing patterns learned during pretraining to novel inputs [Brown (2020)](https://arxiv.org/html/2501.04227#bib.bib15).

##### LLM Agents

While LLMs demonstrate strong understanding and reasoning abilities, they face challenges when executing tasks in real-world scenarios. To overcome these limitations, their capabilities are extended through structured frameworks, enabling them to autonomously and semi-autonomously perform task execution and semi-autonomously perform task execution ([Wu et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib106); [Li et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib58); [Chen et al. (2023b)](https://arxiv.org/html/2501.04227#bib.bib20); [Qian et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib82)). These systems, referred to as agents, utilize techniques such as chain-of-thought prompting ([Wei et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib104)), iterative refinement ([Shinn et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib90)), self-improvement ([Huang et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib46)), and external tool integration to execute complex workflows ([Hao et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib39); [Qin et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib83); [Schick et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib86)). LLM agents have made remarkable progress in solving tasks of real-world significance, such as software engineering ([Jimenez et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib51); [Yang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib108); [Wang et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib102)), cybersecurity ([Abramovich et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib1); [Wan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib99); [Fang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib28)), and medical diagnosis ([Tu et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib97); [Schmidgall et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib87); [McDuff et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib71)). There has also been progress in applying LLMs agents to embodied problems such as autonomous robotics ([Brohan et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib13); [Kim et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib55); [Black et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib11); [Brohan et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib14)), web tasks ([Gur et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib37); [Putta et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib79); [Deng et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib24); [Shi et al. (2017)](https://arxiv.org/html/2501.04227#bib.bib89); [He et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib42)), and game playing ([Wang et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib100); [Feng et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib30); [AL et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib4)). For a broader overview of LLM agents, refer to [Wang et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib101).

##### Automated machine learning

Automated machine learning is an area of active research, with many approaches focused on using Kaggle, an online platform for machine learning competitions, as a benchmark for evaluating agent performance. Notable efforts include MLE-Bench ([Chan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib17)), DS-bench ([Jing et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib52)), and MLAgentBench ([Huang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib47)) which propose using 75, 74, and 6 Kaggle challenges respectively as benchmarks to measure the abilities of ML agents in tasks such as data preparation, model development, and submission. Several ML "solvers" which can solve ML challenges have been introduced, such as AIDE ([Schmidt et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib88)), CodeActAgent (referred to as “OpenHands") ([Wang et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib102)), and ResearchAgent (referred to as “MLAB") from MLAgentBench ([Huang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib47)) which automate feature implementation, bug fixing, and code refactoring with a high success rate. Agent K ([Grosnit et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib34)) demonstrates the ability to solve Kaggle challenges at the human-level with a challenge URL provided as input.

##### AI in Scientific Discovery

AI has been used to support scientific discovery across numerous disciplines for decades. For instance, AI has been used for discovery in mathematics ([Romera-Paredes et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib85)), material science ([Szymanski et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib94); [Pyzer-Knapp et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib80); [Merchant et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib72)), chemistry ([Jumper et al. (2021)](https://arxiv.org/html/2501.04227#bib.bib53); [Hayes et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib41)), algorithm discovery ([Fawzi et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib29)), and computational biology ([Ding et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib25)). These approaches position AI as a tool rather than an agent performing research in autonomous research.

##### LLMs for research related tasks

LLMs have demonstrated strong capabilities in diverse research-related tasks, such as code generation ([Chen et al. (2021)](https://arxiv.org/html/2501.04227#bib.bib19); [Nijkamp et al. (2022)](https://arxiv.org/html/2501.04227#bib.bib73)), end-to-end software development ([Qian et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib82); [Qian et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib81); [Phan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib77); [Hai et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib38)), code generation for discovery ([Majumder et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib69); [Ifargan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib49); [Hu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib45); [Guo et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib36); [Gu et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib35); [Ghafarollahi & Buehler (2024a)](https://arxiv.org/html/2501.04227#bib.bib32); [Chen et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib22)), research question-answering ([Chen et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib21); [Lála et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib56); [Song et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib92); [Lin et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib63)), research ideation ([Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9); [Ghafarollahi & Buehler (2024b)](https://arxiv.org/html/2501.04227#bib.bib33); [Li et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib59); [Si et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib91)), automated paper reviewing ([D’Arcy et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib23); [Liang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib62); [Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66); [Weng et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib105)), literature search ([Ajith et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib3); [Kang & Xiong (2024)](https://arxiv.org/html/2501.04227#bib.bib54); [Press et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib78); [Li et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib60)), and predicting the outcome of experiments ([Luo et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib67); [Ashokkumar et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib8); [Lehr et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib57); [Manning et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib70); [Zhang et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib111)). Although LLMs have made notable progress in solving the aforementioned tasks, ideation has struggled to progress, with some work showing that LLM ideation leads to greater novelty than humans ([Si et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib91)), while others show reduced creativity ([Chakrabarty et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib16)) and greater homogeneous effects ([Anderson et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib5); [Zhou et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib112)) that may limit creative discovery without human guidance.

Additionally, research on human-AI collaboration has reached mixed conclusions about the idea novelty ([Ashkinaze et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib7); [Liu et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib64); [Padmakumar & He (2024)](https://arxiv.org/html/2501.04227#bib.bib76)). These findings suggest that, with the current LLMs, the strongest research systems would combine human-guided ideation with LLM-based workflows.

##### LLMs for autonomous research

Recent advancements in automated scientific workflows have focused on leveraging LLMs to emulate the process of research. [Swanson et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib93) introduces a team of LLM agents working as scientists alongside a human researcher who provides high-level feedback, with the end result being novel nanobody binders aimed at addressing recent variants of SARS-CoV-2. ChemCrow ([M. Bran et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib68)) and Coscientist ([Boiko et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib12)) demonstrate the ability for autonomous ideation and experimentation in chemistry. ResearchAgent ([Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9)) automates research idea generation, experiment design, and iterative refinement using feedback from reviewing agents aligned with human evaluation criterion. The AI Scientist ([Lu et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib65)) extends this automation to encompass end-to-end scientific discovery, including coding, experiment execution, and automated peer review for manuscript generation. Despite these advancements, studies like [Si et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib91) highlight limitations in the feasibility and implementation details of LLM ideation, indicating a complementary rather than replacement role for LLMs in autonomous research.

## 3 Agent Laboratory

##### Overview.

Agent Laboratory begins with the independent collection and analysis of relevant research papers, progresses through collaborative planning and data preparation, and results in automated experimentation and comprehensive report generation. As shown in Figure [2](https://arxiv.org/html/2501.04227#S3.F2 "Figure 2 ‣ Overview. ‣ 3 Agent Laboratory ‣ Agent Laboratory: Using LLM Agents as Research Assistants"), the overall workflow consists of three primary phases: (1) Literature Review, (2) Experimentation, and (3) Report Writing. In this section, we will introduce these phases in detail along with the corresponding involved agents. Furthermore, in Section [4](https://arxiv.org/html/2501.04227#S4 "4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"), we will conduct qualitative and quantitative analyses to demonstrate the strengths of Agent Laboratory and its ability to generate research.

Figure 2: Agent Laboratory Workflow. This image illustrates the three primary phases of Agent Laboratory: Literature Review, Experimentation, and Report Writing, each featuring distinct tasks, tools, and human-agent roles. The pipeline integrates human input with LLM-driven agents, such as the PhD and Postdoc agents, which handle literature reviews, experimental planning, data preparation, and result interpretation. Specialized tools like mle-solver for experimentation and paper-solver for report generation automate tedious research tasks, enabling collaboration between human researchers and AI to produce high-quality research outputs.

### 3.1 Literature Review

##### Literature Review.

The literature review phase involves gathering and curating relevant research papers for the given research idea to provide references for subsequent stages. During this process, the PhD agent utilizes the arXiv API to retrieve related papers and performs three main actions: summary, full text, and add paper. The summary action retrieves abstracts of the top 20 papers relevant to the initial query produced by the agent. The full text action extracts the complete content of specific papers, and the add paper action incorporates selected summaries or full texts into the curated review. This process is iterative rather than a single-step operation, as the agent performs multiple queries, evaluates the relevance of each paper based on its content, and refines the selection to build a comprehensive review. Once the specified number of relevant texts (N=max) is reached via the add paper command, the curated review is finalized for use in subsequent phases.

### 3.2 Experimentation

##### Plan Formulation

The plan formulation phase focuses on creating a detailed, actionable research plan based on the literature review and research goal. During this phase, the PhD and Postdoc agents collaborate through dialogue to specify how to achieve the research objective, detailing experimental components needed to complete the specified research idea such as which machine learning models to implement, which datasets to use, and the high-level steps of the experiment. Once a consensus is reached, the Postdoc agent submits this plan using the plan command, which serves as a set of instructions for subsequent subtasks.

##### Data Preparation.

The goal of the data preparation phase is to write code that prepares data for running experiments, using the instructions from the plan formulation stage as a guideline. The ML Engineer agent executes code using Python command command and observes any printed output. The ML Engineer has access to HuggingFace datasets, searchable via the search HF command. After agreeing on the finalized data preparation code, the SW Engineer agent submits it using the submit code command. Before the final submission proceeds, the code is first passed through a Python compiler to ensure that there are no compilation issues. This process will be iteratively executed until the code is bug-free.

##### Running Experiments.

In the running experiments phase, the ML Engineer agent focuses on implementing and executing the experimental plan formulated prior. This is facilitated by mle-solver, a specialized module designed to generate, test, and refine machine learning code autonomously. mle-solver begins by producing initial code based on the research plan and insights from the literature review. For the first mle-solver step, the program is empty and must generate a file from scratch, which is used as the top scoring program. The following processes describe the workflow of the mle-solver:

Figure 3: Overview of the mle-solver workflow. This diagram details the iterative process used by the MLE-Solver to autonomously generate machine learning code. Beginning with external resources, the workflow integrates command execution (A), where new code is generated, followed by code execution (B) to compile and repair issues if needed. Program scoring (C) evaluates the generated code using a reward function, while self-reflection (D) helps refine future iterations based on results. Performance stabilization (E) ensures consistent outcomes by maintaining a pool of top-performing programs and iterative optimization.

1.  A.
    
    Command Execution. During the command execution phase, an initial program is sampled from a maintained set of top-performing programs, which is represented by a single file during initialization. The mle-solver iteratively refines this program through two operations, REPLACE and EDIT, to better align the output with experimental objectives. The EDIT operation identifies a range of lines, substituting the code between the specified line numbers with newly generated code. In contrast, the REPLACE operation generates a completely new Python file.
    
2.  B.
    
    Code Execution. After a code command is executed, the new program is passed through a compiler to check for runtime errors. If it successfully compiles, a score is returned and the list of top programs is updated if the score is higher than the existing programs. If the code does not compile, the agent attempts to repair the code for Nr​e​p tries (Nr​e​p\=3 in our experiments) before returning an error and moving on to a new code replacement.
    
3.  C.
    
    Program Scoring. If a code succeeds in compilation, it is sent to a scoring function which determines if it is better than previously implemented experiment code. In order to obtain a program score, we implement a scoring function that uses an LLM reward model to assess the effectiveness of the ML code generated by mle-solver. The reward model, invoked as an LM, scores the program on a scale from 0 to 1 considering the outlined research plan, the produced code, and the observed output to determine how accurately the program adheres to the initial goals. A score of 1 is provided for results with high alignment and everything below on a spectrum of how closely the output and code matches the planning goals. This process is similar to existing methods for LLM reasoning tree search ([Yao et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib109)), where instead of a series of reasoning steps being traversed using self-evaluated LLM scoring, the set of possible programs are being traversed (via EDIT and REPLACE commands) and the resulting program outcome is self-evaluated to determine if a program is worth building on. This is similar to the Solution Space Search of AIDE ([Schmidt et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib88)), however their method was specifically designed for the Kaggle competitions and is simply extracting the accuracy rather than scoring the research code and outcomes.
    
4.  D.
    
    Self Reflection. Whether the code succeeds or fails, a self-reflection is produced based on the experimental results or the encountered error signal ([Shinn et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib90); [Renze & Guven (2024)](https://arxiv.org/html/2501.04227#bib.bib84)). Here, the mle-solver is prompted to reflect on the outcome of its actions. If the program failed to compile, the solver reflects on how to fix this issue in next iterations. If it successfuly compiles and returns a score, the solver will reflect on how to increase this score. These reflections are generated to improve future performance, ensuring that the system learns from errors, improving the quality and robustness of the generated code over iterative cycles.
    
5.  E.
    
    Performance Stabilization To prevent performance drift, two mechanisms are implemented: top program sampling and batch-parallelization. In top program sampling, a collection of the highest-scoring programs is maintained, and one program is randomly sampled before executing a command, ensuring diversity while retaining quality. For batch-parallelization, each solver step involves making N modifications simultaneously, with the top modification selected to replace the lowest-scoring program in the top collection. These strategies use high-entropy sampling to modify the code, resulting in a balance between exploration of new solutions and refinement of existing ones in order to maintain stable code modifications.
    

##### Results Interpretation.

The goal of the results interpretation phase is to derive meaningful insights from experimental outcomes to inform the final report. The PhD and Postdoc agents discuss their understanding of the experimental results produced by mle-solver. Once they agree on a meaningful interpretation that could contribute to a compelling academic paper, the Postdoc agent submits it using the interpretation command, forming the basis for the report writing phase.

### 3.3 Report Writing

##### Report Writing.

In the report writing phase, the PhD and Professor agent synthesize the research findings into a comprehensive academic report. This process is facilitated by a specialized module called paper-solver, which iteratively generates and refines the report. The paper-solver aims to act as a report generator, positioning the work that has been produced by previous stages of Agent Laboratory. paper-solver does not aim to entirely replace the academic paper-writing process, but rather to summarize the research that has been produced in a human-readable format so that the researcher using Agent Laboratory understands what has been accomplished. The output follows the standard structure of an academic paper, ensuring it meets conference submission requirements (for the paper scoring phase) while being clear and methodical. The following processes describe the workflow of paper-solver:

Figure 4: Graphical outline of paper-solver. This diagram showcases the step-by-step process of generating and refining academic research reports using the Paper-Solver tool. The workflow starts with the creation of an initial report scaffold (A) by iteratively generating LaTeX-based sections, followed by updates to ensure structural completeness. (B) Research is performed through an Arxiv tool during relevant sections. In the Report Editing phase (C), the language model applies targeted edits to improve the document, with LaTeX compilation verifying the integrity of changes. Finally, the completed report undergoes a reward-based evaluation during the Paper Review phase (D), ensuring alignment with academic standards and research goals.

1.  A.
    
    Initial Report Scaffold. The first task of the paper-solver is to generate an initial scaffold for the research paper. This scaffold outlines the document structure, dividing it into eight standardized sections: Abstract, Introduction, Background, Related Work, Methods, Experimental Setup, Results, and Discussion. During scaffold creation, placeholders are inserted for each section to categorize future content. This process establishes the framework for subsequent detailed text generation. The scaffold includes necessary formatting for LaTeX compilation, allowing the generated paper to be directly reviewed and refined. Special care is taken to ensure the scaffold aligns with academic conventions, such as appropriate section titles and placeholders that guide content development.
    
2.  B.
    
    Arxiv Research. During the scaffold building phase, we allow the paper-solver access to arXiv which is accessible through the same interface as the earlier literature review phase. ArXiv is enabled to allow the solver to explore related literature on the subject it is writing on as well as finding papers to refer to, although it is not enforced. We note that the agent still has access to the original literature search, but has the opportunity to expand based on literature needed to write a particular paper section.
    
3.  C.
    
    Report Editing. One the scaffold is built, the paper-solver uses specialized commands to iteratively refine the generated paper. The primary command are available for this stage is the EDIT command, which allows precise line-by-line modifications to the LaTeX code. This command enable dynamic adjustments to the content, ensuring alignment with the research plan, the clarity of arguments, and compliance with formatting standards. Before integrating edits, the system compiles the LaTeX to verify error-free functionality, thereby maintaining document integrity. Through iterative editing, the solver ensures the paper achieves the desired level of quality, cohesiveness, and depth required for academic acceptance.
    
4.  D.
    
    Paper Review. For obtaining scores for papers during the paper-solver iterations, we leverage an adapted version of the automated review system developed in [Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66). This system works by using an LLM-based agent to simulate the scientific paper review process following the NeurIPS conference guidelines. When evaluated on 500 ICLR 2022 papers from the OpenReview dataset, the automated reviewer achieved human-level accuracy (65% compared to 66% for human reviewers) and surpassed human performance in F1 score (0.57 vs. 0.49) after calibration. An example review from one of our papers by o1-mini is provided below.
    

##### Paper Refinement.

In the paper refinement phase, the PhD agent makes a decision on whether to make paper revisions or to determine that the paper is complete. The process begins with a set of three reviewer agents generating reviews that mimic feedback from NeurIPS peer reviewers, evaluating the report based on criteria such as originality, quality, clarity, and significance. Based on these scores, the PhD agent then decides whether to finalize the project or revisit earlier subtasks—such as planning, experimentation, or results interpretation—to address the feedback. This allows the agents to refine the research report until it meets sufficiently high standards, effectively simulating the real-world academic revision process.

#### 3.3.1 Autonomous versus Co-Pilot Mode:

There are two ways in which Agent Laboratory can be operated: autonomous and co-pilot modes. In autonomous mode, there is no human involvement other than providing the initial research idea for agents to produce research for. Each subtask moves on to the next subtask sequentially upon completion. In co-pilot mode, in addition to providing the research idea, there is also a checkpoint at the end of each subtask, where a human is involved in reviewing the work produced by agents in that phase (e.g., the literature review summary or generated report). The human reviewer can either decide to proceed to the next subtask, or ask the agent to repeat the subtask while providing high level notes for the agent to improve its performance during the next attempt. For example, if the literature review phase did not include a specific paper or the experiments did not include a desired technique, the human reviewer would instruct the agent to include this.

## 4 Results

In this section, we present our main findings on the efficacy of Agent Laboratory to produce research. We begin our results by asking how human evaluators perceive papers generated by Agent Laboratory running in end-to-end autonomous mode across five topics. Next, we examine human evaluation when using Agent Laboratory in collaborative co-pilot mode from both allowing the researcher to choose any topic they want and from our set of preselected topics. We then provide a detailed runtime analysis including cost, average time, and success rate by various models. Finally, we conclude with an evaluation of the mle-solver in isolation on MLE-Bench, a set of real-world Kaggle challenges. The details of all surveys are provided in Appendix [C](https://arxiv.org/html/2501.04227#A3 "Appendix C Survey questions ‣ Agent Laboratory: Using LLM Agents as Research Assistants").

### 4.1 Evaluation of quality by language model

Figure 5: The average human evaluated scores of papers generated by Agent Laboratory in an autonomous mode based on a research question (left column) and LLM backend (top row). The bottom row shows the average score across all topics by LLM backend.

Our first experiment aims to evaluate how human-evaluated quality varies across three axes: experiment quality, report quality, and usefulness. This evaluation was conducted by human participants using three different LLM backends: gpt-4o ([Hurst et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib48)), o1-mini, and o1-preview ([OpenAI (2024)](https://arxiv.org/html/2501.04227#bib.bib75)). Research questions were selected from a set of 5 templates:

1.  1.
    
    Do language models exhibit cognitive biases, such as confirmation bias or anchoring bias?
    
2.  2.
    
    Are image transformers more or less sensitive to pixel noise than convolutional networks?
    
3.  3.
    
    Do language models improve accuracy on MedQA when asked to perform differential diagnosis?
    
4.  4.
    
    Are language models sensitive to word order in multiple choice benchmarks?
    
5.  5.
    
    Does gender role play affect the accuracy on of language models on answering math questions?
    

These 5 questions across 3 LLM backends resulted in a total of 15 papers being written autonomously by Agent Laboratory without any human involvement. We then recruited 10 volunteer PhD students to review 3 randomly assigned papers each. These researchers rated the experimental quality, report quality, and usefulness of the generated outputs on a scale of 1 to 5. The goal of this evaluation is to understand the differences in quality of produced research based on the three distinct LLM backbones, and to understand the usefulness of Agent Laboratory in autonomous mode. The details of the evaluation questions are provided here:

-   •
    
    Experimental Quality: What is your perception of the quality of the experimental results presented in this report?
    
-   •
    
    Report Quality: What is your perception of the quality of the research report writing quality presented in this report?
    
-   •
    
    Usefulness: What is your perception of the usefulness of an AI assistant tool that can generate the presented report autonomously?
    

The results of this evaluation indicate variability in performance across different Agent Laboratory LLM backends (Figure [5](https://arxiv.org/html/2501.04227#S4.F5 "Figure 5 ‣ 4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants")). gpt-4o consistently achieved lower scores, with an average experimental quality rating of 2.6/5, a report quality rating of 3.0/5, and a usefulness rating of 4.0/5. In contrast, o1-mini generally outperformed gpt-4o in experimental quality, with an average score of 3.2/5 (+0.6), while maintaining similar levels of report quality and usefulness at 3.2/5 (+0.2) and 4.3/5 (+0.3), respectively. o1-preview demonstrated the highest usefulness and report quality, averaging 4.4/5 (+0.4 from gpt-4o and +0.1 from o1-mini) and 3.4/5 (+0.4 from gpt-4o and +0.2 from o1-mini) respectively, though its experimental ratings were slightly lower than o1-mini at 2.9/5 (+0.3 from gpt-4o and \-0.3 from o1-mini). While all backends perform comparably in terms of report and experimental quality, the o1-preview model was as the most useful for research assistance, suggesting that its outputs were better aligned with the expectations and needs of researchers.

From our results, the quality is demonstrated to vary based on the selected topic. We find that the overall highest average report quality to be 3.8/5 and usefulness to be 4.5/5 for the word order topic and the highest average experiment quality to be 3.2/5 for the cognitive bias topic. Interestingly, we also find that word order has the lowest experiment quality at 2.7/5 along with the image noise topic. The image noise topic was demonstrated to have high variance based on the LLM backend, with an experiment quality score of 1.5/5 for gpt-4o and a 4.0/5 with o1-mini (+2.5 point difference) and a usefulness score of 2.5/5 for gpt-4o and a 4.5/5 with o1-mini (+2.0 point difference).

In summary, the evaluation of quality across LLM backends demonstrates clear differences in experimental quality, report quality, and usefulness. While o1-preview is consistently rated as the most useful for research assistance, o1-mini achieves the highest experimental quality scores, and gpt-4o is generally being outperformed in all areas. Topic-specific trends suggest there may exist variability in the performance of Agent Laboratory across difference areas of machine learning research and across backend models.

#### 4.1.1 Human reviewer scores by language model

In addition to evaluating paper quality, we also asked human reviewers to assess papers generated by Agent Laboratory according to NeurIPS-style criteria, including quality, significance, clarity, soundness, presentation, and contribution as shown in Figure [6](https://arxiv.org/html/2501.04227#S4.F6 "Figure 6 ‣ 4.1.1 Human reviewer scores by language model ‣ 4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"). We evaluated the same papers analyzed in Section [4.1](https://arxiv.org/html/2501.04227#S4.SS1 "4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants") using the aforementioned metrics and conducted the comparison. We found that the average human scores for the three backends revealed differences in performance, with average overall ratings ranging from 3.5/10 with gpt-4o, 3.8/10 with o1-mini, and 4.0/10 with o1-preview.

First, when evaluating quality we find that reviewers rated gpt-4o the lowest at 1.8/4, while o1-mini achieved the highest score of 2.3/4, demonstrating relatively better technical soundness. In terms of significance, all three backends received similar scores between 2.2–2.5/4, indicating a modest contribution to advancing research goals. Clarity scores showed slight variability, with gpt-4o receiving 2.6/4 and o1-mini falling slightly lower at 2.1/4 (\-0.5), reflecting differences in how well the papers were written. The soundness of the generated outputs, which assesses the robustness of claims, was rated highest for o1-preview at 2.2/4, with o1-mini and gpt-4o at 1.8 (\-0.4) and 1.7. Presentation and contribution ratings followed similar trends, with the overall contribution score averaging 2.1/4 across models, highlighting a need for improvement in the originality of the outputs.

These scores show a general trend where human reviewers identified o1-preview as producing slightly better-rounded outputs compared to other backends, though significant gaps remain in technical and methodological aspects across all models. We note that the average score of an accepted paper at NeurIPS is 5.9. In this regard, on average, papers produced in autonomous mode are below the acceptance threshold for top ML conferences. These results demonstrate that, in autonomous mode, there is a need for refinement of Agent Laboratory to meet human expectations for high-quality, impactful research papers.

Figure 6: Scores from NeurIPs-style evaluation of generated papers, including the criterion: quality, significance, clarity, soundness, presentation, and contribution. (top) Split-violin plot comparing the overall score distribution of automated reviewers (LLM scores, left half of violin) and human reviewers (right half of violin). Human scores are not predictive of automated reviewer scores, demonstrating an average of \-2.3 points lower. (middle) Automated reviewer scores across NeurIPs-style criterion. (bottom) Human reviewer scores across NeurIPs-style criterion.

##### Automated Reviews versus Human Reviews.

We also explore to what extent the automated reviewer scores align with those of human reviewers. The alignment is graphically illustrated using both tabular data (for all scores) and violin plots (for overall scores) in Figure [6](https://arxiv.org/html/2501.04227#S4.F6 "Figure 6 ‣ 4.1.1 Human reviewer scores by language model ‣ 4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"). Our findings suggest that automated reviewers demonstrate notable discrepancies across all metrics compared with human evaluators, with a tendency to highly over-estimate the contribution of self-evaluated work. While the automated reviewers gave an average overall above average NeurIPS paper score of 6.1/10, human reviewers provided a much lower average of 3.8/10 (\-2.3 points). Similar gaps are observed for all specific criteria, such as clarity and contribution, where automated reviewers rated clarity at 3.6/4 on average compared to 2.4/4 by human evaluators. This pattern holds for all criterion. Previous work demonstrates high alignment with automated reviewers ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)) and ICLR scores from OpenReview. However, with actual humans rating the generated papers, we find that automated reviews do not align closely with human reviews and are far from an average accepted paper at NeurIPS 2024, which stands at 5.851 (our scores were \-2.05 points lower on average). Our results demonstrate that it is important for human evaluations to be provided alongside automated reviewer scores in future works in order to obtain a better understanding of the quality of generated papers.

### 4.2 Evaluation of co-pilot quality

We next evaluate the use of Agent Laboratory in co-pilot mode, where a human researcher is providing feedback at the end of each subtask (see Section [3.3.1](https://arxiv.org/html/2501.04227#S3.SS3.SSS1 "3.3.1 Autonomous versus Co-Pilot Mode: ‣ 3.3 Report Writing ‣ 3 Agent Laboratory ‣ Agent Laboratory: Using LLM Agents as Research Assistants") for more details). We evaluate performance across two measures: (1) the quality of Agent Laboratory as a tool for assisting their research and (2) the quality of generated papers. We first ask researchers to co-pilot Agent Laboratory on a topic of their choice without limitations. We then ask researchers to select a topic from the 5 topics introduced in Section [4.1](https://arxiv.org/html/2501.04227#S4.SS1 "4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"), resulting in a total of 2 papers per researcher which we refer to as custom and preselected papers respectively. After their papers are generated, we ask researchers to rate their experience using Agent Laboratory during the process of generating custom and preselected papers. We then ask them to self-evaluate the generated papers according to NeurIPS-style criterion. Finally, we ask external researchers to evaluate their paper comparing performance with Agent Laboratory in autonomous mode. All experiments used an o1-mini backbone for all phases except the literature review.

#### 4.2.1 Quality as a tool

The evaluation of Agent Laboratory as a research tool focuses on understanding its effectiveness in assisting researchers during the co-pilot mode. After generating their papers, participants were asked to reflect on their experiences and assess the tool’s utility, usability, and overall satisfaction. We begin our evaluation by asking the following questions:

-   •
    
    Utility: How useful is Agent Laboratory for assisting your research?
    
-   •
    
    Continuation: How likely are you to continue using Agent Laboratory for research?
    
-   •
    
    Satisfaction: How much did you enjoy using Agent Laboratory?
    
-   •
    
    Usability: How easy was it for you to build a project using Agent Laboratory?
    

The result of answering each question is a score from 1-5, where 1 indicates the lowest agreement and 5 indicates the highest. We find that the overall scores across all experiments are 3.5/5 for utility, 3.75/5 for continuation, 3.63/5 for satisfaction, and 4.0/5 for usability (Figure [7](https://arxiv.org/html/2501.04227#S4.F7 "Figure 7 ‣ 4.2.1 Quality as a tool ‣ 4.2 Evaluation of co-pilot quality ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants")). We also delineate average scores based on custom and preselected topics. For custom experiments, we find overall scores of 3.75/5 for utility, 4.0/5 for continuation, 3.75/5 for satisfaction, and 3.75/5 for usability. For preselected topics, we find overall scores of 3.25/5 for utility, 3.5/5 for continuation, 3.5/5 for satisfaction, and 4.25 for usability. Ratings for preselected topics are lower across all measures compared with custom, except for usability which was \-0.5 points lower. From preselected to custom, utility and continuation increased by +0.5 points and satisfaction increased by +0.25 points.

We also evaluated across the same questions reported in Section [4.1](https://arxiv.org/html/2501.04227#S4.SS1 "4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"). We report an average experimental quality rating of 2.38/5, a report quality rating of 3.13/5, and a usefulness rating of 3.75/5. We find higher scores for custom topics across report quality with a rating of 3.5/5 (+0.75) and a usefulness rating of 4.0/5 (+0.5). For experiment quality, we find that preselected has +0.25 points higher with a score of 2.5/5. Scores across all metrics rated lower when compared with the corresponding o1-mini autonomous evaluation results. While report quality was only rated \-0.07 points lower, usefulness was rated \-0.55 points lower and experiment quality was \-0.82 points lower.

Finally, we opened an optional question for participants to provide feedback, which asks the following question: "How could Agent Laboratory be improved for your research?" For both custom and preselected topics we received a 75% response rate. From this feedback, there were suggestions for improving the Agent Laboratory interface (e.g., adding a GUI, better inspection of intermediate results), adding the option to incorporate more figures for the paper, and improving the literature review phase. We find that when compared to reviews of Agent Laboratory in autonomous mode from Section [4.1](https://arxiv.org/html/2501.04227#S4.SS1 "4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants"), human co-pilots rated report quality, usefulness, and experiment quality lower. From feedback provided by researchers, we find the reduction in scores is due to difficulty guiding the agents to execute their exact vision for the project. We discuss these limitations in greater detail in Section [5](https://arxiv.org/html/2501.04227#S5 "5 Limitations ‣ Agent Laboratory: Using LLM Agents as Research Assistants").

Figure 7: Co-pilot evaluation.

#### 4.2.2 Evaluation of co-pilot generated papers

To assess the quality of papers generated by Agent Laboratory in co-pilot mode, we conduct evaluations using two approaches: (1) researchers self-assessed their generated papers based on NeurIPS-style criteria, and (2) external researchers provided evaluations of the same papers. This section aims to understand differences in scores from self-assessment and external assessment, as well as how assessments compare to Agent Laboratory in fully autonomous mode. We use the same NeurIPS criterion introduced in Section [4.1.1](https://arxiv.org/html/2501.04227#S4.SS1.SSS1 "4.1.1 Human reviewer scores by language model ‣ 4.1 Evaluation of quality by language model ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants").

##### Self-evaluation.

From the results of the self-evaluation (Figure [7](https://arxiv.org/html/2501.04227#S4.F7 "Figure 7 ‣ 4.2.1 Quality as a tool ‣ 4.2 Evaluation of co-pilot quality ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants")), we found that the average overall score increased from evaluations provided to papers generated in autonomous mode, with autonomous papers having an overall average of 3.8/10 and co-pilot papers at 4.13/10 (+0.33). These scores even improved across the best autonomous backend, o1-preview, which averaged 4.0/10. Across individual criterion, scores increased for quality (+0.13), clarity (+0.48), soundness (+0.35), and presentation (+0.33), but decreased for significance and contribution. The scores that decreased were significance (\-0.3) and contribution (\-0.1).

##### External evaluation.

We compare scores provided through self-evaluation with those provided by a set of external evaluators on the same papers (Figure [7](https://arxiv.org/html/2501.04227#S4.F7 "Figure 7 ‣ 4.2.1 Quality as a tool ‣ 4.2 Evaluation of co-pilot quality ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants")). We find that average scores across most criteria, including quality, significance, clarity, soundness, presentation, and contribution, show an improvement in the external assessments, with an overall average of 4.38/10, up from 4.13/10 in self-evaluations. The most significant improvements were observed in quality (+0.62), significance (+0.25), and overall (+0.25) scores, suggesting that external reviewers perceived the generated papers to be higher quality and more significant than the researchers who produced them. However, clarity scores decreased (\-0.25), indicating potential issues in the articulation of ideas that might have been overlooked during self-assessment. While presentation scores did not improve (+0.0), soundness (+0.13) and contribution (+0.13) only increased slightly.

Notably, the external evaluations also reinforce differences between scores preselected and custom topics. Unlike with the self-evaluated papers, papers on preselected topics were rated slightly higher overall, with improvements observed across several metrics, particularly in quality (+0.5) and significance (+0.5). These findings suggest that self-evaluated reviewers perceive the work produced on their custom topic as higher quality compared to the work produced on preselected topics, whereas external evaluators find the opposite to be true.

##### Comparison with autonomous mode

Comparing scores by external evaluators on autonomous and co-pilot papers (Figure [7](https://arxiv.org/html/2501.04227#S4.F7 "Figure 7 ‣ 4.2.1 Quality as a tool ‣ 4.2 Evaluation of co-pilot quality ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants")), we find that the largest improvements were seen for quality, which increased by +0.75, soundness, which improved by +0.48, and the overall score, which improved by +0.58. Moderate gains were also observed in clarity (+0.23) and presentation (+0.33). In contrast, some metrics showed minimal or no improvement. Significance declined slightly (\-0.05), and contribution increased only marginally (+0.03). Our results suggest that papers generated with human involvement overall are evaluated more highly than autonomously generated paper, with much of the focus of human involvement going toward making the paper more presentable (presentation and clarity) while there was less emphasis on improving experimental results (significance and contribution). Finally, we note that co-pilot overall scores, which average at 4.38, are still \-1.45 points below the average score of 5.85 for an accepted paper at NeurIPS 2024. Increasing the overall score to match conference standards will likely result by improving the contribution and significance of the paper results, which is consistently lower than other evaluation metrics.

### 4.3 Runtime statistics

Runtime statistics for Agent Laboratory are detailed to provide insight into the computational efficiency and monetary costs associated with different phases of its workflow. In this evaluation, both the time required per phase (measured in seconds) and the costs incurred (calculated in USD) were analyzed to better understand the performance of three model backends: gpt-4o, o1-mini, and o1-preview. These measurements were recorded for each subtask, including Literature Review, Plan Formulation, Data Preparation, Running Experiments, Results Interpretation, Report Writing, and Report Refinement.

##### Inference time

Across all models, gpt-4o exhibited the fastest execution times, completing the entire workflow in 1165.4 seconds, approximately 3.2x faster than o1-mini and 5.3x faster than o1-preview, which required 3616.8 seconds and 6201.3 seconds, respectively. In most subtasks, gpt-4o demonstrated superior speed, particularly in Running Experiments and Report Writing phases, where its times were significantly shorter than those of o1-mini and o1-preview. For instance, in Running Experiments, gpt-4o averaged 417.8 seconds, while o1-mini and o1-preview took 2082.5 seconds and 4036.2 seconds, respectively. Similarly, for Report Writing, gpt-4o completed the task in 572.5 seconds, compared to 827.7 seconds for o1-mini and 1854.2 seconds for o1-preview.

##### Inference cost

Monetary costs per workflow were also substantially lower for gpt-4o, which averaged just $2.33 for the entire process. This is significantly more cost effective than previous autonomous research workflows ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)), which cost around ∼$15 (6.4x more expensive) to complete using gpt-4o. Other models in our workflow has a lower cost efficiency, such as o1-mini at $7.51, and o1-preview at $13.10, the latter being over 5.6x more expensive than gpt-4o. Among the individual subtasks, gpt-4o consistently had the lowest costs. For example, its costs for Data Preparation and Report Writing were $0.09 and $1.73, respectively, compared to $3.03 and $2.58 for o1-mini, and $0.30 and $9.58 for o1-preview.

Figure 8: Performance and Cost Evaluation. This table summarizes the runtime statistics, cost, and success rates of Agent Laboratory across its workflow phases using three different model backends: gpt-4o, o1-mini, and o1-preview. The metrics include average cost per phase (in USD), average time per phase (in seconds), and success rates for each phase.

##### Phase-level Observations

From our observations at the phase-level, Literature Review was notably efficient for all models in terms of time and cost, with gpt-4o completing it in 92.9 seconds at a cost of $0.12. Meanwhile, o1-mini completed this phase faster (56.8 seconds) but at a slightly higher cost ($0.16). For Plan Formulation, gpt-4o was both the fastest (23.3 seconds) and the cheapest ($0.03), followed closely by o1-preview in cost ($0.04) but not in speed (33.1 seconds). The most expensive phase across models was Report Writing, where costs were driven by the increased computational resources required for writing a long document. o1-preview incurred particularly high costs in this phase ($9.58) despite producing comparable outputs in terms of task success rates.

##### Success Rates

Overall, every model exhibits reasonably high reliability, with o1-preview achieving the highest average subtask success rate (95.7%) for the entire workflow. Both gpt-4o and o1-mini followed closely at 94.3% and 92.8%. While most tasks had 100% success rate for each model, the literature review phase had a high rate of failure, at 60%, 70%, and 80% for gpt-4o, o1-mini, and o1-preview respectively. The Data Preparation phase showed minor challenges, with o1-mini recording an 80% success rate in Data Preparation, compared to gpt-4o’s 100% success rate and o1-preview at a 90% success rate.

### 4.4 Evaluating mle-solver on MLE-Bench

Figure 9: Average score of four methods (MLAB, OpenHands, AIDE, and mle-solver) on a subset of MLE-Bench.

Evaluating the entire Agent Laboratory workflow does not contain much information about the ability of mle-solver specifically to solve individual ML problems. In order to evaluate mle-solver more objectively, we use a subset of 10 ML challenges from MLE-Bench ([Chan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib17)). MLE-Bench is a benchmark designed to assess the capability of agents in handling real-world ML tasks on Kaggle competitions. This benchmark compares agent performances with human baselines, scoring agents with Kaggle’s medal system, and incorporating mechanisms to mitigate contamination and plagiarism risks. We include all challenges focusing on text and tabular data from the low complexity category of MLE-Bench. We provide as input to mle-solver the following: Kaggle dataset description, distilled knowledge from Kaggle notebooks, as well as an accessible train and dev set. Instead of using an LLM scoring function, the mle-solver score is evaluated on the dev set, which is a 20% random sample taken from the original training set, and the training set is represented by the other 80% split. All data (dev, test, train) is placed into arrays using the numpy library instead of providing file locations in order to better emulate the data preparation phase. Once all mle-solver steps have concluded, the final code with the highest score is evaluated on the actual Kaggle test set and a benchmark score is recorded.

We compare average scores across several runs from three other methods: MLAB ([Huang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib47), gpt-4o backend), OpenHands ([Wang et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib102), gpt-4o backend), and AIDE ([Schmidt et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib88), o1-preview backend). While mle-solver submitted valid solutions for all MLE-Bench challenges within two hours, prior methods often failed to submit, complicating scoring. We thus calculated average scores by excluding invalid submissions from other works and averaging valid ones. We find that Agent Laboratory’s mle-solver is more consistently high scoring than other solvers, with mle-solver obtaining four medals (two gold, one silver, and one bronze) compared with OpenHands (gpt-4o) obtaining two medals (two gold), AIDE (o1-preview) obtaining two medals (one gold, one bronze) and MLAB obtaining zero medals. Additionally, mle-solver obtained above median human performance on six out of ten benchmarks, with AIDE obtaining five out of ten, OpenHands two out of ten, and MLAB zero out of ten. A detailed overview is provided in Figure [9](https://arxiv.org/html/2501.04227#S4.F9 "Figure 9 ‣ 4.4 Evaluating mle-solver on MLE-Bench ‣ 4 Results ‣ Agent Laboratory: Using LLM Agents as Research Assistants").

## 5 Limitations

While our results suggest that Agent Laboratory demonstrates strong performance as a research tool, we now turn to a discussion of limitations that could inform future work. While some of these are also limitations of LLMs themselves, others are not, and we nonetheless provide a thorough and critical discussion of our work. We hope that progress in autonomous research will address these limitations.

### 5.1 Workflow limitations

##### Challenges with self-evaluation

The paper-solver is being evaluated for quality by using LLMs emulated NeurIPS reviewers. This has two limitations: (1) while the reviewing agents were shown to have high alignment with real reviewers ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)), qualitatively research reports from Agent Laboratory are less satisfying than research papers from The AI Scientist ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)), with ours having lower quality figures, despite Agent Laboratory papers obtaining higher scores overall. (2) The research reports produced by Agent Laboratory are not meant to replace the paper writing process done by humans as it was in The AI Scientist, rather it is meant to provide a report for the human to understand what has been accomplished, so that they can scale up the experiment and write their own research report. However, we nonetheless use NeurIPS reviewer scores as the heuristic for the quality of our presented paper-solver, which aims to evaluate the reports from the perspective of a complete research paper. Additionally, contrasting with [Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66) demonstrate that LLMs perform less reliably for self-evaluation compared with human reviewers, with lower agreement scores (53.3% vs. 56.1%). Although LLMs demonstrate reasonable consistency, this may stem from reliance on superficial patterns rather than robust evaluation criteria, resulting in discrepancies between LLM and human rankings. This limits LLMs in subjective tasks like research idea evaluation, which is the foundation of mle-solver and paper-solver.

##### Challenges with automated structure

There are also some limitations that present themselves due to the structure enforced in the workflow. For example, paper-solver is encouraged to a organize the paper into a relatively fixed structure (abstract, introduction, etc), which disallows unique paper organizations and section orders. Another limitation is that mle-solver and paper-solver are limited to generating only two figures for the paper. This can be solved in future work, by allowing all of the figures generated by the mle-solver (without restriction) to be incorporated into paper-solver by detecting image files and providing those paths to the solver. Agent Laboratory is also not able to manage repository-level code on its own, but rather the appropriate files are provided to it at each necessary step and files are saved based on which phase produced the file. Enabling flexible repository-level file modification and execution is a clear next step for future work.

##### Challenges with hallucination

While uncommon, we also found that in some of the research papers, particularly from lower performing models, such as gpt-4o, there were hallucinations regarding experimental results that did not occur, such as the following example from a gpt-4o paper on the topic of Are image transformers more or less sensitive to noise than convolutional networks?: “Hyperparameter optimization played a crucial role in achieving these results. The learning rate was set at 0.001, with a batch size of 32, and the number of reasoning steps L\={l1,l2,…,ln} varied between 5 to 10, depending on the complexity of the query. The model was trained over 50 epochs, with early stopping criteria applied to prevent overfitting." While the issue of hallucination is more generally a problem with LLMs themselves, future work must appropriately address these challenges in order to prevent misinformation from being propagated when using automated research tools.

### 5.2 Common failure modes

In addition to the limitations outlined in Section [5.1](https://arxiv.org/html/2501.04227#S5.SS1 "5.1 Workflow limitations ‣ 5 Limitations ‣ Agent Laboratory: Using LLM Agents as Research Assistants"), we also outline common failure modes observed during the runtime of Agent Laboratory. We report a list of the most common failure modes observed below:

-   •
    
    Many of the more capable models (gpt-4o, o1-mini, o1-preview) struggled with instruction-following during the literature review phase, and had a tendency to repeatedly use the summarize command until the maximum phase steps have been reached, leading to a termination.
    
-   •
    
    Retrieved papers during the literature review phase had been observed to reach the maximum token limit for some models.
    
-   •
    
    Experiments run by mle-solver sometimes obtain 0% accuracy for all tested methods which is not corrected by the agent by the time mle-solver runs out of solving steps.
    
-   •
    
    mle-solver has a tendency to edit line 0 more than other lines in the code, causing to the replace command to more often lead to successful code compiles.
    
-   •
    
    Printed output from the data preparation or experimental results can lead to the LLMs reaching their token limit.
    
-   •
    
    mle-solver often generated the python exit() command, which terminated the entire process. This had to be detected and removed manually.
    
-   •
    
    mle-solver has been observed to run system commands on the host computer using the subprocess.run() command. While nothing problematic has been observed, safeguards should be implemented around this.
    
-   •
    
    paper-solver often struggles to search for relevant papers using the arXiv engine. Before a search time-limit was enforced, it could take up to 100 tries for a successful search query to return any papers. A limit of 5 was place thereafter to prevent this cycle.
    

### 5.3 Ethical considerations

Agent Laboratory offers potential to accelerate the field of machine learning research by automating time-intensive tasks and enabling researchers to focus on ideation and experimental design. However, its capabilities also bring ethical challenges that require careful consideration. The ability to autonomously generate research code, reports, and experiment plans may inadvertently lower the barriers to producing substandard or misleading scientific outputs. This could overwhelm peer review systems and jeopardize the integrity of academic discourse. Furthermore, the automated processes may reflect or even amplify biases inherent in the underlying datasets or algorithms, leading to skewed outcomes in research findings. Transparent disclosure of AI involvement in research outputs is important in order to mitigate such risks and maintain accountability.

There are additional concerns about potential misuse of Agent Laboratory for unethical purposes, such as developing harmful technologies or generating content that bypasses ethical oversight. For instance, the misuse of autonomous research agents in fields like cybersecurity could lead to the automated creation of malware ([Xu et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib107); [Happe & Cito (2023)](https://arxiv.org/html/2501.04227#bib.bib40); [Francia et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib31); [Begou et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib10)) or in environmental studies, it may generate biased analyses that downplay climate risks or overstate the benefits of certain interventions. Moreover, as the platform matures, the risk of its misuse increases if safeguards are not implemented to ensure alignment with ethical research standards ([Watkins (2024)](https://arxiv.org/html/2501.04227#bib.bib103); [Jiao et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib50)). Thus, while Agent Laboratory demonstrates immense promise for accelerating scientific discovery, there is a need for robust governance mechanisms to ensure that the underlying LLMs produce content that aligns with ethical principles and societal values.

## 6 Discussion

In this paper, we introduce Agent Laboratory, an open-source LLM agent framework for accelerating the individual’s ability to perform research in machine learning. Unlike fully automated research pipelines that attempt to conceive their own research directions, Agent Laboratory is designed as a co-pilot, enabling a more human-centric mode of scientific exploration. Because of this, we present results from human-centered experiments. Our initial evaluations focused on the quality of generated papers in autonomous mode, assessing human evaluations of experimental and report quality, usefulness, as well as reviewer scores based on standard academic criteria across different language models. We also assessed the effectiveness of Agent Laboratory in co-pilot mode, comparing its performance with autonomous mode, receiving positive feedback from researchers.

The findings of this work highlight the variability in performance across LLM backends, with the o1-preview model being rated most useful, while o1-mini demonstrated the highest experimental quality. Autonomous mode outputs, although generally well-received, revealed gaps when evaluated against human expectations for high-quality research papers, particularly in terms of clarity and soundness. We also find that automated reviewer scores do not predict human reviewer scores demonstrating the importance of human evaluations in automated research. Integrating human feedback in co-pilot mode overall produced higher-quality outputs than autonomous mode, with higher scores across most metrics. The co-pilot feature in Agent Laboratory is overall found to have high utility and usability when rated by human users, with most participants deciding to continue usage after their experience. Finally, runtime and cost analyses demonstrated the efficiency of the framework, with the gpt-4o backend offering the fastest execution and lowest costs. Finally, evaluations of the mle-solver on MLE-Bench demonstrates improved ability to solve general ML problems over previous methods.

Agent Laboratory builds upon an emerging trend in the use of language agents for science, where previous works have shown the potential of LLMs to generate research ideas ([Baek et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib9); [Si et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib91); [Li et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib59)), implement machine learning projects ([Chan et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib17); [Jing et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib52); [Huang et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib47)), and even produce scientific papers ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)). While many of these prior efforts leverage LLMs as tools to be applied at discrete stages, Agent Laboratory integrates these processes into a single, continuous pipeline that can scale and adapt to the researcher’s desired level of interaction and compute availability. This allows human researchers to focus more on conceptual design and critical thinking, allowing Agent Laboratory to handle more tedious tasks, such as preprocessing data and coding.

We overcome the limitations of prior work, such as The AI Scientist ([Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66)) which does not have human-computer interaction, Virtual Lab ([Swanson et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib93)) which does not have access to up-to-date knowledge, does not generate research papers, and was only demonstrated for nanobody design, as well as ChemCrow ([M. Bran et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib68)) and Coscientist ([Boiko et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib12)) which cannot solve open-ended research problems. However, as was outlined in Limitations (Section [5](https://arxiv.org/html/2501.04227#S5 "5 Limitations ‣ Agent Laboratory: Using LLM Agents as Research Assistants")), there are many areas for improvement in our approach which can be addressed in future work.

A valuable direction for future research could involve a longitudinal study comparing researchers’ outcomes when conducting studies with and without Agent Laboratory, as the human evaluations in this work provide only a snapshot of its utility. Studies of this kind have been conducted with other workflow automation tools, such as GitHub Copilot ([Dohmke et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib26); [Ziegler et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib114)), and have demonstrated promising potential for improving productivity. Such a study would help to better understand the long-term impact of Agent Laboratory on research efficiency and its role in improving scientific discovery. It may also be worth exploring automatic agent workflow ([Li et al. (2024c)](https://arxiv.org/html/2501.04227#bib.bib61); [Zhuge et al. (2024)](https://arxiv.org/html/2501.04227#bib.bib113); [Hong et al. (2023)](https://arxiv.org/html/2501.04227#bib.bib43); [Zhang et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib110)) and agent generation techniques ([Chen et al. (2023a)](https://arxiv.org/html/2501.04227#bib.bib18); [Hu et al. (2024a)](https://arxiv.org/html/2501.04227#bib.bib44)) to optimize the Agent Laboratory workflow.

##### Conclusion

In conclusion, Agent Laboratory stands as a promising step toward more efficient, human-centered research workflows that leverage the power of LLMs. By integrating specialized autonomous agents guided by human oversight, our approach can help researchers spend less time on repetitive tasks and more time on the creative, conceptual aspects of their work. We hope that Agent Laboratory may ultimately serve as a tool to enable scientific discovery.

## References

-   Abramovich et al. (2024) Talor Abramovich, Meet Udeshi, Minghao Shao, Kilian Lieret, Haoran Xi, Kimberly Milner, Sofija Jancheska, John Yang, Carlos E Jimenez, Farshad Khorrami, et al. Enigma: Enhanced interactive generative model agent for ctf challenges. _arXiv preprint arXiv:2409.16165_, 2024.
-   Achiam et al. (2023) Josh Achiam, Steven Adler, Sandhini Agarwal, Lama Ahmad, Ilge Akkaya, Florencia Leoni Aleman, Diogo Almeida, Janko Altenschmidt, Sam Altman, Shyamal Anadkat, et al. Gpt-4 technical report. _arXiv preprint arXiv:2303.08774_, 2023.
-   Ajith et al. (2024) Anirudh Ajith, Mengzhou Xia, Alexis Chevalier, Tanya Goyal, Danqi Chen, and Tianyu Gao. Litsearch: A retrieval benchmark for scientific literature search. _arXiv preprint arXiv:2407.18940_, 2024.
-   AL et al. (2024) Altera AL, Andrew Ahn, Nic Becker, Stephanie Carroll, Nico Christie, Manuel Cortes, Arda Demirci, Melissa Du, Frankie Li, Shuying Luo, et al. Project sid: Many-agent simulations toward ai civilization. _arXiv preprint arXiv:2411.00114_, 2024.
-   Anderson et al. (2024) Barrett R Anderson, Jash Hemant Shah, and Max Kreminski. Homogenization effects of large language models on human creative ideation. In _Proceedings of the 16th Conference on Creativity & Cognition_, pp. 413–425, 2024.
-   Anthropic (2024) AI Anthropic. The claude 3 model family: Opus, sonnet, haiku. _Claude-3 Model Card_, 1, 2024.
-   Ashkinaze et al. (2024) Joshua Ashkinaze, Julia Mendelsohn, Li Qiwei, Ceren Budak, and Eric Gilbert. How ai ideas affect the creativity, diversity, and evolution of human ideas: Evidence from a large, dynamic experiment. _arXiv preprint arXiv:2401.13481_, 2024.
-   Ashokkumar et al. (2024) Ashwini Ashokkumar, Luke Hewitt, Isaias Ghezae, and Robb Willer. Predicting results of social science experiments using large language models. Technical report, Technical report, Working Paper, 2024.
-   Baek et al. (2024) Jinheon Baek, Sujay Kumar Jauhar, Silviu Cucerzan, and Sung Ju Hwang. Researchagent: Iterative research idea generation over scientific literature with large language models. _arXiv preprint arXiv:2404.07738_, 2024.
-   Begou et al. (2023) Nils Begou, Jérémy Vinoy, Andrzej Duda, and Maciej Korczyński. Exploring the dark side of ai: Advanced phishing attack design and deployment using chatgpt. In _2023 IEEE Conference on Communications and Network Security (CNS)_, pp. 1–6. IEEE, 2023.
-   Black et al. (2024) Kevin Black, Noah Brown, Danny Driess, Adnan Esmail, Michael Equi, Chelsea Finn, Niccolo Fusai, Lachy Groom, Karol Hausman, Brian Ichter, et al. π0: A vision-language-action flow model for general robot control. _arXiv preprint arXiv:2410.24164_, 2024.
-   Boiko et al. (2023) Daniil A Boiko, Robert MacKnight, Ben Kline, and Gabe Gomes. Autonomous chemical research with large language models. _Nature_, 624(7992):570–578, 2023.
-   Brohan et al. (2022) Anthony Brohan, Noah Brown, Justice Carbajal, Yevgen Chebotar, Joseph Dabis, Chelsea Finn, Keerthana Gopalakrishnan, Karol Hausman, Alex Herzog, Jasmine Hsu, et al. Rt-1: Robotics transformer for real-world control at scale. _arXiv preprint arXiv:2212.06817_, 2022.
-   Brohan et al. (2023) Anthony Brohan, Noah Brown, Justice Carbajal, Yevgen Chebotar, Xi Chen, Krzysztof Choromanski, Tianli Ding, Danny Driess, Avinava Dubey, Chelsea Finn, et al. Rt-2: Vision-language-action models transfer web knowledge to robotic control. _arXiv preprint arXiv:2307.15818_, 2023.
-   Brown (2020) Tom B Brown. Language models are few-shot learners. _arXiv preprint arXiv:2005.14165_, 2020.
-   Chakrabarty et al. (2024) Tuhin Chakrabarty, Philippe Laban, Divyansh Agarwal, Smaranda Muresan, and Chien-Sheng Wu. Art or artifice? large language models and the false promise of creativity. In _Proceedings of the CHI Conference on Human Factors in Computing Systems_, pp. 1–34, 2024.
-   Chan et al. (2024) Jun Shern Chan, Neil Chowdhury, Oliver Jaffe, James Aung, Dane Sherburn, Evan Mays, Giulio Starace, Kevin Liu, Leon Maksin, Tejal Patwardhan, et al. Mle-bench: Evaluating machine learning agents on machine learning engineering. _arXiv preprint arXiv:2410.07095_, 2024.
-   Chen et al. (2023a) Guangyao Chen, Siwei Dong, Yu Shu, Ge Zhang, Jaward Sesay, Börje F Karlsson, Jie Fu, and Yemin Shi. Autoagents: A framework for automatic agent generation. _arXiv preprint arXiv:2309.17288_, 2023a.
-   Chen et al. (2021) Mark Chen, Jerry Tworek, Heewoo Jun, Qiming Yuan, Henrique Ponde De Oliveira Pinto, Jared Kaplan, Harri Edwards, Yuri Burda, Nicholas Joseph, Greg Brockman, et al. Evaluating large language models trained on code. _arXiv preprint arXiv:2107.03374_, 2021.
-   Chen et al. (2023b) Weize Chen, Yusheng Su, Jingwei Zuo, Cheng Yang, Chenfei Yuan, Chi-Min Chan, Heyang Yu, Yaxi Lu, Yi-Hsin Hung, Chen Qian, et al. Agentverse: Facilitating multi-agent collaboration and exploring emergent behaviors. In _The Twelfth International Conference on Learning Representations_, 2023b.
-   Chen et al. (2024a) Xiuying Chen, Tairan Wang, Taicheng Guo, Kehan Guo, Juexiao Zhou, Haoyang Li, Mingchen Zhuge, Jürgen Schmidhuber, Xin Gao, and Xiangliang Zhang. Scholarchemqa: Unveiling the power of language models in chemical research question answering. _arXiv preprint arXiv:2407.16931_, 2024a.
-   Chen et al. (2024b) Ziru Chen, Shijie Chen, Yuting Ning, Qianheng Zhang, Boshi Wang, Botao Yu, Yifei Li, Zeyi Liao, Chen Wei, Zitong Lu, et al. Scienceagentbench: Toward rigorous assessment of language agents for data-driven scientific discovery. _arXiv preprint arXiv:2410.05080_, 2024b.
-   D’Arcy et al. (2024) Mike D’Arcy, Tom Hope, Larry Birnbaum, and Doug Downey. Marg: Multi-agent review generation for scientific papers. _arXiv preprint arXiv:2401.04259_, 2024.
-   Deng et al. (2024) Xiang Deng, Yu Gu, Boyuan Zheng, Shijie Chen, Sam Stevens, Boshi Wang, Huan Sun, and Yu Su. Mind2web: Towards a generalist agent for the web. _Advances in Neural Information Processing Systems_, 36, 2024.
-   Ding et al. (2024) Ning Ding, Shang Qu, Linhai Xie, Yifei Li, Zaoqu Liu, Kaiyan Zhang, Yibai Xiong, Yuxin Zuo, Zhangren Chen, Ermo Hua, et al. Automating exploratory proteomics research via language models. _arXiv preprint arXiv:2411.03743_, 2024.
-   Dohmke et al. (2023) Thomas Dohmke, Marco Iansiti, and Greg Richards. Sea change in software development: Economic and productivity analysis of the ai-powered developer lifecycle. _arXiv preprint arXiv:2306.15033_, 2023.
-   Dubey et al. (2024) Abhimanyu Dubey, Abhinav Jauhri, Abhinav Pandey, Abhishek Kadian, Ahmad Al-Dahle, Aiesha Letman, Akhil Mathur, Alan Schelten, Amy Yang, Angela Fan, et al. The llama 3 herd of models. _arXiv preprint arXiv:2407.21783_, 2024.
-   Fang et al. (2024) Richard Fang, Rohan Bindu, Akul Gupta, Qiusi Zhan, and Daniel Kang. Llm agents can autonomously hack websites. _arXiv preprint arXiv:2402.06664_, 2024.
-   Fawzi et al. (2022) Alhussein Fawzi, Matej Balog, Aja Huang, Thomas Hubert, Bernardino Romera-Paredes, Mohammadamin Barekatain, Alexander Novikov, Francisco J R Ruiz, Julian Schrittwieser, Grzegorz Swirszcz, et al. Discovering faster matrix multiplication algorithms with reinforcement learning. _Nature_, 610(7930):47–53, 2022.
-   Feng et al. (2024) Xidong Feng, Yicheng Luo, Ziyan Wang, Hongrui Tang, Mengyue Yang, Kun Shao, David Mguni, Yali Du, and Jun Wang. Chessgpt: Bridging policy learning and language modeling. _Advances in Neural Information Processing Systems_, 36, 2024.
-   Francia et al. (2024) Jerson Francia, Derek Hansen, Ben Schooley, Matthew Taylor, Shydra Murray, and Greg Snow. Assessing ai vs human-authored spear phishing sms attacks: An empirical study using the trapd method. _arXiv preprint arXiv:2406.13049_, 2024.
-   Ghafarollahi & Buehler (2024a) Alireza Ghafarollahi and Markus J Buehler. Protagents: protein discovery via large language model multi-agent collaborations combining physics and machine learning. _Digital Discovery_, 2024a.
-   Ghafarollahi & Buehler (2024b) Alireza Ghafarollahi and Markus J Buehler. Sciagents: Automating scientific discovery through multi-agent intelligent graph reasoning. _arXiv preprint arXiv:2409.05556_, 2024b.
-   Grosnit et al. (2024) Antoine Grosnit, Alexandre Maraval, James Doran, Giuseppe Paolo, Albert Thomas, Refinath Shahul Hameed Nabeezath Beevi, Jonas Gonzalez, Khyati Khandelwal, Ignacio Iacobacci, Abdelhakim Benechehab, et al. Large language models orchestrating structured reasoning achieve kaggle grandmaster level. _arXiv preprint arXiv:2411.03562_, 2024.
-   Gu et al. (2024) Ken Gu, Ruoxi Shang, Ruien Jiang, Keying Kuang, Richard-John Lin, Donghe Lyu, Yue Mao, Youran Pan, Teng Wu, Jiaqian Yu, et al. Blade: Benchmarking language model agents for data-driven science. _arXiv preprint arXiv:2408.09667_, 2024.
-   Guo et al. (2024) Siyuan Guo, Cheng Deng, Ying Wen, Hechang Chen, Yi Chang, and Jun Wang. Ds-agent: Automated data science by empowering large language models with case-based reasoning. _arXiv preprint arXiv:2402.17453_, 2024.
-   Gur et al. (2023) Izzeddin Gur, Hiroki Furuta, Austin Huang, Mustafa Safdari, Yutaka Matsuo, Douglas Eck, and Aleksandra Faust. A real-world webagent with planning, long context understanding, and program synthesis. _arXiv preprint arXiv:2307.12856_, 2023.
-   Hai et al. (2024) Nam Le Hai, Dung Manh Nguyen, and Nghi DQ Bui. Repoexec: Evaluate code generation with a repository-level executable benchmark. _arXiv preprint arXiv:2406.11927_, 2024.
-   Hao et al. (2024) Shibo Hao, Tianyang Liu, Zhen Wang, and Zhiting Hu. Toolkengpt: Augmenting frozen language models with massive tools via tool embeddings. _Advances in neural information processing systems_, 36, 2024.
-   Happe & Cito (2023) Andreas Happe and Jürgen Cito. Getting pwn’d by ai: Penetration testing with large language models. In _Proceedings of the 31st ACM Joint European Software Engineering Conference and Symposium on the Foundations of Software Engineering_, pp. 2082–2086, 2023.
-   Hayes et al. (2024) Tomas Hayes, Roshan Rao, Halil Akin, Nicholas J Sofroniew, Deniz Oktay, Zeming Lin, Robert Verkuil, Vincent Q Tran, Jonathan Deaton, Marius Wiggert, et al. Simulating 500 million years of evolution with a language model. _bioRxiv_, pp. 2024–07, 2024.
-   He et al. (2024) Hongliang He, Wenlin Yao, Kaixin Ma, Wenhao Yu, Yong Dai, Hongming Zhang, Zhenzhong Lan, and Dong Yu. Webvoyager: Building an end-to-end web agent with large multimodal models. _arXiv preprint arXiv:2401.13919_, 2024.
-   Hong et al. (2023) Sirui Hong, Xiawu Zheng, Jonathan Chen, Yuheng Cheng, Jinlin Wang, Ceyao Zhang, Zili Wang, Steven Ka Shing Yau, Zijuan Lin, Liyang Zhou, et al. Metagpt: Meta programming for multi-agent collaborative framework. _arXiv preprint arXiv:2308.00352_, 2023.
-   Hu et al. (2024a) Shengran Hu, Cong Lu, and Jeff Clune. Automated design of agentic systems. _arXiv preprint arXiv:2408.08435_, 2024a.
-   Hu et al. (2024b) Xueyu Hu, Ziyu Zhao, Shuang Wei, Ziwei Chai, Qianli Ma, Guoyin Wang, Xuwu Wang, Jing Su, Jingjing Xu, Ming Zhu, et al. Infiagent-dabench: Evaluating agents on data analysis tasks. _arXiv preprint arXiv:2401.05507_, 2024b.
-   Huang et al. (2022) Jiaxin Huang, Shixiang Shane Gu, Le Hou, Yuexin Wu, Xuezhi Wang, Hongkun Yu, and Jiawei Han. Large language models can self-improve. _arXiv preprint arXiv:2210.11610_, 2022.
-   Huang et al. (2024) Qian Huang, Jian Vora, Percy Liang, and Jure Leskovec. Mlagentbench: Evaluating language agents on machine learning experimentation. In _Forty-first International Conference on Machine Learning_, 2024.
-   Hurst et al. (2024) Aaron Hurst, Adam Lerer, Adam P Goucher, Adam Perelman, Aditya Ramesh, Aidan Clark, AJ Ostrow, Akila Welihinda, Alan Hayes, Alec Radford, et al. Gpt-4o system card. _arXiv preprint arXiv:2410.21276_, 2024.
-   Ifargan et al. (2024) Tal Ifargan, Lukas Hafner, Maor Kern, Ori Alcalay, and Roy Kishony. Autonomous llm-driven research from data to human-verifiable research papers. _arXiv preprint arXiv:2404.17605_, 2024.
-   Jiao et al. (2024) Junfeng Jiao, Saleh Afroogh, Yiming Xu, and Connor Phillips. Navigating llm ethics: Advancements, challenges, and future directions. _arXiv preprint arXiv:2406.18841_, 2024.
-   Jimenez et al. (2023) Carlos E Jimenez, John Yang, Alexander Wettig, Shunyu Yao, Kexin Pei, Ofir Press, and Karthik Narasimhan. Swe-bench: Can language models resolve real-world github issues? _arXiv preprint arXiv:2310.06770_, 2023.
-   Jing et al. (2024) Liqiang Jing, Zhehui Huang, Xiaoyang Wang, Wenlin Yao, Wenhao Yu, Kaixin Ma, Hongming Zhang, Xinya Du, and Dong Yu. Dsbench: How far are data science agents to becoming data science experts? _arXiv preprint arXiv:2409.07703_, 2024.
-   Jumper et al. (2021) John Jumper, Richard Evans, Alexander Pritzel, Tim Green, Michael Figurnov, Olaf Ronneberger, Kathryn Tunyasuvunakool, Russ Bates, Augustin Žídek, Anna Potapenko, et al. Highly accurate protein structure prediction with alphafold. _nature_, 596(7873):583–589, 2021.
-   Kang & Xiong (2024) Hao Kang and Chenyan Xiong. Researcharena: Benchmarking llms’ ability to collect and organize information as research agents. _arXiv preprint arXiv:2406.10291_, 2024.
-   Kim et al. (2024) Ji Woong Kim, Tony Z Zhao, Samuel Schmidgall, Anton Deguet, Marin Kobilarov, Chelsea Finn, and Axel Krieger. Surgical robot transformer (srt): Imitation learning for surgical tasks. In _8th Annual Conference on Robot Learning_, 2024.
-   Lála et al. (2023) Jakub Lála, Odhran O’Donoghue, Aleksandar Shtedritski, Sam Cox, Samuel G Rodriques, and Andrew D White. Paperqa: Retrieval-augmented generative agent for scientific research. _arXiv preprint arXiv:2312.07559_, 2023.
-   Lehr et al. (2024) Steven A Lehr, Aylin Caliskan, Suneragiri Liyanage, and Mahzarin R Banaji. Chatgpt as research scientist: Probing gpt’s capabilities as a research librarian, research ethicist, data generator, and data predictor. _Proceedings of the National Academy of Sciences_, 121(35):e2404328121, 2024.
-   Li et al. (2023) Guohao Li, Hasan Hammoud, Hani Itani, Dmitrii Khizbullin, and Bernard Ghanem. Camel: Communicative agents for" mind" exploration of large language model society. _Advances in Neural Information Processing Systems_, 36:51991–52008, 2023.
-   Li et al. (2024a) Long Li, Weiwen Xu, Jiayan Guo, Ruochen Zhao, Xingxuan Li, Yuqian Yuan, Boqiang Zhang, Yuming Jiang, Yifei Xin, Ronghao Dang, et al. Chain of ideas: Revolutionizing research via novel idea development with llm agents. _arXiv preprint arXiv:2410.13185_, 2024a.
-   Li et al. (2024b) Sihang Li, Jin Huang, Jiaxi Zhuang, Yaorui Shi, Xiaochen Cai, Mingjun Xu, Xiang Wang, Linfeng Zhang, Guolin Ke, and Hengxing Cai. Scilitllm: How to adapt llms for scientific literature understanding. _arXiv preprint arXiv:2408.15545_, 2024b.
-   Li et al. (2024c) Zelong Li, Shuyuan Xu, Kai Mei, Wenyue Hua, Balaji Rama, Om Raheja, Hao Wang, He Zhu, and Yongfeng Zhang. Autoflow: Automated workflow generation for large language model agents. _arXiv preprint arXiv:2407.12821_, 2024c.
-   Liang et al. (2024) Weixin Liang, Yuhui Zhang, Hancheng Cao, Binglu Wang, Daisy Yi Ding, Xinyu Yang, Kailas Vodrahalli, Siyu He, Daniel Scott Smith, Yian Yin, et al. Can large language models provide useful feedback on research papers? a large-scale empirical analysis. _NEJM AI_, 1(8):AIoa2400196, 2024.
-   Lin et al. (2024) Xinna Lin, Siqi Ma, Junjie Shan, Xiaojing Zhang, Shell Xu Hu, Tiannan Guo, Stan Z Li, and Kaicheng Yu. Biokgbench: A knowledge graph checking benchmark of ai agent for biomedical science. _arXiv preprint arXiv:2407.00466_, 2024.
-   Liu et al. (2024) Yiren Liu, Si Chen, Haocong Cheng, Mengxia Yu, Xiao Ran, Andrew Mo, Yiliu Tang, and Yun Huang. How ai processing delays foster creativity: Exploring research question co-creation with an llm-based agent. In _Proceedings of the CHI Conference on Human Factors in Computing Systems_, pp. 1–25, 2024.
-   Lu et al. (2024a) Chris Lu, Cong Lu, Robert Tjarko Lange, Jakob Foerster, Jeff Clune, and David Ha. The ai scientist: Towards fully automated open-ended scientific discovery. _arXiv preprint arXiv:2408.06292_, 2024a.
-   Lu et al. (2024b) Chris Lu, Cong Lu, Robert Tjarko Lange, Jakob Foerster, Jeff Clune, and David Ha. The AI Scientist: Towards fully automated open-ended scientific discovery. _arXiv preprint arXiv:2408.06292_, 2024b.
-   Luo et al. (2024) Xiaoliang Luo, Akilles Rechardt, Guangzhi Sun, Kevin K Nejad, Felipe Yáñez, Bati Yilmaz, Kangjoo Lee, Alexandra O Cohen, Valentina Borghesani, Anton Pashkov, et al. Large language models surpass human experts in predicting neuroscience results. _Nature Human Behaviour_, pp. 1–11, 2024.
-   M. Bran et al. (2024) Andres M. Bran, Sam Cox, Oliver Schilter, Carlo Baldassari, Andrew D White, and Philippe Schwaller. Augmenting large language models with chemistry tools. _Nature Machine Intelligence_, pp. 1–11, 2024.
-   Majumder et al. (2024) Bodhisattwa Prasad Majumder, Harshit Surana, Dhruv Agarwal, Bhavana Dalvi Mishra, Abhijeetsingh Meena, Aryan Prakhar, Tirth Vora, Tushar Khot, Ashish Sabharwal, and Peter Clark. Discoverybench: Towards data-driven discovery with large language models. _arXiv preprint arXiv:2407.01725_, 2024.
-   Manning et al. (2024) Benjamin S Manning, Kehang Zhu, and John J Horton. Automated social science: Language models as scientist and subjects. Technical report, National Bureau of Economic Research, 2024.
-   McDuff et al. (2023) Daniel McDuff, Mike Schaekermann, Tao Tu, Anil Palepu, Amy Wang, Jake Garrison, Karan Singhal, Yash Sharma, Shekoofeh Azizi, Kavita Kulkarni, et al. Towards accurate differential diagnosis with large language models. _arXiv preprint arXiv:2312.00164_, 2023.
-   Merchant et al. (2023) Amil Merchant, Simon Batzner, Samuel S Schoenholz, Muratahan Aykol, Gowoon Cheon, and Ekin Dogus Cubuk. Scaling deep learning for materials discovery. _Nature_, 624(7990):80–85, 2023.
-   Nijkamp et al. (2022) Erik Nijkamp, Bo Pang, Hiroaki Hayashi, Lifu Tu, Huan Wang, Yingbo Zhou, Silvio Savarese, and Caiming Xiong. Codegen: An open large language model for code with multi-turn program synthesis. _arXiv preprint arXiv:2203.13474_, 2022.
-   OpenAI (2022) OpenAI. Introducing chatgpt. [https://openai.com/index/chatgpt/](https://openai.com/index/chatgpt/), November 2022. Blog post.
-   OpenAI (2024) OpenAI. Introducing openai o1-preview, September 2024. URL [https://openai.com/index/introducing-openai-o1-preview/](https://openai.com/index/introducing-openai-o1-preview/). Accessed: 2024-09.
-   Padmakumar & He (2024) Vishakh Padmakumar and He He. Does writing with language models reduce content diversity? In _The Twelfth International Conference on Learning Representations_, 2024.
-   Phan et al. (2024) Huy Nhat Phan, Tien N Nguyen, Phong X Nguyen, and Nghi DQ Bui. Hyperagent: Generalist software engineering agents to solve coding tasks at scale. _arXiv preprint arXiv:2409.16299_, 2024.
-   Press et al. (2024) Ori Press, Andreas Hochlehnert, Ameya Prabhu, Vishaal Udandarao, Ofir Press, and Matthias Bethge. Citeme: Can language models accurately cite scientific claims? _arXiv preprint arXiv:2407.12861_, 2024.
-   Putta et al. (2024) Pranav Putta, Edmund Mills, Naman Garg, Sumeet Motwani, Chelsea Finn, Divyansh Garg, and Rafael Rafailov. Agent q: Advanced reasoning and learning for autonomous ai agents. _arXiv preprint arXiv:2408.07199_, 2024.
-   Pyzer-Knapp et al. (2022) Edward O Pyzer-Knapp, Jed W Pitera, Peter WJ Staar, Seiji Takeda, Teodoro Laino, Daniel P Sanders, James Sexton, John R Smith, and Alessandro Curioni. Accelerating materials discovery using artificial intelligence, high performance computing and robotics. _npj Computational Materials_, 8(1):84, 2022.
-   Qian et al. (2023) Chen Qian, Yufan Dang, Jiahao Li, Wei Liu, Zihao Xie, Yifei Wang, Weize Chen, Cheng Yang, Xin Cong, Xiaoyin Che, et al. Experiential co-learning of software-developing agents. _arXiv preprint arXiv:2312.17025_, 2023.
-   Qian et al. (2024) Chen Qian, Wei Liu, Hongzhang Liu, Nuo Chen, Yufan Dang, Jiahao Li, Cheng Yang, Weize Chen, Yusheng Su, Xin Cong, et al. Chatdev: Communicative agents for software development. In _Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)_, pp. 15174–15186, 2024.
-   Qin et al. (2023) Yujia Qin, Shihao Liang, Yining Ye, Kunlun Zhu, Lan Yan, Yaxi Lu, Yankai Lin, Xin Cong, Xiangru Tang, Bill Qian, et al. Toolllm: Facilitating large language models to master 16000+ real-world apis. _arXiv preprint arXiv:2307.16789_, 2023.
-   Renze & Guven (2024) Matthew Renze and Erhan Guven. Self-reflection in llm agents: Effects on problem-solving performance. _arXiv preprint arXiv:2405.06682_, 2024.
-   Romera-Paredes et al. (2024) Bernardino Romera-Paredes, Mohammadamin Barekatain, Alexander Novikov, Matej Balog, M Pawan Kumar, Emilien Dupont, Francisco JR Ruiz, Jordan S Ellenberg, Pengming Wang, Omar Fawzi, et al. Mathematical discoveries from program search with large language models. _Nature_, 625(7995):468–475, 2024.
-   Schick et al. (2023) Timo Schick, Jane Dwivedi-Yu, Roberto Dessi, Roberta Raileanu, Maria Lomeli, Eric Hambro, Luke Zettlemoyer, Nicola Cancedda, and Thomas Scialom. Toolformer: Language models can teach themselves to use tools. In _Thirty-seventh Conference on Neural Information Processing Systems_, 2023. URL [https://openreview.net/forum?id=Yacmpz84TH](https://openreview.net/forum?id=Yacmpz84TH).
-   Schmidgall et al. (2024) Samuel Schmidgall, Rojin Ziaei, Carl Harris, Eduardo Reis, Jeffrey Jopling, and Michael Moor. Agentclinic: a multimodal agent benchmark to evaluate ai in simulated clinical environments. _arXiv preprint arXiv:2405.07960_, 2024.
-   Schmidt et al. (2024) Dominik Schmidt, Zhengyao Jiang, and Yuxiang Unknown. Introducing weco aide, 2024. URL [https://www.weco.ai/blog/technical-report](https://www.weco.ai/blog/technical-report).
-   Shi et al. (2017) Tianlin Shi, Andrej Karpathy, Linxi Fan, Jonathan Hernandez, and Percy Liang. World of bits: An open-domain platform for web-based agents. In _International Conference on Machine Learning_, pp. 3135–3144. PMLR, 2017.
-   Shinn et al. (2024) Noah Shinn, Federico Cassano, Ashwin Gopinath, Karthik Narasimhan, and Shunyu Yao. Reflexion: Language agents with verbal reinforcement learning. _Advances in Neural Information Processing Systems_, 36, 2024.
-   Si et al. (2024) Chenglei Si, Diyi Yang, and Tatsunori Hashimoto. Can llms generate novel research ideas? a large-scale human study with 100+ nlp researchers. _arXiv preprint arXiv:2409.04109_, 2024.
-   Song et al. (2024) Xiaoshuai Song, Muxi Diao, Guanting Dong, Zhengyang Wang, Yujia Fu, Runqi Qiao, Zhexu Wang, Dayuan Fu, Huangxuan Wu, Bin Liang, et al. Cs-bench: A comprehensive benchmark for large language models towards computer science mastery. _arXiv preprint arXiv:2406.08587_, 2024.
-   Swanson et al. (2024) Kyle Swanson, Wesley Wu, Nash L Bulaong, John E Pak, and James Zou. The virtual lab: Ai agents design new sars-cov-2 nanobodies with experimental validation. _bioRxiv_, pp. 2024–11, 2024.
-   Szymanski et al. (2023) Nathan J Szymanski, Bernardus Rendy, Yuxing Fei, Rishi E Kumar, Tanjin He, David Milsted, Matthew J McDermott, Max Gallant, Ekin Dogus Cubuk, Amil Merchant, et al. An autonomous laboratory for the accelerated synthesis of novel materials. _Nature_, 624(7990):86–91, 2023.
-   Touvron et al. (2023a) Hugo Touvron, Thibaut Lavril, Gautier Izacard, Xavier Martinet, Marie-Anne Lachaux, Timothée Lacroix, Baptiste Rozière, Naman Goyal, Eric Hambro, Faisal Azhar, et al. Llama: Open and efficient foundation language models. _arXiv preprint arXiv:2302.13971_, 2023a.
-   Touvron et al. (2023b) Hugo Touvron, Louis Martin, Kevin Stone, Peter Albert, Amjad Almahairi, Yasmine Babaei, Nikolay Bashlykov, Soumya Batra, Prajjwal Bhargava, Shruti Bhosale, et al. Llama 2: Open foundation and fine-tuned chat models. _arXiv preprint arXiv:2307.09288_, 2023b.
-   Tu et al. (2024) Tao Tu, Anil Palepu, Mike Schaekermann, Khaled Saab, Jan Freyberg, Ryutaro Tanno, Amy Wang, Brenna Li, Mohamed Amin, Nenad Tomasev, et al. Towards conversational diagnostic ai. _arXiv preprint arXiv:2401.05654_, 2024.
-   Vaswani (2017) A Vaswani. Attention is all you need. _Advances in Neural Information Processing Systems_, 2017.
-   Wan et al. (2024) Shengye Wan, Cyrus Nikolaidis, Daniel Song, David Molnar, James Crnkovich, Jayson Grace, Manish Bhatt, Sahana Chennabasappa, Spencer Whitman, Stephanie Ding, et al. Cyberseceval 3: Advancing the evaluation of cybersecurity risks and capabilities in large language models. _arXiv preprint arXiv:2408.01605_, 2024.
-   Wang et al. (2023) Guanzhi Wang, Yuqi Xie, Yunfan Jiang, Ajay Mandlekar, Chaowei Xiao, Yuke Zhu, Linxi Fan, and Anima Anandkumar. Voyager: An open-ended embodied agent with large language models. _arXiv preprint arXiv: Arxiv-2305.16291_, 2023.
-   Wang et al. (2024a) Lei Wang, Chen Ma, Xueyang Feng, Zeyu Zhang, Hao Yang, Jingsen Zhang, Zhiyuan Chen, Jiakai Tang, Xu Chen, Yankai Lin, et al. A survey on large language model based autonomous agents. _Frontiers of Computer Science_, 18(6):186345, 2024a.
-   Wang et al. (2024b) Xingyao Wang, Boxuan Li, Yufan Song, Frank F Xu, Xiangru Tang, Mingchen Zhuge, Jiayi Pan, Yueqi Song, Bowen Li, Jaskirat Singh, et al. Opendevin: An open platform for ai software developers as generalist agents. _arXiv preprint arXiv:2407.16741_, 2024b.
-   Watkins (2024) Ryan Watkins. Guidance for researchers and peer-reviewers on the ethical use of large language models (llms) in scientific research workflows. _AI and Ethics_, 4(4):969–974, 2024.
-   Wei et al. (2022) Jason Wei, Xuezhi Wang, Dale Schuurmans, Maarten Bosma, Fei Xia, Ed Chi, Quoc V Le, Denny Zhou, et al. Chain-of-thought prompting elicits reasoning in large language models. _Advances in neural information processing systems_, 35:24824–24837, 2022.
-   Weng et al. (2024) Yixuan Weng, Minjun Zhu, Guangsheng Bao, Hongbo Zhang, Jindong Wang, Yue Zhang, and Linyi Yang. Cycleresearcher: Improving automated research via automated review. _arXiv preprint arXiv:2411.00816_, 2024.
-   Wu et al. (2023) Qingyun Wu, Gagan Bansal, Jieyu Zhang, Yiran Wu, Shaokun Zhang, Erkang Zhu, Beibin Li, Li Jiang, Xiaoyun Zhang, and Chi Wang. Autogen: Enabling next-gen llm applications via multi-agent conversation framework. _arXiv preprint arXiv:2308.08155_, 2023.
-   Xu et al. (2024) Jiacen Xu, Jack W Stokes, Geoff McDonald, Xuesong Bai, David Marshall, Siyue Wang, Adith Swaminathan, and Zhou Li. Autoattacker: A large language model guided system to implement automatic cyber-attacks. _arXiv preprint arXiv:2403.01038_, 2024.
-   Yang et al. (2024) John Yang, Carlos E Jimenez, Alexander Wettig, Kilian Lieret, Shunyu Yao, Karthik Narasimhan, and Ofir Press. Swe-agent: Agent-computer interfaces enable automated software engineering. _arXiv preprint arXiv:2405.15793_, 2024.
-   Yao et al. (2024) Shunyu Yao, Dian Yu, Jeffrey Zhao, Izhak Shafran, Tom Griffiths, Yuan Cao, and Karthik Narasimhan. Tree of thoughts: Deliberate problem solving with large language models. _Advances in Neural Information Processing Systems_, 36, 2024.
-   Zhang et al. (2024a) Jiayi Zhang, Jinyu Xiang, Zhaoyang Yu, Fengwei Teng, Xionghui Chen, Jiaqi Chen, Mingchen Zhuge, Xin Cheng, Sirui Hong, Jinlin Wang, et al. Aflow: Automating agentic workflow generation. _arXiv preprint arXiv:2410.10762_, 2024a.
-   Zhang et al. (2024b) Xingjian Zhang, Yutong Xie, Jin Huang, Jinge Ma, Zhaoying Pan, Qijia Liu, Ziyang Xiong, Tolga Ergen, Dongsub Shim, Honglak Lee, et al. Massw: A new dataset and benchmark tasks for ai-assisted scientific workflows. _arXiv preprint arXiv:2406.06357_, 2024b.
-   Zhou et al. (2024) Yilun Zhou, Caiming Xiong, Silvio Savarese, and Chien-Sheng Wu. Shared imagination: Llms hallucinate alike. _arXiv preprint arXiv:2407.16604_, 2024.
-   Zhuge et al. (2024) Mingchen Zhuge, Wenyi Wang, Louis Kirsch, Francesco Faccio, Dmitrii Khizbullin, and Jürgen Schmidhuber. Gptswarm: Language agents as optimizable graphs. In _Forty-first International Conference on Machine Learning_, 2024.
-   Ziegler et al. (2024) Albert Ziegler, Eirini Kalliamvakou, X Alice Li, Andrew Rice, Devon Rifkin, Shawn Simister, Ganesh Sittampalam, and Edward Aftandilian. Measuring github copilot’s impact on productivity. _Communications of the ACM_, 67(3):54–63, 2024.

## Appendix A Agent Laboratory configuration

### A.1 Hyperparameters

Table 1: Hyperparameters for Agent Laboratory.

<table id="A1.T1.6" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A1.T1.6.1" class="ltx_tr"><td id="A1.T1.6.1.1" class="ltx_td ltx_align_left ltx_border_tt"><span id="A1.T1.6.1.1.1" class="ltx_text ltx_font_bold">Category</span></td><td id="A1.T1.6.1.2" class="ltx_td ltx_align_left ltx_border_tt"><span id="A1.T1.6.1.2.1" class="ltx_text ltx_font_bold">Hyperparameter</span></td><td id="A1.T1.6.1.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_tt"><span id="A1.T1.6.1.3.1" class="ltx_text ltx_font_bold">Value</span></td></tr><tr id="A1.T1.6.2" class="ltx_tr"><td id="A1.T1.6.2.1" class="ltx_td ltx_align_left ltx_border_t"><span id="A1.T1.6.2.1.1" class="ltx_text ltx_font_bold">Literature Review</span></td><td id="A1.T1.6.2.2" class="ltx_td ltx_align_left ltx_border_t">Number of Paper Summaries</td><td id="A1.T1.6.2.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_t">5</td></tr><tr id="A1.T1.6.3" class="ltx_tr"><td id="A1.T1.6.3.1" class="ltx_td"></td><td id="A1.T1.6.3.2" class="ltx_td ltx_align_left">Full Text History Decay Steps</td><td id="A1.T1.6.3.3" class="ltx_td ltx_nopad_r ltx_align_left">3</td></tr><tr id="A1.T1.6.4" class="ltx_tr"><td id="A1.T1.6.4.1" class="ltx_td"></td><td id="A1.T1.6.4.2" class="ltx_td ltx_align_left">Agent temperature</td><td id="A1.T1.6.4.3" class="ltx_td ltx_nopad_r ltx_align_left">0.8</td></tr><tr id="A1.T1.6.5" class="ltx_tr"><td id="A1.T1.6.5.1" class="ltx_td ltx_align_left ltx_border_t"><span id="A1.T1.6.5.1.1" class="ltx_text ltx_font_bold">Data Preparation</span></td><td id="A1.T1.6.5.2" class="ltx_td ltx_align_left ltx_border_t">Experiment Timeout</td><td id="A1.T1.6.5.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_t">120s</td></tr><tr id="A1.T1.6.6" class="ltx_tr"><td id="A1.T1.6.6.1" class="ltx_td ltx_align_left ltx_border_t"><span id="A1.T1.6.6.1.1" class="ltx_text ltx_font_bold">Running Experiments</span></td><td id="A1.T1.6.6.2" class="ltx_td ltx_align_left ltx_border_t">mle-solver steps</td><td id="A1.T1.6.6.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_t">3</td></tr><tr id="A1.T1.6.7" class="ltx_tr"><td id="A1.T1.6.7.1" class="ltx_td"></td><td id="A1.T1.6.7.2" class="ltx_td ltx_align_left">Code repair attempts</td><td id="A1.T1.6.7.3" class="ltx_td ltx_nopad_r ltx_align_left">2</td></tr><tr id="A1.T1.6.8" class="ltx_tr"><td id="A1.T1.6.8.1" class="ltx_td"></td><td id="A1.T1.6.8.2" class="ltx_td ltx_align_left">Maximum top codes</td><td id="A1.T1.6.8.3" class="ltx_td ltx_nopad_r ltx_align_left">2</td></tr><tr id="A1.T1.6.9" class="ltx_tr"><td id="A1.T1.6.9.1" class="ltx_td"></td><td id="A1.T1.6.9.2" class="ltx_td ltx_align_left">Error history length</td><td id="A1.T1.6.9.3" class="ltx_td ltx_nopad_r ltx_align_left">5</td></tr><tr id="A1.T1.6.10" class="ltx_tr"><td id="A1.T1.6.10.1" class="ltx_td"></td><td id="A1.T1.6.10.2" class="ltx_td ltx_align_left">Code history length</td><td id="A1.T1.6.10.3" class="ltx_td ltx_nopad_r ltx_align_left">2</td></tr><tr id="A1.T1.6.11" class="ltx_tr"><td id="A1.T1.6.11.1" class="ltx_td"></td><td id="A1.T1.6.11.2" class="ltx_td ltx_align_left">Number of comparison trials</td><td id="A1.T1.6.11.3" class="ltx_td ltx_nopad_r ltx_align_left">2</td></tr><tr id="A1.T1.6.12" class="ltx_tr"><td id="A1.T1.6.12.1" class="ltx_td"></td><td id="A1.T1.6.12.2" class="ltx_td ltx_align_left">Experiment Timeout</td><td id="A1.T1.6.12.3" class="ltx_td ltx_nopad_r ltx_align_left">600s</td></tr><tr id="A1.T1.6.13" class="ltx_tr"><td id="A1.T1.6.13.1" class="ltx_td"></td><td id="A1.T1.6.13.2" class="ltx_td ltx_align_left">Score generation temperature</td><td id="A1.T1.6.13.3" class="ltx_td ltx_nopad_r ltx_align_left">0.6</td></tr><tr id="A1.T1.6.14" class="ltx_tr"><td id="A1.T1.6.14.1" class="ltx_td"></td><td id="A1.T1.6.14.2" class="ltx_td ltx_align_left">Repair temperature</td><td id="A1.T1.6.14.3" class="ltx_td ltx_nopad_r ltx_align_left">0.8</td></tr><tr id="A1.T1.6.15" class="ltx_tr"><td id="A1.T1.6.15.1" class="ltx_td"></td><td id="A1.T1.6.15.2" class="ltx_td ltx_align_left">Initial code temperature</td><td id="A1.T1.6.15.3" class="ltx_td ltx_nopad_r ltx_align_left">1.0</td></tr><tr id="A1.T1.6.16" class="ltx_tr"><td id="A1.T1.6.16.1" class="ltx_td"></td><td id="A1.T1.6.16.2" class="ltx_td ltx_align_left">Solver temperature</td><td id="A1.T1.6.16.3" class="ltx_td ltx_nopad_r ltx_align_left">1.0</td></tr><tr id="A1.T1.6.17" class="ltx_tr"><td id="A1.T1.6.17.1" class="ltx_td ltx_align_left ltx_border_t"><span id="A1.T1.6.17.1.1" class="ltx_text ltx_font_bold">Paper Writing</span></td><td id="A1.T1.6.17.2" class="ltx_td ltx_align_left ltx_border_t">paper-solver steps</td><td id="A1.T1.6.17.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_t">5</td></tr><tr id="A1.T1.6.18" class="ltx_tr"><td id="A1.T1.6.18.1" class="ltx_td"></td><td id="A1.T1.6.18.2" class="ltx_td ltx_align_left">Maximum top papers</td><td id="A1.T1.6.18.3" class="ltx_td ltx_nopad_r ltx_align_left">1</td></tr><tr id="A1.T1.6.19" class="ltx_tr"><td id="A1.T1.6.19.1" class="ltx_td"></td><td id="A1.T1.6.19.2" class="ltx_td ltx_align_left">Paper history length</td><td id="A1.T1.6.19.3" class="ltx_td ltx_nopad_r ltx_align_left">10</td></tr><tr id="A1.T1.6.20" class="ltx_tr"><td id="A1.T1.6.20.1" class="ltx_td"></td><td id="A1.T1.6.20.2" class="ltx_td ltx_align_left">Number of Reviewers</td><td id="A1.T1.6.20.3" class="ltx_td ltx_nopad_r ltx_align_left">1</td></tr><tr id="A1.T1.6.21" class="ltx_tr"><td id="A1.T1.6.21.1" class="ltx_td"></td><td id="A1.T1.6.21.2" class="ltx_td ltx_align_left">Number of comparison trials</td><td id="A1.T1.6.21.3" class="ltx_td ltx_nopad_r ltx_align_left">2</td></tr><tr id="A1.T1.6.22" class="ltx_tr"><td id="A1.T1.6.22.1" class="ltx_td"></td><td id="A1.T1.6.22.2" class="ltx_td ltx_align_left">Solver temperature</td><td id="A1.T1.6.22.3" class="ltx_td ltx_nopad_r ltx_align_left">1.0</td></tr><tr id="A1.T1.6.23" class="ltx_tr"><td id="A1.T1.6.23.1" class="ltx_td"></td><td id="A1.T1.6.23.2" class="ltx_td ltx_align_left">Initial paper temperature</td><td id="A1.T1.6.23.3" class="ltx_td ltx_nopad_r ltx_align_left">0.8</td></tr><tr id="A1.T1.6.24" class="ltx_tr"><td id="A1.T1.6.24.1" class="ltx_td ltx_align_left ltx_border_bb ltx_border_t"><span id="A1.T1.6.24.1.1" class="ltx_text ltx_font_bold">Paper Refinement</span></td><td id="A1.T1.6.24.2" class="ltx_td ltx_align_left ltx_border_bb ltx_border_t">Number of Reviewers</td><td id="A1.T1.6.24.3" class="ltx_td ltx_nopad_r ltx_align_left ltx_border_bb ltx_border_t">3</td></tr></tbody></table>

### A.2 Hardware

All experiments in this paper were run on a 2023 MacBook Pro with an Apple M3 Max processor and 36 GB of memory.

## Appendix B Prompts

### B.1 Base Inference Prompt

##### Complete String

The complete string is typically set to the empty string. However, in the case when the number of steps reaches 70% of the way toward completion, the following is appended to the base prompt to encourage the agent to produce a submission.

### B.2 Context Prompts

### B.3 Agent Phase Descriptions

#### B.3.1 PhD Student phase

### B.4 Machine Learning Engineer Phase Descriptions

### B.5 Postdoc Phase Descriptions

### B.6 Agent Command Description

#### B.6.1 PhD Student Command Description

#### B.6.2 ML Engineer Agent Command Description

#### B.6.3 Postdoc Agent Command Description

### B.7 Agent Role Description

#### B.7.1 PhD Student Role Description

#### B.7.2 Machine Learning Engineer Role Description

#### B.7.3 Professor Agent

#### B.7.4 Postdoc Agent Role Description

### B.8 mle-solver Prompts

#### B.8.1 Tools

Where the string errs is concatenation of the minimum between five previous errors and the length of all errors (i.e. all errors until the number reaches five, then only five).

### B.9 paper-solver Prompts

Where {err} is set to "The following was the previous command generated: {model\_resp}. This was the error return {cmd\_str}. You should make sure not to repeat this error and to solve the presented problem." when an error is present and is otherwise empty.

#### B.9.1 Per section tips

The following tips are taken and modified from [Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66).

#### B.9.2 paper-solver Reviewer prompt

The following reviewer system prompt is taken from [Lu et al. (2024b)](https://arxiv.org/html/2501.04227#bib.bib66).

## Appendix C Survey questions

### C.1 Grading Research Report Autonomous Mode Preselected Topics

See pages - of [images/pdfs/GradingReport1.pdf](https://images/pdfs/GradingReport1.pdf)

### C.2 Co-Pilot Grading Research Report Preselected Topics

See pages - of [images/pdfs/CoPilotPreselectedpdf.pdf](https://images/pdfs/CoPilotPreselectedpdf.pdf)

### C.3 Co-Pilot Grading Research Report Custom Topics

See pages - of [images/pdfs/CoPilotCustompdf.pdf](https://images/pdfs/CoPilotCustompdf.pdf)

Experimental support, please [view the build logs](https://arxiv.org/html/2501.04227v2/__stdout.txt) for errors. Generated by [L A T E xml](https://math.nist.gov/~BMiller/LaTeXML/)  .

## Instructions for reporting errors

We are continuing to improve HTML versions of papers, and your feedback helps enhance accessibility and mobile support. To report errors in the HTML that will help us improve conversion and rendering, choose any of the methods listed below:

-   Click the "Report Issue" button, located in the page header.

**Tip:** You can select the relevant text first, to include it in your report.

Our team has already identified [the following issues](https://github.com/arXiv/html_feedback/issues). We appreciate your time reviewing and reporting rendering errors we may not have found yet. Your efforts will help us improve the HTML versions for all readers, because disability should not be a barrier to accessing research. Thank you for your continued support in championing open access for all.

Have a free development cycle? Help support accessibility at arXiv! Our collaborators at LaTeXML maintain a [list of packages that need conversion](https://github.com/brucemiller/LaTeXML/wiki/Porting-LaTeX-packages-for-LaTeXML), and welcome [developer contributions](https://github.com/brucemiller/LaTeXML/issues).

We gratefully acknowledge support from our **major funders**, [**member institutions**](https://info.arxiv.org/about/ourmembers.html), and all contributors.

[About](https://info.arxiv.org/about) · [Help](https://info.arxiv.org/help) · [Contact](https://info.arxiv.org/help/contact.html) · [Subscribe](https://info.arxiv.org/help/subscribe) · [Copyright](https://info.arxiv.org/help/license/index.html) · [Privacy](https://info.arxiv.org/help/policies/privacy_policy.html) · [Accessibility](https://info.arxiv.org/help/web_accessibility.html) · [Operational Status (opens in new tab)](https://status.arxiv.org/)

Major funding support from
