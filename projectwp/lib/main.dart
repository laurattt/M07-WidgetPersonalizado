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
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
  ),
);

void main() {
  runApp(const MyApp());
}

Future<void> getServers() async {
  // 1. Cargar el archivo como String
  final String response = await rootBundle.loadString(
    'assets/json/servers.json',
  );
  List<ServerInfo> _servers = [];

  // 2. Decodificar a un Map o List
  final data = jsonDecode(response);

  // 3. Convertir a una lista de ServerInfo
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
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
    Color connectedColor = Colors.lightGreen;
    Color disconnectedColor = Colors.redAccent;
    Color connectionColor = disconnectedColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //  Visualización
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.blueGrey[900],
                height: double.infinity,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: servers.length,
                          itemBuilder: (context, index) {
                            final server = servers[index];
                            return ListTile(
                              title: Text(
                                server.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                server.ip,
                                style: const TextStyle(color: Colors.white70),
                              ),
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
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Configuración
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Configuración SSH",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: _servernameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Server Name',
                        prefixIcon: Icon(Icons.person_outline),
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
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (value) => currentUsername = value,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Host',
                        prefixIcon: Icon(Icons.language),
                      ),
                      onChanged: (value) => currentIP = value,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Port',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      onChanged: (value) =>
                          currentPort = int.tryParse(value) ?? 22,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Key',
                        prefixIcon: Icon(Icons.key),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton.icon(
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
                                builder: (context) =>
                                    FileExplorerPage(manager: sshManager),
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
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onPressed: () async {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatPermissions(int? mode) {
  if (mode == null) return '---------';

  // Extraemos los últimos 9 bits (rwxrwxrwx)
  final bits = mode & 0x1FF;

  String res = '';
  final chars = ['r', 'w', 'x'];

  for (int i = 0; i < 9; i++) {
    // Verificamos cada bit de mayor a menor importancia
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
  SftpClient?
  _sftp; // Teniendo un solo cliente SFTP para no estar creando una y otra vez

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
      return true; // Éxito en la conexión inicial
    } catch (e) {
      logger.e("Connection error: $e");
      return false; // Fallo
    }
  }

  Future<void> switchPermission(
    String filePath,
    String permission,
    bool add,
  ) async {
    if (_client == null) return;

    try {
      // 1. Iniciar el cliente SFTP
      _sftp ??= await _client!.sftp();

      // 2. Obtener atributos actuales
      final attrs = await _sftp!.stat(filePath);
      int mode = attrs.mode?.value ?? 0;

      // 3. Modificar permisos
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
        mode |= permBit; // Añadir permiso
      } else {
        mode &= ~permBit; // Quitar permiso
      }

      // 4. Aplicar nuevos permisos
      await _sftp!.setStat(
        filePath,
        SftpFileAttrs(mode: SftpFileMode.value(mode)),
      );
      logger.i("Permisos actualizados para $filePath");
    } catch (e) {
      logger.e("Error cambiando permisos: $e");
      _sftp = null; // Forzando reconexión si hay error
    }
  }

  Future<void> changeFileName(String oldPath, String newPath) async {
    if (_client == null) return;

    try {
      // 1. Iniciar el cliente SFTP
      _sftp ??= await _client!.sftp();

      // 2. Renombrar el archivo
      await _sftp!.rename(oldPath, newPath);
      logger.i("Archivo renombrado de $oldPath a $newPath");
    } catch (e) {
      logger.e("Error renombrando archivo: $e");
      _sftp = null; // Forzando reconexión si hay error
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
      _sftp = null; // Forzando reconexión si hay error
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
    // Usamos p.posix para rutas remotas (siempre "/")
    final folderName = p.posix.basename(remotePath);
    final zipName =
        "${folderName}_${DateTime.now().millisecondsSinceEpoch}.zip";

    // Usamos el HOME del servidor (~) para asegurar permisos de escritura
    final remoteZipPath = "~/$zipName";
    final localZipPath = p.join(localDir, zipName);

    try {
      logger.i('Comprimiendo carpeta en el servidor...');
      final parentDir = p.posix.dirname(remotePath);

      // Comando: entrar al padre, comprimir y guardar en el HOME
      await _client!.execute(
        'cd "$parentDir" && zip -r "$remoteZipPath" "$folderName"',
      );

      _sftp ??= await _client!.sftp();

      logger.i('Descargando ZIP...');
      // Abrimos el archivo por su nombre (relativo al home del usuario SFTP)
      final remoteFile = await _sftp!.open(zipName);
      final localFile = File(localZipPath);

      final ios = localFile.openWrite();
      await ios.addStream(remoteFile.read());
      await ios.close();

      logger.i('Descomprimiendo localmente...');

      // SOLUCIÓN AL ERROR decodeBuffer:
      // Usamos decodeBytes cargando el archivo en un buffer de memoria
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

      // Limpieza
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
      // 1. Iniciar el cliente SFTP
      _sftp ??= await _client!.sftp();

      // 2. Eliminar el archivo
      await _sftp!.remove(filePath);
      logger.i("Archivo eliminado: $filePath");
    } catch (e) {
      logger.e("Error eliminando archivo: $e");
      _sftp = null; // Forzando reconexión si hay error
    }
  }

  Future<void> downloadAsZip(String remotePath) async {
    if (_client == null) return;

    // nombre base y timestamp para el ZIP
    final String baseName = p.basename(remotePath);
    final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String zipName = "${baseName}_$timeStamp.zip";

    // aseguramos cliente SFTP activo
    _sftp ??= await _client!.sftp();

    final downloadsDir = await getDownloadsDirectory();
    final localZipPath = p.join(downloadsDir!.path, zipName);

    try {
      logger.i('Comprimiendo en el servidor...');

      final parentDir = p.dirname(remotePath);
      final folderName = p.basename(remotePath);

      // crear zip con ruta relativa al directorio padre
      // escapar comillas en rutas para el shell
      final safeParent = parentDir.replaceAll('"', '\\"');
      final safeFolder = folderName.replaceAll('"', '\\"');
      final safeZipName = zipName.replaceAll('"', '\\"');

      // crear el zip en el mismo directorio padre donde está el archivo/carpeta
      final zipCommand =
          'cd "$safeParent" && zip -r "$safeZipName" "$safeFolder" && pwd';
      logger.i('Ejecutando comando: $zipCommand');
      final result = await _client!.execute(zipCommand);
      logger.i('Resultado del comando: $result');

      // la ruta remota es relativa a parentDir
      final remoteZipPath = p.join(parentDir, zipName);
      logger.i('Intentando abrir ZIP desde: $remoteZipPath');

      logger.i('Descargando ZIP desde el servidor...');
      final remoteFile = await _sftp!.open(remoteZipPath);
      final localFile = File(localZipPath);
      final ios = localFile.openWrite();
      await ios.addStream(remoteFile.read());
      await ios.close();

      // descomprimir en carpeta con el nombre original
      final extractDir = Directory(p.join(downloadsDir.path, baseName));
      if (!extractDir.existsSync()) extractDir.createSync(recursive: true);
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

      // limpiar archivos
      await _client!.execute('rm "${remoteZipPath}"').catchError((_) => {});
      if (await File(localZipPath).exists()) await File(localZipPath).delete();

      logger.i('¡Éxito! Archivos guardados en ${extractDir.path}');
    } catch (e) {
      logger.e('Error descargando/comprimiendo: $e');
      // intentar limpiar
      final zipPath = p.join(p.dirname(remotePath), "${baseName}_*.zip");
      await _client!.execute('rm $zipPath').catchError((_) => {});
    }
  }

  Future<void> listFiles(String path) async {
    if (_client == null) return;

    try {
      // 1. Iniciar el cliente SFTP
      _sftp ??= await _client!.sftp();

      // 2. Listar el directorio
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
      _sftp = null; // Forzando reconexión si hay error
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
            item.filename == 'build.gradle.kts')
          return 'java';
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
        // Only wait for output if it's not a background command
        final output = utf8.decode(
          await session.stdout.fold(
            <int>[],
            (previous, element) => previous..addAll(element),
          ),
        );
        logger.i("Command executed: $command, output: $output");
      } else {
        // Background command, just log and don't wait
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
        port = '3000'; // Default Node dev port
      } else if (type == 'java') {
        port = '8080'; // Default Spring Boot port
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

// Clase para la página de detalles del archivo
class FileDetailPage extends StatefulWidget {
  final SSHManager manager;
  final FileItem file;

  const FileDetailPage({super.key, required this.manager, required this.file});

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
    // Wait for the server to start up
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("File Details")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.file.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'File Name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  String oldPath = p.join(currentPath, widget.file.name);
                  String newPath = p.join(currentPath, value);
                  widget.manager.changeFileName(oldPath, newPath);
                  setState(() {
                    widget.file.name = value;
                    widget.manager.listFiles(currentPath);
                  });
                },
                controller: TextEditingController(text: widget.file.name),
              ),
            ),

            const SizedBox(width: 16),
            Icon(
              widget.file.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 200,
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // Mostramos un snackbar o indicador de carga
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Iniciando descarga...")),
                    );

                    // Construimos la ruta usando p.posix para asegurar '/'
                    String fullRemotePath = p.posix.join(
                      currentPath,
                      widget.file.name,
                    );

                    await widget.manager.downloadPath(fullRemotePath);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Descarga completada")),
                      );
                    }
                  },
                  child: const Text("Download"),
                ),
                SizedBox(width: 16),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      widget.manager.deleteFile(
                        p.join(currentPath, widget.file.name),
                      );
                      widget.manager.listFiles(currentPath).then((_) {
                        Navigator.pop(
                          context,
                        ); // Esperando a que se liste después de borrar para volver
                      });
                    });
                  },
                  child: const Text("Delete"),
                ),
              ],
            ),

            ///////////////////////////////////////// PERMISOS
            const SizedBox(height: 24),
            Text(
              "Permissions",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[0] == 'r'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '1r',
                        widget.file.permissions[0] != 'r',
                      );
                      widget.file.permissions =
                          widget.file.permissions[0] == 'r'
                          ? widget.file.permissions.replaceRange(0, 1, '-')
                          : widget.file.permissions.replaceRange(0, 1, 'r');

                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("R"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[1] == 'w'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '1w',
                        widget.file.permissions[1] != 'w',
                      );
                      widget.file.permissions =
                          widget.file.permissions[1] == 'w'
                          ? widget.file.permissions.replaceRange(1, 2, '-')
                          : widget.file.permissions.replaceRange(1, 2, 'w');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("W"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[2] == 'x'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '1x',
                        widget.file.permissions[2] != 'x',
                      );
                      widget.file.permissions =
                          widget.file.permissions[2] == 'x'
                          ? widget.file.permissions.replaceRange(2, 3, '-')
                          : widget.file.permissions.replaceRange(2, 3, 'x');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("X"),
                ),

                SizedBox(width: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[3] == 'r'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '2r',
                        widget.file.permissions[3] != 'r',
                      );
                      widget.file.permissions =
                          widget.file.permissions[3] == 'r'
                          ? widget.file.permissions.replaceRange(3, 4, '-')
                          : widget.file.permissions.replaceRange(3, 4, 'r');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("R"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[4] == 'w'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '2w',
                        widget.file.permissions[4] != 'w',
                      );
                      widget.file.permissions =
                          widget.file.permissions[4] == 'w'
                          ? widget.file.permissions.replaceRange(4, 5, '-')
                          : widget.file.permissions.replaceRange(4, 5, 'w');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("W"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[5] == 'x'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '2x',
                        widget.file.permissions[5] != 'x',
                      );
                      widget.file.permissions =
                          widget.file.permissions[5] == 'x'
                          ? widget.file.permissions.replaceRange(5, 6, '-')
                          : widget.file.permissions.replaceRange(5, 6, 'x');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("X"),
                ),

                SizedBox(width: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[6] == 'r'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '3r',
                        widget.file.permissions[6] != 'r',
                      );
                      widget.file.permissions =
                          widget.file.permissions[6] == 'r'
                          ? widget.file.permissions.replaceRange(6, 7, '-')
                          : widget.file.permissions.replaceRange(6, 7, 'r');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("R"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[7] == 'w'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '3w',
                        widget.file.permissions[7] != 'w',
                      );
                      widget.file.permissions =
                          widget.file.permissions[7] == 'w'
                          ? widget.file.permissions.replaceRange(7, 8, '-')
                          : widget.file.permissions.replaceRange(7, 8, 'w');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("W"),
                ),
                SizedBox(width: buttonPadding),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.file.permissions[8] == 'x'
                        ? AppColors.permissionColor
                        : AppColors.noPermissionColor,
                  ),
                  onPressed: () {
                    setState(() {
                      widget.manager.switchPermission(
                        p.join(currentPath, widget.file.name),
                        '3x',
                        widget.file.permissions[8] != 'x',
                      );
                      widget.file.permissions =
                          widget.file.permissions[8] == 'x'
                          ? widget.file.permissions.replaceRange(8, 9, '-')
                          : widget.file.permissions.replaceRange(8, 9, 'x');
                      widget.manager.listFiles(currentPath);
                    });
                  },
                  child: Text("X"),
                ),
              ],
            ),

            const SizedBox(height: 24),
            if (serverType != null) ...[
              Text(
                "Server Controls",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Status: ${isRunning ? 'Running' : 'Stopped'}",
                style: TextStyle(
                  fontSize: 16,
                  color: isRunning ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: startServer,
                    child: const Text("Start"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: stopServer,
                    child: const Text("Stop"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: restartServer,
                    child: const Text("Restart"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Clase para la página del explorador de archivos
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
    setState(() {}); // Refrescando vista
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900], // Para que se vea el texto blanco
      appBar: AppBar(title: const Text("Proxmox Drive")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color.fromARGB(255, 18, 23, 26),
            width: double.infinity,
            child: Text(
              currentPath,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: currentFiles.length,
              itemBuilder: (context, index) {
                final file = currentFiles[index];
                return ListTile(
                  leading: Icon(
                    file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: file.isDirectory ? Colors.amber : Colors.blueAccent,
                  ),
                  title: Text(
                    file.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    if (file.isDirectory) {
                      logger.i("Entrando en: ${file.name}");
                      if (file.name == "..") {
                        // Navegar al directorio anterior
                        String parentPath = p.dirname(currentPath);
                        _navigateTo(parentPath);
                      } else {
                        // Navegar al subdirectorio
                        String newPath = p.join(currentPath, file.name);
                        _navigateTo(newPath);
                      }
                    }
                  },
                  onLongPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FileDetailPage(manager: widget.manager, file: file),
                      ),
                    ).then((_) {
                      // Con esto puedo actualizar la UI al volver
                      widget.manager.listFiles(currentPath);
                      setState(() {});
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.upload),
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
    // 1. Obtener la ruta de la carpeta de documentos de la app
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/servers.json');

    // 2. Convertir la lista o mapa a una cadena JSON legible
    String jsonString = jsonEncode(servers.map((s) => s.toJson()).toList());
    logger.i(jsonString);

    // 3. Escribir el archivo
    await file.writeAsString(jsonString);

    logger.i("Archivo guardado en: ${file.path}");
  } catch (e) {
    logger.e("Error: $e");
  }
}
