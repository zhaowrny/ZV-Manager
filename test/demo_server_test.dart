import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zv_manager/core/services/demo_server.dart';
import 'package:zv_manager/core/services/jar_metadata.dart';
import 'package:zv_manager/core/services/server_monitor_service.dart';
import 'package:zv_manager/core/services/sftp_service.dart';
import 'package:zv_manager/core/services/ssh_shell_service.dart';
import 'package:zv_manager/core/utils/rcon_client.dart';
import 'package:zv_manager/features/player_management/player_service.dart';
import 'package:zv_manager/providers/rcon_provider.dart';
import 'package:zv_manager/providers/server_provider.dart';

ServerConfig _demoServer() => ServerConfig(
      id: 'demo-test',
      name: '演示服务器',
      host: 'demo.local',
      port: 25575,
      password: 'demo',
      sshEnabled: true,
      sshUser: 'demo',
      sshPassword: 'demo',
      isDemo: true,
    );

void main() {
  test('演示服务器状态、玩家与 TPS 可被现有解析器识别', () async {
    final provider = RconProvider();
    addTearDown(provider.dispose);
    final server = _demoServer();

    final status = await provider.checkStatus(server);
    expect(status.online, isTrue);
    expect(status.playerCount, 3);
    expect(status.tps, 20.0);
    expect(
      parseOnlinePlayerNames(status.playerInfo),
      ['Steve', 'Alex', 'Notch'],
    );

    final players = await PlayerService(await provider.getClient(server))
        .getOnlinePlayers();
    expect(players.map((p) => p.name), ['Steve', 'Alex', 'Notch']);
    expect(players.first.uuid, isNotEmpty);
  });

  test('演示 RCON 支持预设命令并响应 kick', () async {
    final client = RconClient.demo();
    addTearDown(client.disconnect);
    expect(await client.connect('demo.local', 25575, 'demo'), isTrue);

    expect(await client.executeCommand('tps'), contains('20.0'));
    expect(await client.executeCommand('seed'), contains('Seed'));
    expect(await client.executeCommand('say 你好'), contains('你好'));
    expect(await client.executeCommand('weather clear'), contains('clear'));
    expect(await client.executeCommand('time set day'), contains('day'));
    expect(
      await client.executeCommand('difficulty peaceful'),
      contains('peaceful'),
    );
    expect(await client.executeCommand('whitelist list'), contains('0'));

    expect(await client.executeCommand('kick Alex'), contains('Alex'));
    expect(await client.executeCommand('list'), isNot(contains('Alex')));
    expect(await client.executeCommand('nonsense'), contains('Unknown'));
  });

  test('演示 SSH 终端回显输入并响应命令', () async {
    final service = SshShellService();
    addTearDown(service.disconnect);
    final out = StringBuffer();

    await service.connect(_demoServer(), onOutput: out.write);
    expect(service.isConnected, isTrue);
    expect(out.toString(), contains('demo@zvmanager-demo'));

    service.write('help\r');
    expect(out.toString(), contains('演示终端可用命令'));

    out.clear();
    service.write('ls\r');
    expect(out.toString(), contains('server.jar'));

    out.clear();
    service.write('cd logs\r');
    expect(out.toString(), contains('~/logs'));

    out.clear();
    service.write('cat eula.txt\r');
    expect(out.toString(), contains('eula=true'));

    out.clear();
    service.write('./start.sh\r');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(out.toString(), contains('Done'));
  });

  test('演示 SFTP 提供模组、插件、日志与增删改', () async {
    final sftp = SftpService();
    addTearDown(sftp.disconnect);
    await sftp.connect(_demoServer());
    expect(sftp.isConnected, isTrue);

    final mods = await sftp.listDir('/home/demo/mods');
    expect(mods.length, 4);
    expect(mods.any((e) => e.attr.isDirectory), isFalse);

    final plugins = await sftp.listDir('/home/demo/plugins');
    expect(plugins.map((e) => e.filename), contains('EssentialsX-2.20.1.jar'));

    final logs = await sftp.listDir('/home/demo/logs');
    expect(logs.map((e) => e.filename), contains('latest.log'));
    final log = await sftp.readString('/home/demo/logs/latest.log');
    expect(log, contains('[Server thread/INFO]'));

    await sftp.rename(
      '/home/demo/mods/fabric-api-0.92.2+1.20.1.jar',
      'renamed.jar',
    );
    expect(
      (await sftp.listDir('/home/demo/mods')).map((e) => e.filename),
      contains('renamed.jar'),
    );
    await sftp.delete('/home/demo/mods/renamed.jar');
    expect(
      (await sftp.listDir('/home/demo/mods')).map((e) => e.filename),
      isNot(contains('renamed.jar')),
    );
  });

  test('演示 jar 可被 JarMetadata 解析', () {
    final fs = DemoFileSystem();

    final fabric = ZipDecoder().decodeBytes(
      fs.bytesOf('/home/demo/mods/jei-1.20.1-forge-15.20.0.106.jar'),
    );
    final fabricMeta = JarMetadata.parseArchive(fabric);
    expect(fabricMeta.name, 'Just Enough Items');
    expect(fabricMeta.version, '15.20.0.106');

    final plugin = ZipDecoder().decodeBytes(
      fs.bytesOf('/home/demo/plugins/EssentialsX-2.20.1.jar'),
    );
    final pluginMeta = JarMetadata.parseArchive(plugin);
    expect(pluginMeta.name, 'EssentialsX');
    expect(pluginMeta.depends, contains('Vault'));
  });
}
