import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'update_service.dart';

/// 应用外部链接集中配置。
///
/// 爱发电赞助主页 / 官方 QQ 群一键加群链接；更换地址只需改对应常量。
/// 留空时入口点击会走兜底（提示 / 复制群号），不会跳转到错误页面。
const String kAfdianUrl = 'https://afdian.com/a/ZV-Manager';

/// 打开爱发电赞助页；未配置链接时给出提示，避免跳空。
Future<void> openAfdian(BuildContext context) async {
  if (kAfdianUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.t('赞助链接待配置'))),
    );
    return;
  }
  await UpdateService.openUrl(kAfdianUrl);
}

/// 官方 QQ 群号（兜底：复制后由用户在 QQ 内搜索加群）。
const String kQQGroupNumber = '1104846597';

/// 一键加群链接，由群主在 QQ「群设置 → 分享群 → 复制加群链接」生成，
/// 形如 https://qun.qq.com/join.html?c=... 或 https://qm.qq.com/q/xxx 。
/// QQ 分享链接可能有时效性；失效时把本常量清空即可自动回到「复制群号」兜底。
const String kQQGroupUrl = 'https://qun.qq.com/universal-share/share?ac=1&authKey=dcXyjTs%2FlsBVwuyqft4mtdv0M6%2FneeXoBsSC3NlY64BkPqMQzSMxMwkb7aMSlqvq&busi_data=eyJncm91cENvZGUiOiIxMTA0ODQ2NTk3IiwidG9rZW4iOiJia25JTCsrWGVNTTV1RVR2R291cjV5cGd3dkFQNlpwMHRmSjRYQ1JmVXhIV2VYUkVRTEtTQ0h4dVV6UDRKbndNIiwidWluIjoiMzQ4MDQyODI1MSJ9&data=OOUyy8zBOrBDZJRGvyg3_d-8WmJ8jaEXSFGUfBkjY27G1nJDgzbNHDEU-0c_mFCNfufsWIvaXtwZUOdTL-qZsg&svctype=4&tempid=h5_group_info';

/// 加入官方 QQ 群：优先打开一键加群链接，未配置则复制群号兜底。
Future<void> joinQQGroup(BuildContext context) async {
  if (kQQGroupUrl.isNotEmpty) {
    await UpdateService.openUrl(kQQGroupUrl);
    return;
  }
  await Clipboard.setData(const ClipboardData(text: kQQGroupNumber));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(S.t('群号已复制，打开 QQ 搜索加群'))),
  );
}
