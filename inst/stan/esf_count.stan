functions {
#include parts/priors.stan
}

data {
#include parts/glm_data.stan
#include parts/esf_data.stan
  int y[n]; // outcome variable
}

transformed data {
#include parts/QR.stan
}

parameters {
#include parts/esf_parameters.stan
#include parts/glm_parameters.stan
}

transformed parameters {
#include parts/esf_trans_params.stan
}

model {
#include parts/glm_model.stan
#include parts/rhs_model.stan
  y ~ poisson_log(f); 
}

generated quantities {
  vector[n] yrep;
  vector[n] fitted;
  vector[n] esf;
  vector[n] residual;
  vector[n] log_lik;
  vector[n_ids] alpha_re;
  if (has_re) {
    for (i in 1:n_ids) {
      alpha_re[i] = alpha_tau[has_re] * alpha_re_tilde[i];
    }
  }
  for (i in 1:n) {
    fitted[i] = exp(f[i]);
    residual[i] = fitted[i] - y[i];
    esf[i] = EV[i]*beta_ev;
    log_lik[i] = poisson_log_lpmf(y[i] | f[i]);
    if (f[i] > 20) {
       print("f[i] too large (>20) for poisson_log_rng");
       yrep[i] = -1;
       } else {
    yrep[i] = poisson_log_rng(f[i]);
    }
  }
}

