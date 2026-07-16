module.exports = {
  preset: undefined,
  testEnvironment: 'node',
  transform: {
    '^.+\\.(ts|tsx)$': [
      'babel-jest',
      {
        presets: [
          ['@babel/preset-env', { targets: { node: 'current' } }],
          '@babel/preset-typescript',
        ],
      },
    ],
  },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  testMatch: ['**/tests/typescript/**/*.test.ts'],
  transformIgnorePatterns: ['node_modules/(?!(react-native|@react-native)/)'],
  moduleNameMapper: {
    '^@app/app-text-input$': '<rootDir>/src/index.tsx',
  },
};
