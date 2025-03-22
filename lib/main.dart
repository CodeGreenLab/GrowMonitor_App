import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importe o Firestore
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


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

  runApp(MyApp());
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
  // Dados dos sensores
  double temperaturaInterna = 0.0;
  double temperaturaExterna = 0.0;
  double umidadeExterna = 0.0;
  double umidadeSolo1 = 0.0;
  double umidadeSolo2 = 0.0;

  // Timestamp da última medição
  String ultimaMedicao = "Nenhuma medição realizada";

  // Lista para armazenar as últimas 20 medições
  List<Map<String, dynamic>> historico = [];

  // Referência ao Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Inicia a leitura dos dados do Firestore
    _iniciarLeituraFirestore();
  }

  // Função para iniciar a leitura dos dados do Firestore
void _iniciarLeituraFirestore() {
  _firestore
      .collection('dados')
      .orderBy('horaMedicao', descending: true) // Ordenando corretamente
      .limit(1) // Pegando apenas o último registro
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
        ultimaMedicao = dados['horaMedicao'] ?? "Horário não disponível";

        // Atualiza histórico
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


  // Função para construir o gráfico
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
                    String horaCompleta = historico[value.toInt()]['horaMedicao'].toString();
                    if (horaCompleta.length >= 16) {
                      return Text(horaCompleta.substring(11, 16)); // Exibe apenas a hora e o minuto
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
                return FlSpot(entry.key.toDouble(), entry.value['temperaturaInterna']!);
              }).toList(),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: historico.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value['temperaturaExterna']!);
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: historico.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value['umidadeExterna']!);
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
                // Card para exibir a última medição
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
                // Card para temperaturas
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
                          subtitle: Text('${temperaturaInterna.toStringAsFixed(1)}°C'),
                        ),
                        ListTile(
                          leading: Icon(Icons.thermostat, color: Colors.blue),
                          title: Text('Externa'),
                          subtitle: Text('${temperaturaExterna.toStringAsFixed(1)}°C'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Card para umidades
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
                          leading: Icon(Icons.water_drop, color: Colors.green),
                          title: Text('Externa'),
                          subtitle: Text('${umidadeExterna.toStringAsFixed(1)}%'),
                        ),
                        ListTile(
                          leading: Icon(Icons.grass, color: Colors.brown),
                          title: Text('Solo 1'),
                          subtitle: Text('${umidadeSolo1.toStringAsFixed(1)}%'),
                        ),
                        ListTile(
                          leading: Icon(Icons.grass, color: Colors.orange),
                          title: Text('Solo 2'),
                          subtitle: Text('${umidadeSolo2.toStringAsFixed(1)}%'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Gráfico
                Text(
                  'Gráfico das Últimas 20 Medições',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                buildGrafico(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}