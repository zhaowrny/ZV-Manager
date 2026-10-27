import 'package:dio/dio.dart';
import 'mirror_service.dart';

/// Modrinth API 封装（无需密钥）。
/// 文档：https://docs.modrinth.com/
class ModrinthApi {
  final MirrorService mirror;
  ModrinthApi(this.mirror);

  Dio get _dio {
    final d = Dio(BaseOptions(
      // 镜像线路偶尔抖动，给足超时时间，避免用户看到莫名失败
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 镜像改写：api.modrinth.com / cdn.modrinth.com → 镜像节点
        options.path = mirror.rewrite(options.uri.toString());
        // Modrinth 要求标明客户端身份，否则可能被限流
        options.headers['User-Agent'] = 'ZVManager/2.0 (gitee.com/driftinblock/zvmanager)';
        handler.next(options);
      },
    ));
    return d;
  }

  /// 搜索项目。facets 例：[["versions:1.20.1"], ["categories:fabric"], ["project_type:mod"]]
  ///
  /// Modrinth 的 facets 是「AND 组合、组内 OR」的结构，
  /// 因此项目类型/版本/加载器各占一组即可实现"三者同时满足"的筛选。
  Future<List<ModrinthSearchResult>> search({
    required String query,
    String projectType = 'mod',
    String? mcVersion,
    String? loader,
    int limit = 20,
  }) async {
    final facets = <List<String>>[
      ['project_type:$projectType'],
    ];
    if (mcVersion != null && mcVersion.isNotEmpty) facets.add(['versions:$mcVersion']);
    if (loader != null && loader.isNotEmpty) facets.add(['categories:$loader']);
    final resp = await _dio.get('/v2/search', queryParameters: {
      'query': query,
      'limit': limit,
      'facets': facets,
    });
    final hits = resp.data['hits'] as List;
    return hits.map((e) => ModrinthSearchResult.fromJson(e)).toList();
  }

  /// 获取项目最新兼容版本列表（按日期倒序）。
  Future<List<ModrinthVersion>> versions(String projectId) async {
    final resp = await _dio.get('/v2/project/$projectId/version');
    final list = (resp.data as List).map((e) => ModrinthVersion.fromJson(e)).toList();
    list.sort((a, b) => b.datePublished.compareTo(a.datePublished));
    return list;
  }

  /// 项目详情（用于依赖信息）。
  Future<Map<String, dynamic>> project(String idOrSlug) async {
    final resp = await _dio.get('/v2/project/$idOrSlug');
    return Map<String, dynamic>.from(resp.data);
  }
}

/// 在项目搜索中会出现多页结果，这里仅取 limit 条（分页由上层滚动加载扩展）。
class ModrinthSearchResult {
  /// 项目短名，可用于拼 URL（如 /mod/sodium）
  final String slug;
  final String title;
  final String description;
  final List<String> categories;
  final int downloads;

  /// 项目图标，部分项目无图标返回 null
  final String? iconUrl;

  /// 项目唯一 id，查版本时用
  final String projectId;

  ModrinthSearchResult({
    required this.slug,
    required this.title,
    required this.description,
    required this.categories,
    required this.downloads,
    this.iconUrl,
    required this.projectId,
  });

  factory ModrinthSearchResult.fromJson(Map<String, dynamic> e) => ModrinthSearchResult(
        slug: e['slug'] ?? '',
        title: e['title'] ?? '',
        description: e['description'] ?? '',
        categories: List<String>.from(e['categories'] ?? const []),
        downloads: e['downloads'] ?? 0,
        iconUrl: e['icon_url'],
        projectId: e['project_id'] ?? '',
      );
}

/// Modrinth 的一个发布版本。
class ModrinthVersion {
  final String id;

  /// 版本号（如 0.5.11）
  final String versionNumber;

  /// 版本展示名（通常是版本号 + 说明）
  final String name;

  /// 兼容的 MC 版本列表（如 ['1.20.1', '1.20.2']）
  final List<String> gameVersions;

  /// 兼容的加载器（fabric / forge / neoforge / quilt）
  final List<String> loaders;

  final DateTime datePublished;
  final String? changelog;

  /// 文件列表，每项含 url / filename / primary 等字段
  final List<Map<String, dynamic>> files;

  ModrinthVersion({
    required this.id,
    required this.versionNumber,
    required this.name,
    required this.gameVersions,
    required this.loaders,
    required this.datePublished,
    this.changelog,
    this.files = const [],
  });

  factory ModrinthVersion.fromJson(Map<String, dynamic> e) => ModrinthVersion(
        id: e['id'],
        versionNumber: e['version_number'] ?? '',
        name: e['name'] ?? '',
        gameVersions: List<String>.from(e['game_versions'] ?? const []),
        loaders: List<String>.from(e['loaders'] ?? const []),
        datePublished: DateTime.tryParse(e['date_published'] ?? '') ?? DateTime.now(),
        changelog: e['changelog'],
        files: List<Map<String, dynamic>>.from(e['files'] ?? const []),
      );
}

/// 从版本文件列表中取主 jar 文件的下载链接。
String? primaryFileUrl(Map<String, dynamic> file) => file['url'] as String?;
