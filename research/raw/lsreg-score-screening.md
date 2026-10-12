# Large-Scale Poisson Regression with lsReg

<https://cran.r-project.org/web/packages/lsReg/vignettes/poisson-regression.html>

# Large-Scale Poisson Regression with lsReg

## Overview

This vignette demonstrates large-scale Poisson regression using `lsReg` with the score test. The score test is computed entirely from the base model fit and does not require fitting the full model for each candidate covariate, making it especially efficient for large-scale screening. Because the full model is never fit, no parameter estimate is produced — only the test statistic.

## Example data

We use the same simulated dataset as the other vignettes. The count outcome `ypois` was generated from a Poisson model with `x1`, `x2`, `z5`, and `z9` as predictors. The variables `z1` through `z10` are the candidates to be screened.

```
library(lsReg)

datafile <- system.file("extdata", "simulated_data.rds", package = "lsReg")
dat <- readRDS(datafile)
head(dat[, c("ypois", "x1", "x2", "z1", "z2", "z5", "z9")])
#>   ypois          x1 x2 z1 z2 z5        z9
#> 1     0 -1.52199116  1  0  1  0 0.5931028
#> 2     0 -0.96937043  1  0  0  0 0.6778513
#> 3     1 -0.38494124  0  0  0  0 0.8131135
#> 4     0 -0.24568841  0  1  1  0 0.2320682
#> 5     0 -0.49640532  0  0  1  0 0.7719654
#> 6     2  0.07975954  0  0  1  0 0.2162713
```

## Step 1: Fit the base model

```
basemdl <- glm(ypois ~ x1 + x2, data = dat, family = poisson)
summary(basemdl)
#> 
#> Call:
#> glm(formula = ypois ~ x1 + x2, family = poisson, data = dat)
#> 
#> Coefficients:
#>             Estimate Std. Error z value Pr(>|z|)    
#> (Intercept) -1.06112    0.07078 -14.991  < 2e-16 ***
#> x1           0.90872    0.04214  21.567  < 2e-16 ***
#> x2           0.32645    0.08150   4.006 6.19e-05 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#> (Dispersion parameter for poisson family taken to be 1)
#> 
#>     Null deviance: 1400.59  on 999  degrees of freedom
#> Residual deviance:  892.59  on 997  degrees of freedom
#> AIC: 1760.6
#> 
#> Number of Fisher Scoring iterations: 6
```

## Step 2: Allocate memory

```
mem <- lsReg(basemdl, colstoadd = 1, testtype = "score")
```

## Step 3: Test each candidate covariate

After each call to `addcovar()` the score test statistic is in `mem$testvalue`. The score test returns a z-score, so p-values are computed from the standard normal distribution.

```
zvars <- paste0("z", 1:10)

results <- data.frame(
  variable  = zvars,
  statistic = NA_real_
)

for (i in seq_along(zvars)) {
  xr <- as.matrix(dat[, zvars[i], drop = FALSE])
  addcovar(mem, xr)
  results$statistic[i] <- mem$testvalue[1, 1]
}
```

## Results

```
results$pvalue <- 2 * pnorm(-abs(results$statistic))
print(results, digits = 4)
#>    variable statistic    pvalue
#> 1        z1   -1.1822 0.2371119
#> 2        z2   -0.7992 0.4241484
#> 3        z3   -0.5253 0.5993434
#> 4        z4    1.0150 0.3101199
#> 5        z5    3.0923 0.0019864
#> 6        z6    0.5395 0.5895274
#> 7        z7    0.8378 0.4021242
#> 8        z8   -1.2688 0.2044948
#> 9        z9   -3.5103 0.0004476
#> 10      z10    1.5944 0.1108519
```

The variables `z5` and `z9` have the largest score statistics and the smallest p-values, consistent with the data-generating model.

## Verification against statmod

The `glm.scoretest()` function from the `statmod` package computes the score test statistic for a single candidate covariate added to a fitted GLM. We use it to verify the `lsReg` results for `z5` and `z9`.

```
library(statmod)

statmod_stat_z5 <- glm.scoretest(basemdl, dat[, "z5"])
statmod_stat_z9 <- glm.scoretest(basemdl, dat[, "z9"])

lsreg_stat_z5 <- results$statistic[results$variable == "z5"]
lsreg_stat_z9 <- results$statistic[results$variable == "z9"]

comparison <- data.frame(
  variable         = c("z5", "z9"),
  statmod_statistic = c(statmod_stat_z5, statmod_stat_z9),
  lsreg_statistic  = c(lsreg_stat_z5,   lsreg_stat_z9)
)
print(comparison, digits = 6)
#>   variable statmod_statistic lsreg_statistic
#> 1       z5           3.09225         3.09225
#> 2       z9          -3.51030        -3.51030
```

The score statistics from `lsReg` match those from `statmod::glm.scoretest()` to numerical precision.
