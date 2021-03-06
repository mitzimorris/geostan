// if Poisson, offset term is natural log of user-provided offset vector
// do not use this in combination with any other *_trans_params.stan //
  vector[n] f;
  vector[dx] beta;
  f = offset + intercept;
  if (dx) {
    f += Q_ast * beta_tilde;
    beta = R_inverse * beta_tilde;
  }
  if (has_re) {
    for (i in 1:n) {
      f[i] += alpha_tau[has_re] * alpha_re_tilde[id[i]];
   }
  }

