module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
    mocha: true,
  },
  parserOptions: { ecmaVersion: 8 },
  extends: ['eslint:recommended', 'plugin:prettier/recommended'],
  rules: {
    radix: ['error', 'always'],
    'no-unused-vars': 'warn',
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
    {
      parser: '@typescript-eslint/parser',
      plugins: ['@typescript-eslint'],
      files: ['*.ts', '*.tsx'],
      extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended', 'plugin:prettier/recommended'],
    },
  ],
};
