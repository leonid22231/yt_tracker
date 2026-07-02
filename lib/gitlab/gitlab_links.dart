/// Ссылки на объекты GitLab в веб-интерфейсе.
abstract final class GitLabLinks {
  static String normalizeBase(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  static String encodeProjectPath(String path) =>
      Uri.encodeComponent(path);

  static String projectUrl(String baseUrl, String projectPath) =>
      '${normalizeBase(baseUrl)}/${projectPath.trim()}';

  static String commitUrl(
    String baseUrl,
    String projectPath,
    String sha,
  ) =>
      '${projectUrl(baseUrl, projectPath)}/-/commit/$sha';

  static String mergeRequestUrl(
    String baseUrl,
    String projectPath,
    int iid,
  ) =>
      '${projectUrl(baseUrl, projectPath)}/-/merge_requests/$iid';

  static String branchUrl(
    String baseUrl,
    String projectPath,
    String branchName,
  ) {
    final branch = branchName.startsWith('refs/heads/')
        ? branchName.substring('refs/heads/'.length)
        : branchName;
    return '${projectUrl(baseUrl, projectPath)}/-/tree/'
        '${Uri.encodeComponent(branch)}';
  }

  static String compareUrl(
    String baseUrl,
    String projectPath, {
    String from = 'main',
    String to = '',
  }) {
    if (to.isEmpty) {
      return '${projectUrl(baseUrl, projectPath)}/-/compare';
    }
    return '${projectUrl(baseUrl, projectPath)}/-/compare/'
        '${Uri.encodeComponent(from)}...${Uri.encodeComponent(to)}';
  }
}
