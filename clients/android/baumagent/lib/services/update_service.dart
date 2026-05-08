import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String downloadUrl;
  const UpdateInfo({required this.version, required this.notes, required this.downloadUrl});
}

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/Bruiserbaum/baumagent-clients/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);

      final resp = await http.get(
        Uri.parse(_apiUrl),
        headers: {'User-Agent': 'BaumAgentAndroid/1.0'},
      );
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String).replaceFirst('v', '');
      final latest = _parseVersion(tag);

      if (_compareVersions(latest, current) <= 0) return null;

      final assets = json['assets'] as List;
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );
      if (apkAsset == null) return null;

      return UpdateInfo(
        version: tag,
        notes: (json['body'] as String?) ?? '',
        downloadUrl: apkAsset['browser_download_url'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(int percent)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/BaumAgent-${update.version}.apk');

    final request = http.Request('GET', Uri.parse(update.downloadUrl));
    request.headers['User-Agent'] = 'BaumAgentAndroid/1.0';
    final response = await http.Client().send(request);

    final total = response.contentLength ?? 0;
    var downloaded = 0;

    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total > 0) onProgress?.call((downloaded * 100 ~/ total));
    }
    await sink.flush();
    await sink.close();

    await OpenFilex.open(file.path);
  }

  List<int> _parseVersion(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

  int _compareVersions(List<int> a, List<int> b) {
    final len = [a.length, b.length].reduce((x, y) => x > y ? x : y);
    for (var i = 0; i < len; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
