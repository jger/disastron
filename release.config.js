module.exports = {
  branches: ['main'],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    [
      '@semantic-release/changelog',
      {
        changelogFile: 'CHANGELOG.md',
        changelogTitle:
          '# Changelog\n\nAll notable changes will be documented in this file.',
      },
    ],
    [
      'semantic-release-dart',
      {
        updateBuildNumber: true,
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['pubspec.yaml', 'CHANGELOG.md'],
        message:
          'chore(release): bump version to ${nextRelease.version} [skip ci]',
      },
    ],
  ],
};
