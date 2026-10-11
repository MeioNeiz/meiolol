# LoLDraftAI monorepo public archive

Source code archive for the website [LoLDraftAI](https://loldraftai.com/), which hosts a deep learning model that predicts and analyzes League of Legends matches from draft only.

> **Note:** This public archive represents the state of the code as of May 2025. Since then, the codebase has been taken private.

## Model Performance

The project features two models trained for different scenarios:

### Solo Queue Model

- **Endpoint:** [loldraftai.com/draft](https://loldraftai.com/draft)
- **Best Model:** Epoch 46
- **Metrics:**
  - Validation Loss: 0.681
  - Accuracy: 56.1%
- **Training Logs:** [View on Weights & Biases](https://wandb.ai/loyd-team/draftking/runs/jy5hf0bv?nw=nwuserloyd)

### Pro Model

- **Endpoint:** [loldraftai.com/pro-draft](https://loldraftai.com/pro-draft)
- **Best Model:** Epoch 240
- **Metrics:**
  - Validation Loss: 0.6775
  - Accuracy: 56.8%
- **Training Logs:** [View on Weights & Biases](https://wandb.ai/loyd-team/draftking-pro-finetune/runs/jg3ls0xp/workspace?nw=nwuserloyd)

> **Note:** Both models achieve good metrics considering the complexity of the task. Predicting match outcomes from draft alone is challenging since the draft phase represents only a small portion of the overall game.

## Repository Structure

### Apps

- **data-collection**  
  Data collection scripts, run on a VM and store data in a postgresql database.

- **desktop**  
  Code for the desktop application. Can be downloaded from https://loldraftai.com/download

- **machine-learning**  
  Code for the machine learning part. See `./apps/machine-learning/README.md` for full details.

- **team-comp-visualizer**  
  Code for a proof of concept desktop app that uses millions of team comps rated by the pro finetuned model, to see which are the best.  
  See https://docs.google.com/document/d/1aHmNZq_Wvn6YChEOKfZa1i1fs_97NExXwBnLYN1WInI/edit?usp=sharing for how it looks like.

- **web-frontend**  
  Code for the LoLDraftAI website.

### Packages

- **ui**  
  UI package, used by both the desktop and web-frontend app.

## Infrastructure

The infrastructure used for this project is:

- An Azure VM(Standard D2s v3) for running the data-collection scripts.

- A Postgresql database(Standard_B4ms (4 vCores)) for storing the league api data(Summoners and Matches). Complete matches are then exported to an Azure bucket in parquet format.

- Cloudflare for large media hosting(download file for desktop and images for web-frontend).

- Vercel for web-frontend.

- Azure container apps for the model inference(0.5vCPU and 1Gb Ram was enough).

- My gaming PC for model training :-)
