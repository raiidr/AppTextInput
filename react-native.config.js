const path = require('path');

module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: path.join(__dirname, 'android'),
      },
      ios: {
        podspecPath: path.join(__dirname, 'AppTextInput.podspec'),
      },
    },
  },
};
