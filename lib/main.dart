import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Erro ao carregar .env: $e");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa o FlutterDownloader
  await FlutterDownloader.initialize();

  // Registra o callback para monitorar os downloads
  FlutterDownloader.registerCallback(downloadCallback);

  runApp(MyApp());
}


@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) async {
  print("Task: $id, Status: $status, Progress: $progress%");

  if (status == DownloadTaskStatus.complete) {
    final dir = await getExternalStorageDirectory();
    final apkPath = '${dir!.path}/app-release.apk';

    print('>>> Download concluído. Tentando instalar APK em: $apkPath');
    final result = await OpenFile.open(apkPath);
    print('>>> Resultado do OpenFile.open(): ${result.message}');
  }
}









class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowMonitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
            .copyWith(secondary: Colors.orange),
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
      home: SensorDataScreen(),
    );
  }
}

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({super.key});

  @override
  _SensorDataScreenState createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  double temperaturaInterna = 0.0;
  double temperaturaExterna = 0.0;
  double umidadeExterna = 0.0;
  double umidadeSolo1 = 0.0;
  double umidadeSolo2 = 0.0;

  String ultimaMedicao = "Nenhuma medição realizada";

  List<Map<String, dynamic>> historico = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _iniciarLeituraFirestore();
  }

  void _iniciarLeituraFirestore() {
    _firestore
        .collection('dados')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var dados = snapshot.docs.first.data();
        setState(() {
          temperaturaInterna = dados['temperaturaInterna'] ?? 0.0;
          temperaturaExterna = dados['temperaturaExterna'] ?? 0.0;
          umidadeExterna = dados['umidadeExterna'] ?? 0.0;
          umidadeSolo1 = dados['umidadeSolo1'] ?? 0.0;
          umidadeSolo2 = dados['umidadeSolo2'] ?? 0.0;

          Timestamp timestamp = dados['createdAt'] as Timestamp;
          DateTime dateTime = timestamp.toDate();
          ultimaMedicao = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);

          historico.add({
            'temperaturaInterna': temperaturaInterna,
            'temperaturaExterna': temperaturaExterna,
            'umidadeExterna': umidadeExterna,
            'umidadeSolo1': umidadeSolo1,
            'umidadeSolo2': umidadeSolo2,
            'horaMedicao': ultimaMedicao,
          });

          if (historico.length > 20) {
            historico.removeAt(0);
          }
        });
      }
    });
  }

  Future<void> checkForUpdate(BuildContext context) async {
  try {
    final currentVersion = await getCurrentVersion();
    print('Versão instalada: $currentVersion');

    final latestVersionInfo = await getLatestVersion();
    final latestVersion = latestVersionInfo['version'] as String;
    final apkUrl = latestVersionInfo['url'] as String;
    print('Versão disponível: $latestVersion');

    if (latestVersion != currentVersion) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Atualização Disponível'),
          content: Text(
            'Versão instalada: $currentVersion\n'
            'Versão disponível: $latestVersion\n'
            'Deseja atualizar agora?'
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Atualizar'),
              onPressed: () async {
                Navigator.of(context).pop();
                print('Usuário confirmou atualização — iniciando download...');
                try {
                  await downloadAndInstallAPK(apkUrl);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao baixar a atualização: $e'))
                  );
                }
              },
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Você já possui a versão mais recente: $currentVersion'))
      );
    }
  } catch (e) {
    print('Erro ao verificar atualização: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao verificar atualização: $e'))
    );
  }
}


  Future<String> getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<Map<String, dynamic>> getLatestVersion() async {
    try {
      final url =
          'https://raw.githubusercontent.com/CodeGreenLab/GrowMonitor_app/main/latest_version.json';
      print('Fazendo requisição para: $url');

      final response = await http.get(Uri.parse(url));
      print('Resposta recebida: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('JSON recebido: ${response.body}');
        return json.decode(response.body);
      } else {
        print('Erro na requisição: ${response.statusCode}');
        throw Exception('Falha ao verificar a versão mais recente');
      }
    } catch (e) {
      print('Erro ao verificar atualização: $e');
      throw e;
    }
  }

  Future<void> requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return;
    }
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Permissão para armazenamento negada');
    }
  }

  Future<void> requestInstallPermission() async {
    if (await Permission.requestInstallPackages.isGranted) {
      return;
    }
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw Exception('Permissão para instalar APKs negada');
    }
  }

Future<void> downloadAndInstallAPK(String url) async {
  // Apenas solicita permissão de instalação (INSTALL_PACKAGES)
  try {
    await Permission.requestInstallPackages.request();
  } catch (e) {
    print('Install-permission error (ignored): $e');
  }

  // Agora dispara o download SEM checagem de storage
  await _startDownload(url);
}

String? _currentTaskId;

Future<void> _startDownload(String url) async {
  Directory? directory;

  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdk = androidInfo.version.sdkInt;
    print('>>> Android SDK Int: $sdk');

    if (sdk < 29) {
      if (!await Permission.storage.isGranted) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Permissão de armazenamento negada');
        }
      }
    }

    directory = await getExternalStorageDirectory();
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  if (directory == null) {
    throw Exception('Não foi possível acessar o diretório de armazenamento');
  }

  print('>>> Diretório para salvar APK: ${directory.path}');

  try {
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: directory.path,
      fileName: 'app-release.apk',
      showNotification: true,
      openFileFromNotification: true,
    );

    _currentTaskId = taskId;
    print('>>> Download iniciado com taskId: $taskId');

    // Aguarda até que o download termine
    _monitorDownloadAndInstall(taskId, directory.path);
  } catch (e) {
    print('>>> Erro ao iniciar download: $e');
    rethrow;
  }
}

void _monitorDownloadAndInstall(String? taskId, String savedDir) async {
  if (taskId == null) {
    print('>>> taskId é nulo, abortando monitoramento.');
    return;
  }

  bool completed = false;

  while (!completed) {
    final tasks = await FlutterDownloader.loadTasks();

    try {
      final task = tasks!.firstWhere((t) => t.taskId == taskId);

      print('>>> Monitorando task ${task.taskId}: status ${task.status}, progresso ${task.progress}%');

      if (task.status == DownloadTaskStatus.complete) {
        completed = true;

        final apkPath = '$savedDir/app-release.apk';
        print('>>> Download finalizado. Instalando APK: $apkPath');
        final result = await OpenFile.open(apkPath);
        print('>>> Resultado da instalação: ${result.message}');
      }
    } catch (e) {
      print('>>> Nenhuma task encontrada com taskId: $taskId');
    }

    await Future.delayed(Duration(seconds: 1));
  }
}











  Widget buildGrafico() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < historico.length) {
                    String horaCompleta =
                        historico[value.toInt()]['horaMedicao'].toString();
                    if (horaCompleta.length >= 16) {
                      return Text(horaCompleta.substring(11, 16));
                    } else {
                      return Text(horaCompleta);
                    }
                  }
                  return Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: historico.asMap().entries.map((entry) {
                return FlSpot(
                    entry.key.toDouble(), entry.value['temperaturaInterna']!);
              }).toList(),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: historico.asMap().entries.map((entry) {
                return FlSpot(
                    entry.key.toDouble(), entry.value['temperaturaExterna']!);
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: historico.asMap().entries.map((entry) {
                return FlSpot(
                    entry.key.toDouble(), entry.value['umidadeExterna']!);
              }).toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 2,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.spa, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'GrowMonitor',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/background.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  color: Colors.white.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Última Medição',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hora: $ultimaMedicao',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  color: Colors.white.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temperaturas',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
                        ListTile(
                          leading: Icon(Icons.thermostat, color: Colors.red),
                          title: Text('Interna'),
                          subtitle: Text(
                              '${temperaturaInterna.toStringAsFixed(1)}°C'),
                        ),
                        ListTile(
                          leading: Icon(Icons.thermostat, color: Colors.blue),
                          title: Text('Externa'),
                          subtitle: Text(
                              '${temperaturaExterna.toStringAsFixed(1)}°C'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  color: Colors.white.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Umidades',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
                        ListTile(
                          leading:
                              Icon(Icons.water_drop, color: Colors.green),
                          title: Text('Externa'),
                          subtitle:
                              Text('${umidadeExterna.toStringAsFixed(1)}%'),
                        ),
                        ListTile(
                          leading: Icon(Icons.grass, color: Colors.brown),
                          title: Text('Solo 1'),
                          subtitle:
                              Text('${umidadeSolo1.toStringAsFixed(1)}%'),
                        ),
                        ListTile(
                          leading: Icon(Icons.grass, color: Colors.orange),
                          title: Text('Solo 2'),
                          subtitle:
                              Text('${umidadeSolo2.toStringAsFixed(1)}%'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Gráfico das Últimas 20 Medições',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                buildGrafico(),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    ElevatedButton(
      onPressed: () {
        checkForUpdate(context);
      },
      child: Text('Verificar Atualizações'),
    ),
    ElevatedButton(
      onPressed: () async {
        final info = await PackageInfo.fromPlatform();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Versão do App'),
            content: Text('Versão instalada: ${info.version}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      },
      child: Text('Versão'),
    ),
  ],
),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
