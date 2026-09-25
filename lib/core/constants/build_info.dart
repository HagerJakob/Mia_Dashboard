class BuildInfo {
  const BuildInfo._();

  static const label = String.fromEnvironment(
    'STUDYBUDDY_BUILD_LABEL',
    defaultValue: 'dev',
  );

  static const builtAt = String.fromEnvironment(
    'STUDYBUDDY_BUILT_AT',
    defaultValue: 'unknown',
  );
}
