module.exports = {
  semi: true,
  singleQuote: true,
  printWidth: 120,
  endOfLine: 'auto',
  tabWidth: 2,
  trailingComma: 'all',
  overrides: [
    {
      files: '*.sol',
      options: {
        printWidth: 120,
        tabWidth: 2,
        useTabs: false,
        singleQuote: false,
        bracketSpacing: false,
        explicitTypes: 'always',
        compiler: '0.8.17',
      },
    },
  ],
}
