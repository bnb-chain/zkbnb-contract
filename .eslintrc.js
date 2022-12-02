module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  env: {
    es6: true,
    node: true,
    mocha: true,
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  rules: {
    radix: ['error', 'always'],
    'object-shorthand': ['error', 'always'],
    'prettier/prettier': [
      'error',
      { semi: true },
      {
        usePrettierrc: true,
      },
    ],
    camelcase: ['error', { ignoreImports: true }],
    'prefer-const': 'error',
    'sort-imports': ['error', { ignoreDeclarationSort: true }],
  },
  overrides: [
    {
      files: ['test/**/*.js'],
      rules: {
        'no-unused-expressions': 'off',
      },
    },
  ],
};
