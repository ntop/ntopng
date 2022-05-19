const path = require("path");
const { CleanWebpackPlugin } = require("clean-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const webpack = require("webpack")

module.exports = {
  devtool: "source-map",
  entry: { 
      'custom-theme': './http_src/views/private/clients/custom_theme.js',
      'dark-mode': './http_src/views/private/clients/dark-mode.js',
      'white-mode': './http_src/views/private/clients/white-mode.js',
      'images': './assets/images/images.js', 
      'login': './assets/scripts/login.js',      
      'ntopng': "./http_src/ntopng_css.js",
      'third-party': "./assets/third-party.js",
  },
  output: {
    path: __dirname + '/httpdocs/tmp-dist',
    filename: '[name].js'
  },
  optimization: {
    minimize: true,
    minimizer: [
      new CssMinimizerPlugin(), 
      new TerserPlugin(),
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: "jquery",
      jQuery: "jquery",
      d3: 'd3',
    }),   
    new MiniCssExtractPlugin({ filename: '[name].css' }),
    new CleanWebpackPlugin(),
  ],
  module: {
    rules: [
      {
        test: /\.(scss|sass)$/,
        use: [
          MiniCssExtractPlugin.loader, //
          "css-loader",  //2. Turns css into commonjs, 
          {
            // Run postcss actions
            loader: 'postcss-loader',
            options: {
              // `postcssOptions` is needed for postcss 8.x;
              // if you use postcss 7.x skip the key
              postcssOptions: {
                // postcss plugins, can be exported to postcss.config.js
                plugins: function () {
                  return [
                    require('autoprefixer')
                  ];
                }
              }
            }
          },
          "sass-loader", //1. Turns sass into css
        ]
      },
      {
          test: /\.(map)$/,
          use: "source-map-loader"
      },
      {
        test: /.m?js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env']
          }
        }
      },
      {
        test: /\.(gif|png|jpe?g|svg)$/i,
        use: [
          {
            loader: 'file-loader',
            options: {
              outputPath: './images',
              name: '[name].[ext]'
            }
          },
          {
            loader: 'image-webpack-loader',
            options: {
              mozjpeg: {
                progressive: true,
              },
              // optipng.enabled: false will disable optipng
              optipng: {
                enabled: false,
              },
              pngquant: {
                quality: [0.65, 0.90],
                speed: 4
              },
              gifsicle: {
                interlaced: false,
              },
              // the webp option will enable WEBP
              webp: {
                quality: 75
              }
            }
          },
        ],
      }
    ]
  }
}
