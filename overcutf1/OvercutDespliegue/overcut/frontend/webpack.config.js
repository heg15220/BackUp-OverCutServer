const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { HotModuleReplacementPlugin, DefinePlugin, ProvidePlugin } = require('webpack');


module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production';

  return {
    entry: './src/index.js',
    output: {
      path: path.resolve(__dirname, 'dist'),
      filename: 'bundle.js',
      publicPath: '/', // importante para rutas absolutas
      clean: true,
    },
    resolve: {
      extensions: ['.js', '.jsx'],
    },
    module: {
      rules: [
        {
          test: /\.(js|jsx)$/,
	  include: path.resolve(__dirname, 'src'), // fuerza que tu código pase por Babel
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              // Fuerza runtime automático -> no depende de "React" en scope
              presets: [['@babel/preset-react', { runtime: 'automatic' }]],
            },
          },
        },
        {
          test: /\.(png|jpe?g|gif|svg)$/i,
          type: 'asset/resource',
          generator: {
            filename: 'images/[path][name][ext]',
          },
        },
        {
          test: /\.css$/,
          use: [isProduction ? MiniCssExtractPlugin.loader : 'style-loader', 'css-loader', 'postcss-loader'],
        },
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({
        template: './public/index.html',
      }),
      new DefinePlugin({ 'process.env.NODE_ENV': JSON.stringify('production') }),
      new ProvidePlugin({ React: 'react' }),
      isProduction && new MiniCssExtractPlugin({ filename: '[name].[contenthash].css' }),
      !isProduction && new HotModuleReplacementPlugin(),
    ].filter(Boolean),
    devServer: {
      static: path.join(__dirname, 'dist'),
      compress: true,
      port: 8080,
      historyApiFallback: true, // SPA
      hot: !isProduction,
    },
    devtool: isProduction ? false : 'source-map',
    mode: isProduction ? 'production' : 'development',
  };
};

