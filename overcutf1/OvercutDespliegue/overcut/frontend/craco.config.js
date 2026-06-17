// craco.config.js
module.exports = {
  webpack: {
    configure: (config) => {
      // Quita el CssMinimizerPlugin que casca con '/'
      config.optimization.minimizer = (config.optimization.minimizer || []).filter(
        (p) => p.constructor && p.constructor.name !== 'CssMinimizerPlugin'
      );
      return config;
    },
  },
};
