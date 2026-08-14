import nextCoreWebVitals from 'eslint-config-next/core-web-vitals'

// eslint-config-next v16 already ships a native flat-config array, so it is
// spread directly — no @eslint/eslintrc FlatCompat bridge is required here.
const config = [
  {
    ignores: ['.next/**', 'out/**', 'node_modules/**', 'next-env.d.ts'],
  },
  ...nextCoreWebVitals,
  {
    // next/core-web-vitals ships no unused-symbol rule, so dead code (unused
    // imports, unread hook results) slips through. The @typescript-eslint
    // plugin is already registered by next/typescript for these files.
    files: ['**/*.ts', '**/*.tsx'],
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_', caughtErrorsIgnorePattern: '^_' },
      ],
    },
  },
]

export default config
