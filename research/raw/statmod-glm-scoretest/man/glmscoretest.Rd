\name{glm.scoretest}
\alias{glm.scoretest}

\title{Score Test for Adding a Covariate to a GLM}
\description{
Computes score test statistics (z-statistics) for adding covariates to a generalized linear model.
}

\usage{
glm.scoretest(fit, x2, dispersion=NULL)
}

\arguments{
\item{fit}{generalized linear model fit object, of class \code{\link{glm}}.}
\item{x2}{vector or matrix with each column a covariate to be added.}
\item{dispersion}{the dispersion for the generalized linear model family.}
}

\details{
Rao's score test is a type of asymptotic test that is an alternative to Wald tests or likelihood ratio tests (LRTs) (Dunn and Smyth, 2018).
Wald tests are computed by dividing parameter estimates by their standard errors.
LRTs are computed from differences in the log-likihoods between the null and alternative hypotheses.
Score tests are computed from log-likelihood derivatives.
All three types of tests (Wald, score and LRT) are asymptotically equivalent under ideal circumstances, but the score and LRT tests are invariant under-reparametrization whereas Wald tests are not.

One of the main differences between the tests is the need for estimation of parameters under the null and alternative hypotheses.
Wald tests require maximum likelihood estimates (MLEs) to be computed only under the alternative hypothesis, LRT tests require both the null and alternative models to be fitted, while score tests require only the null hypothesis to be fitted.

When a generalized linear model (GLM) is fitted in R using the \code{glm} function, the \code{summary()} function presents Wald tests for all the coefficients in the linear model while \code{anova()} is able to compute likelihood ratio tests.
GLM output in R has historically not included score tests, although score tests can be a very computationally efficient choice when one wants to test for many potential additional covariates being added to a relatively simple null model.

A number of well known Pearson chisquare statistics, including goodness of fit statistics and the Pearson test for independence in a contingency table can be derived as score tests (Smyth, 2003; Dunn and Smyth, 2018).

This function computes score test statistics for adding a single numerical covariate to a GLM, given the \code{glm} output for the null model.
It makes very efficient use of the quantities already stored in the GLM fit object.
A computational formula for the score test statistics is given in Section 7.2.6 of Dunn and Smyth (2018).

The dispersion parameter is treated as for \code{\link{summary.glm}}.
If \code{NULL}, the Pearson estimator is used, except for the binomial, Poisson and negative binomial
families, for which the dispersion is one.

Note that the \code{anova.glm} function in the stats package has offered a Rao score test option since 2011, but it requires model fits under the alternative as well as the null hypothesis, which does not take advantage of the computational advantage of score test.
The \code{glm.scoretest} is more efficient as it does not require a full model fit.
On the other hand, \code{anova.glm} can compute score tests for factors and multiple covariates, which \code{glm.scoretest} does not currently do.
}

\value{
numeric vector containing the z-statistics, one for each covariate.
The z-statistics can be treated as standard normal under the null hypothesis.
}

\author{Gordon Smyth}

\seealso{
\code{\link{glm}}, \code{\link{add1}}, \code{\link{anova.glm}}
}

\references{
Dunn, PK, and Smyth, GK (2018). \emph{Generalized linear models with examples in R}. Springer, New York, NY. 
\doi{10.1007/978-1-4419-0118-7}

Lovison, G (2005). On Rao score and Pearson X^2 statistics in generalized linear models.
\emph{Statistical Papers}, 46, 555-574.

Pregibon, D (1982). Score tests in GLIM with applications.
In \emph{GLIM82: Proceedings of the International Conference on Generalized Linear Models},
R Gilchrist (ed.), Lecture Notes in Statistics, Volume 14, Springer, New York, pages 87-97. 

Smyth, G. K. (2003). Pearson's goodness of fit statistic as a score test statistic.
In: \emph{Science and Statistics: A Festschrift for Terry Speed}, D. R. Goldstein (ed.), IMS Lecture Notes - Monograph Series, Volume 40, Institute of Mathematical Statistics, Beachwood, Ohio, pages 115-126.
\url{https://gksmyth.github.io/pubs/goodness.pdf}
}

\examples{
#  Pearson's chisquare test for independence
#  in a contingency table is a score test.

#  First the usual test

y <- c(20,40,40,30)
chisq.test(matrix(y,2,2), correct=FALSE)

#  Now same test using glm.scoretest

a <- gl(2,1,4)
b <- gl(2,2,4)
fit <- glm(y~a+b, family=poisson)
x2 <- c(0,0,0,1)
z <- glm.scoretest(fit, x2)
z^2
}

\concept{generalized linear models}
