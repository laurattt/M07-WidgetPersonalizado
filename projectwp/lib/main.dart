import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/widget_previews.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

SSHManager sshManager = SSHManager();
bool isConnected = false;
List<ServerInfo> servers = [];

List<FileItem> currentFiles = [];
String currentPath = "/";

class FileItem {
  String name;
  final bool isDirectory;
  final bool isImage;
  String permissions;

  FileItem({
    required this.name,
    required this.isDirectory,
    required this.isImage,
    required this.permissions,
  });
}

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: false,
  ),
);

void main() {
  runApp(const MyApp());
}

Future<void> getServers() async {
  final String response = await rootBundle.loadString(
    'assets/json/servers.json',
  );

  List<ServerInfo> _servers = [];
  final data = jsonDecode(response);

  for (var serverJson in data["servers"]) {
    ServerInfo server = ServerInfo.fromJson(serverJson);
    logger.i("Server Name: ${server.name}, IP: ${server.ip}");
    _servers.add(server);
  }

  servers = _servers;
}

class AppColors {
  static const Color permissionColor = Color.fromRGBO(137, 213, 137, 1);
  static const Color noPermissionColor = Color.fromRGBO(200, 100, 100, 1);
}

class ServerInfo {
  int id;
  String name;
  String ip;
  int port;
  String username;
  String key;

  ServerInfo({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.username,
    required this.key,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      id: json['id'],
      name: json['name'],
      ip: json['host'],
      port: json['port'],
      username: json['username'],
      key: json['key'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'username': username,
      'key': key,
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'File Manager'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController _servernameController;
  late TextEditingController _userController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    _servernameController = TextEditingController(text: "Laura");
    _userController = TextEditingController(text: "ltorocordero");
    _hostController = TextEditingController(text: "ieticloudpro.ieti.cat");
    _portController = TextEditingController(text: "20127");
    _keyController = TextEditingController(text: "id_rsa");
    _loadServers();
  }

  void _loadServers() async {
    await getServers();
    setState(() {});
  }

  void _getCurrentFiles(String route) async {
    await sshManager.listFiles(route);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    int currentServerId = 1;
    String currentServername = "Laura";
    String currentUsername = "ltorocordero";
    String currentIP = "ieticloudpro.ieti.cat";
    String currentKey = "id_rsa";
    int currentPort = 20127;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              color: const Color(0xFF18232E),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Servidores",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Selecciona una conexión SSH",
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      itemCount: servers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final server = servers[index];

                        return Material(
                          color: const Color(0xFF223140),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                currentServerId = server.id;
                                _servernameController.text = server.name;
                                _userController.text = server.username;
                                _hostController.text = server.ip;
                                _portController.text = server.port.toString();
                                _keyController.text = server.key;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey[700],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.dns,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          server.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          server.ip,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF101820),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.terminal,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Configuración SSH",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Datos de conexión del servidor",
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _servernameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Server Name',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        onChanged: (value) => currentServername = value,
                        onEditingComplete: () => {
                          changeServerName(currentServerId, currentServername),
                          saveServers(servers),
                          _loadServers(),
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        onChanged: (value) => currentUsername = value,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Host',
                          prefixIcon: const Icon(Icons.language),
                        ),
                        onChanged: (value) => currentIP = value,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Port',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        onChanged: (value) =>
                            currentPort = int.tryParse(value) ?? 22,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _keyController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Key',
                          prefixIcon: const Icon(Icons.key),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF101820),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.link),
                                label: const Text('Connect'),
                                onPressed: () async {
                                  bool success = await sshManager.connect(
                                    _userController.text,
                                    _hostController.text,
                                    int.tryParse(_portController.text) ?? 22,
                                    _keyController.text,
                                  );

                                  if (success && mounted) {
                                    await sshManager.listFiles(currentPath);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FileExplorerPage(
                                          manager: sshManager,
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Error al conectar"),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                onPressed: () async {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatPermissions(int? mode) {
  if (mode == null) return '---------';

  final bits = mode & 0x1FF;

  String res = '';
  final chars = ['r', 'w', 'x'];

  for (int i = 0; i < 9; i++) {
    if ((bits >> (8 - i)) & 1 == 1) {
      res += chars[i % 3];
    } else {
      res += '-';
    }
  }

  return res;
}

class SSHManager {
  SSHClient? _client;
  SftpClient? _sftp;

  bool shouldReconnect = true;

  Future<bool> connect(String username, String ip, int port, String key) async {
    try {
      logger.i("Attempting to connect to $ip:$port");
      final socket = await SSHSocket.connect(ip, port);

      _client = SSHClient(
        socket,
        username: username,
        keepAliveInterval: const Duration(seconds: 30),
        identities: [...SSHKeyPair.fromPem(await getPrivateKey(key))],
      );

      logger.i("Connected to $ip:$port");
      isConnected = true;
      return true;
    } catch (e) {
      logger.e("Connection error: $e");
      return false;
    }
  }

  Future<void> switchPermission(
    String filePath,
    String permission,
    bool add,
  ) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();

      final attrs = await _sftp!.stat(filePath);
      int mode = attrs.mode?.value ?? 0;

      int permBit = 0;

      switch (permission) {
        case '1r':
          permBit = 0x100;
          break;
        case '1w':
          permBit = 0x80;
          break;
        case '1x':
          permBit = 0x40;
          break;
        case '2r':
          permBit = 0x20;
          break;
        case '2w':
          permBit = 0x10;
          break;
        case '2x':
          permBit = 0x8;
          break;
        case '3r':
          permBit = 0x4;
          break;
        case '3w':
          permBit = 0x2;
          break;
        case '3x':
          permBit = 0x1;
          break;
      }

      if (add) {
        mode |= permBit;
      } else {
        mode &= ~permBit;
      }

      await _sftp!.setStat(
        filePath,
        SftpFileAttrs(mode: SftpFileMode.value(mode)),
      );

      logger.i("Permisos actualizados para $filePath");
    } catch (e) {
      logger.e("Error cambiando permisos: $e");
      _sftp = null;
    }
  }

  Future<void> changeFileName(String oldPath, String newPath) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();

      await _sftp!.rename(oldPath, newPath);
      logger.i("Archivo renombrado de $oldPath a $newPath");
    } catch (e) {
      logger.e("Error renombrando archivo: $e");
      _sftp = null;
    }
  }

  final _remotePathContext = p.Context(style: p.Style.posix);

  Future<void> downloadPath(String remotePath) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();
      final stat = await _sftp!.stat(remotePath);
      final downloadsDir = await getDownloadsDirectory();

      if (stat.isDirectory) {
        await _downloadFolderAsZip(remotePath, downloadsDir!.path);
      } else {
        await _downloadSingleFile(remotePath, downloadsDir!.path);
      }
    } catch (e) {
      logger.e("Error en descarga: $e");
    }
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();

      final localFile = File(localPath);
      final fileName = p.basename(localPath);
      final remoteFilePath = p.posix.join(remotePath, fileName);

      logger.i("Subiendo archivo: $fileName a $remoteFilePath");

      final remoteFile = await _sftp!.open(
        remoteFilePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );

      final stream = localFile.openRead().map(
        (list) => Uint8List.fromList(list),
      );

      await remoteFile.write(stream);

      logger.i("Archivo subido exitosamente: $remoteFilePath");
    } catch (e) {
      logger.e("Error subiendo archivo: $e");
      _sftp = null;
    }
  }

  Future<void> _downloadSingleFile(String remotePath, String localDir) async {
    final fileName = _remotePathContext.basename(remotePath);
    final localPath = p.join(localDir, fileName);

    logger.i("Descargando archivo individual: $fileName");

    final remoteFile = await _sftp!.open(remotePath);
    final localFile = File(localPath);
    final ios = localFile.openWrite();

    await ios.addStream(remoteFile.read());
    await ios.close();

    logger.i("Archivo guardado en: $localPath");
  }

  Future<void> _downloadFolderAsZip(String remotePath, String localDir) async {
    final folderName = p.posix.basename(remotePath);
    final zipName =
        "${folderName}_${DateTime.now().millisecondsSinceEpoch}.zip";

    final remoteZipPath = "~/$zipName";
    final localZipPath = p.join(localDir, zipName);

    try {
      logger.i('Comprimiendo carpeta en el servidor...');

      final parentDir = p.posix.dirname(remotePath);

      await _client!.execute(
        'cd "$parentDir" && zip -r "$remoteZipPath" "$folderName"',
      );

      _sftp ??= await _client!.sftp();

      logger.i('Descargando ZIP...');

      final remoteFile = await _sftp!.open(zipName);
      final localFile = File(localZipPath);

      final ios = localFile.openWrite();
      await ios.addStream(remoteFile.read());
      await ios.close();

      logger.i('Descomprimiendo localmente...');

      final bytes = File(localZipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final String filename = file.name;
        final String destPath = p.join(localDir, filename);

        if (file.isFile) {
          final data = file.content as List<int>;

          File(destPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(destPath).createSync(recursive: true);
        }
      }

      logger.i('Limpiando archivos temporales...');

      await _client!.execute('rm "$remoteZipPath"');

      if (await File(localZipPath).exists()) {
        await File(localZipPath).delete();
      }

      logger.i('¡Carpeta descargada y descomprimida con éxito!');
    } catch (e) {
      logger.e('Fallo en proceso ZIP: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String filePath) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();

      await _sftp!.remove(filePath);

      logger.i("Archivo eliminado: $filePath");
    } catch (e) {
      logger.e("Error eliminando archivo: $e");
      _sftp = null;
    }
  }

  Future<void> downloadAsZip(String remotePath) async {
    if (_client == null) return;

    final String baseName = p.basename(remotePath);
    final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String zipName = "${baseName}_$timeStamp.zip";

    _sftp ??= await _client!.sftp();

    final downloadsDir = await getDownloadsDirectory();
    final localZipPath = p.join(downloadsDir!.path, zipName);

    try {
      logger.i('Comprimiendo en el servidor...');

      final parentDir = p.dirname(remotePath);
      final folderName = p.basename(remotePath);

      final safeParent = parentDir.replaceAll('"', '\\"');
      final safeFolder = folderName.replaceAll('"', '\\"');
      final safeZipName = zipName.replaceAll('"', '\\"');

      final zipCommand =
          'cd "$safeParent" && zip -r "$safeZipName" "$safeFolder" && pwd';

      logger.i('Ejecutando comando: $zipCommand');

      final result = await _client!.execute(zipCommand);

      logger.i('Resultado del comando: $result');

      final remoteZipPath = p.join(parentDir, zipName);

      logger.i('Intentando abrir ZIP desde: $remoteZipPath');
      logger.i('Descargando ZIP desde el servidor...');

      final remoteFile = await _sftp!.open(remoteZipPath);
      final localFile = File(localZipPath);
      final ios = localFile.openWrite();

      await ios.addStream(remoteFile.read());
      await ios.close();

      final extractDir = Directory(p.join(downloadsDir.path, baseName));

      if (!extractDir.existsSync()) {
        extractDir.createSync(recursive: true);
      }

      logger.i('Descomprimiendo localmente en ${extractDir.path}...');

      final bytes = File(localZipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        final destPath = p.join(extractDir.path, filename);

        if (file.isFile) {
          File(destPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(destPath).createSync(recursive: true);
        }
      }

      await _client!.execute('rm "${remoteZipPath}"').catchError((_) => {});

      if (await File(localZipPath).exists()) {
        await File(localZipPath).delete();
      }

      logger.i('¡Éxito! Archivos guardados en ${extractDir.path}');
    } catch (e) {
      logger.e('Error descargando/comprimiendo: $e');

      final zipPath = p.join(p.dirname(remotePath), "${baseName}_*.zip");
      await _client!.execute('rm $zipPath').catchError((_) => {});
    }
  }

  Future<void> listFiles(String path) async {
    if (_client == null) return;

    try {
      _sftp ??= await _client!.sftp();

      final items = await _sftp!.listdir(path);

      currentFiles.clear();

      for (final item in items) {
        currentFiles.add(
          FileItem(
            name: item.filename,
            isDirectory: item.attr.isDirectory,
            isImage: isImageFile(item.filename),
            permissions: formatPermissions(item.attr.mode?.value),
          ),
        );
      }
    } catch (e) {
      logger.e("Error listando archivos: $e");
      _sftp = null;
    }
  }

  Future<String> getPrivateKey(String file) async {
    String home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

    String keyPath = p.join(home, '.ssh', file);

    File keyFile = File(keyPath);

    if (await keyFile.exists()) {
      return await keyFile.readAsString();
    } else {
      throw Exception("Private key file not found: $keyPath");
    }
  }

  Future<String?> checkServerType(String path) async {
    if (_client == null) return null;

    try {
      _sftp ??= await _client!.sftp();

      final items = await _sftp!.listdir(path);

      for (final item in items) {
        if (item.filename == 'package.json') return 'node';

        if (item.filename == 'pom.xml' ||
            item.filename == 'build.gradle' ||
            item.filename == 'build.gradle.kts') {
          return 'java';
        }
      }

      return null;
    } catch (e) {
      logger.e("Error checking server type: $e");
      return null;
    }
  }

  Future<void> executeCommand(String command) async {
    if (_client == null) return;

    try {
      final session = await _client!.execute(command);

      if (!command.trim().endsWith('&')) {
        final output = utf8.decode(
          await session.stdout.fold(
            <int>[],
            (previous, element) => previous..addAll(element),
          ),
        );

        logger.i("Command executed: $command, output: $output");
      } else {
        logger.i("Background command executed: $command");
      }
    } catch (e) {
      logger.e("Error executing command: $e");
    }
  }

  Future<bool> isServerRunning(String type, String path) async {
    if (_client == null) return false;

    try {
      String port;

      if (type == 'node') {
        port = '3000';
      } else if (type == 'java') {
        port = '8080';
      } else {
        return false;
      }

      final command = 'ss -tln | grep :$port || netstat -tln | grep :$port';
      final session = await _client!.execute(command);

      final output = utf8.decode(
        await session.stdout.fold(
          <int>[],
          (previous, element) => previous..addAll(element),
        ),
      );

      return output.trim().isNotEmpty;
    } catch (e) {
      logger.e("Error checking server status: $e");
      return false;
    }
  }
}

class FileDetailPage extends StatefulWidget {
  final SSHManager manager;
  final FileItem file;

  const FileDetailPage({
    super.key,
    required this.manager,
    required this.file,
  });

  @override
  State<FileDetailPage> createState() => _FileDetailPageState();
}

class _FileDetailPageState extends State<FileDetailPage> {
  double buttonPadding = 4;
  String? serverType;
  bool isRunning = false;

  @override
  void initState() {
    super.initState();

    if (widget.file.isDirectory) {
      _checkServerType();
    }
  }

  Future<void> _checkServerType() async {
    serverType = await widget.manager.checkServerType(
      p.posix.join(currentPath, widget.file.name),
    );

    if (serverType != null) {
      await _checkServerStatus();
    }

    setState(() {});
  }

  Future<void> _checkServerStatus() async {
    isRunning = await widget.manager.isServerRunning(
      serverType!,
      p.posix.join(currentPath, widget.file.name),
    );

    setState(() {});
  }

  Future<void> startServer() async {
    String path = p.posix.join(currentPath, widget.file.name);
    String command;

    if (serverType == 'node') {
      command = 'cd "$path" && nohup npm run dev > /dev/null 2>&1 &';
    } else if (serverType == 'java') {
      command = 'cd "$path" && nohup mvn spring-boot:run > /dev/null 2>&1 &';
    } else {
      return;
    }

    await widget.manager.executeCommand(command);

    await Future.delayed(const Duration(seconds: 3));

    await _checkServerStatus();
  }

  Future<void> stopServer() async {
    String process = serverType == 'node' ? 'node' : 'java';

    await widget.manager.executeCommand('pkill -f $process');

    await _checkServerStatus();
  }

  Future<void> restartServer() async {
    await stopServer();

    await Future.delayed(const Duration(seconds: 2));

    await startServer();
  }

  Widget permissionButton({
    required String text,
    required int index,
    required String permission,
    required String activeLetter,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: widget.file.permissions[index] == activeLetter
              ? AppColors.permissionColor
              : AppColors.noPermissionColor,
          foregroundColor: const Color(0xFF101820),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          setState(() {
            widget.manager.switchPermission(
              p.join(currentPath, widget.file.name),
              permission,
              widget.file.permissions[index] != activeLetter,
            );

            widget.file.permissions = widget.file.permissions[index] ==
                    activeLetter
                ? widget.file.permissions.replaceRange(index, index + 1, '-')
                : widget.file.permissions.replaceRange(
                    index,
                    index + 1,
                    activeLetter,
                  );

            widget.manager.listFiles(currentPath);
          });
        },
        child: Text(text),
      ),
    );
  }

  Widget permissionGroup({
    required String title,
    required List<Widget> buttons,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF101820),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...buttons.map(
            (button) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: button,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
        title: const Text("File Details"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 980),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: widget.file.isDirectory
                              ? Colors.amber.withOpacity(0.18)
                              : Colors.blueAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          widget.file.isDirectory
                              ? Icons.folder
                              : Icons.insert_drive_file,
                          size: 70,
                          color: widget.file.isDirectory
                              ? Colors.amber[800]
                              : Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.file.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101820),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 430,
                        child: TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF4F6F8),
                            labelText: 'File Name',
                            prefixIcon: const Icon(Icons.edit),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (value) {
                            String oldPath = p.join(
                              currentPath,
                              widget.file.name,
                            );
                            String newPath = p.join(currentPath, value);

                            widget.manager.changeFileName(oldPath, newPath);

                            setState(() {
                              widget.file.name = value;
                              widget.manager.listFiles(currentPath);
                            });
                          },
                          controller: TextEditingController(
                            text: widget.file.name,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF101820),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Iniciando descarga..."),
                                ),
                              );

                              String fullRemotePath = p.posix.join(
                                currentPath,
                                widget.file.name,
                              );

                              await widget.manager.downloadPath(fullRemotePath);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Descarga completada"),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: const Text("Download"),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                widget.manager.deleteFile(
                                  p.join(currentPath, widget.file.name),
                                );

                                widget.manager.listFiles(currentPath).then((_) {
                                  Navigator.pop(context);
                                });
                              });
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text("Delete"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      if (serverType != null) ...[
                        Container(
                          width: 430,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Server Controls",
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101820),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Status: ${isRunning ? 'Running' : 'Stopped'}",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isRunning ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: startServer,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text("Start"),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: stopServer,
                                    icon: const Icon(Icons.stop),
                                    label: const Text("Stop"),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: restartServer,
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text("Restart"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              color: Color(0xFF101820),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Permissions",
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101820),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.file.permissions,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 22),
                        permissionGroup(
                          title: "Owner",
                          buttons: [
                            permissionButton(
                              text: "Read",
                              index: 0,
                              permission: '1r',
                              activeLetter: 'r',
                            ),
                            permissionButton(
                              text: "Write",
                              index: 1,
                              permission: '1w',
                              activeLetter: 'w',
                            ),
                            permissionButton(
                              text: "Execute",
                              index: 2,
                              permission: '1x',
                              activeLetter: 'x',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        permissionGroup(
                          title: "Group",
                          buttons: [
                            permissionButton(
                              text: "Read",
                              index: 3,
                              permission: '2r',
                              activeLetter: 'r',
                            ),
                            permissionButton(
                              text: "Write",
                              index: 4,
                              permission: '2w',
                              activeLetter: 'w',
                            ),
                            permissionButton(
                              text: "Execute",
                              index: 5,
                              permission: '2x',
                              activeLetter: 'x',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        permissionGroup(
                          title: "Other",
                          buttons: [
                            permissionButton(
                              text: "Read",
                              index: 6,
                              permission: '3r',
                              activeLetter: 'r',
                            ),
                            permissionButton(
                              text: "Write",
                              index: 7,
                              permission: '3w',
                              activeLetter: 'w',
                            ),
                            permissionButton(
                              text: "Execute",
                              index: 8,
                              permission: '3x',
                              activeLetter: 'x',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FileExplorerPage extends StatefulWidget {
  final SSHManager manager;

  const FileExplorerPage({super.key, required this.manager});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  void _navigateTo(String path) async {
    String cleanPath = p.normalize(path);
    currentPath = cleanPath;

    await widget.manager.listFiles(cleanPath);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
        title: const Text("Proxmox Drive"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open, color: Color(0xFF101820)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentPath,
                    style: const TextStyle(
                      color: Color(0xFF101820),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.separated(
                itemCount: currentFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final file = currentFiles[index];

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (file.isDirectory) {
                          logger.i("Entrando en: ${file.name}");

                          if (file.name == "..") {
                            String parentPath = p.dirname(currentPath);
                            _navigateTo(parentPath);
                          } else {
                            String newPath = p.join(currentPath, file.name);
                            _navigateTo(newPath);
                          }
                        }
                      },
                      onLongPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileDetailPage(
                              manager: widget.manager,
                              file: file,
                            ),
                          ),
                        ).then((_) {
                          widget.manager.listFiles(currentPath);
                          setState(() {});
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: file.isDirectory
                                    ? Colors.amber.withOpacity(0.18)
                                    : Colors.blueAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                file.isDirectory
                                    ? Icons.folder
                                    : Icons.insert_drive_file,
                                color: file.isDirectory
                                    ? Colors.amber[800]
                                    : Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                file.name,
                                style: const TextStyle(
                                  color: Color(0xFF101820),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              file.permissions,
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.more_vert,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload),
        label: const Text("Upload"),
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();

          if (result != null) {
            String? filePath = result.files.single.path;

            if (filePath != null) {
              await widget.manager.uploadFile(filePath, currentPath);
              await widget.manager.listFiles(currentPath);

              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("File uploaded successfully")),
              );
            }
          }
        },
      ),
    );
  }
}

bool isImageFile(String fileName) {
  final imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
  final extension = p.extension(fileName).toLowerCase();

  return imageExtensions.contains(extension);
}

void changeServerName(int serverId, String newName) {
  for (var server in servers) {
    if (server.id == serverId) {
      server = ServerInfo(
        id: server.id,
        name: newName,
        ip: server.ip,
        port: server.port,
        username: server.username,
        key: server.key,
      );

      logger.i("Server name changed to $newName");

      break;
    }
  }
}

Future<void> saveServers(List<ServerInfo> listaServers) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/servers.json');

    String jsonString = jsonEncode(servers.map((s) => s.toJson()).toList());

    logger.i(jsonString);

    await file.writeAsString(jsonString);

    logger.i("Archivo guardado en: ${file.path}");
  } catch (e) {
    logger.e("Error: $e");
  }
}