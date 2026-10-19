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
        updateBuildNumber: false,
      },
    ],
    [
      '@semantic-release/exec',
      {
        prepareCmd:
          'bash scripts/increment_build.sh && bash scripts/build_apk.sh ${nextRelease.version}',
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
    [
      '@semantic-release/github',
      {
        assets: [
          { path: 'dist/*.apk', label: 'Disastron Android APK' },
          { path: 'dist/*.sha256', label: 'SHA-256 checksum' },
        ],
      },
    ],
  ],
};
