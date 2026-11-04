/// 软件更新信息，由 Gitee 发布接口解析而来。
class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String apkName;

  /// Gitee 发布说明（Markdown 原文）。
  final String releaseNotes;

  /// Gitee 发布接口返回的发布时间。
  final DateTime? releasedAt;

  /// Gitee 发布页地址。
  final String releasePageUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.apkName,
    this.releaseNotes = '',
    this.releasedAt,
    this.releasePageUrl = '',
  });
}
