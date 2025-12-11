import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'financial_logic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evaluador Financiero AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const FinancialHomePage(),
      },
    );
  }
}

class FinancialHomePage extends StatefulWidget {
  const FinancialHomePage({super.key});

  @override
  State<FinancialHomePage> createState() => _FinancialHomePageState();
}

class _FinancialHomePageState extends State<FinancialHomePage> {
  String? _fileName;
  FinancialData? _financialData;
  List<FinancialIndicator>? _results;
  bool _isLoading = false;
  String? _errorMessage;

  // Función para cargar archivo
  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _results = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // Importante para Web
      );

      if (result != null) {
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          setState(() {
            _isLoading = true;
            _fileName = fileName;
          });

          // Procesar el archivo
          final data = await FinancialAnalyzer.parseExcel(fileBytes);
          
          setState(() {
            _financialData = data;
            _isLoading = false;
          });

          if (!_financialData!.isValid) {
             setState(() {
              _errorMessage = "No se pudieron detectar datos financieros válidos. Asegúrate de que el Excel tenga columnas con nombres como 'Activo Total', 'Ventas', 'Utilidad Neta'.";
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error al leer el archivo: $e";
      });
    }
  }

  // Función para cargar datos de prueba (Demo)
  void _loadDemoData() {
    final demoData = FinancialData()
      ..totalAssets = 150000
      ..currentAssets = 60000
      ..inventory = 20000
      ..totalLiabilities = 80000
      ..currentLiabilities = 40000
      ..totalEquity = 70000
      ..netSales = 200000
      ..costOfGoodsSold = 120000
      ..netIncome = 30000
      ..operatingIncome = 45000
      ..interestExpense = 5000;

    setState(() {
      _fileName = "Datos de Prueba (Demo)";
      _financialData = demoData;
      _results = null;
      _errorMessage = null;
    });
  }

  // Función para ejecutar la evaluación
  void _runEvaluation() {
    if (_financialData == null) return;
    
    final indicators = FinancialAnalyzer.evaluate(_financialData!);
    setState(() {
      _results = indicators;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluación Financiera Inteligente'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de Carga
            _buildUploadSection(),
            
            const SizedBox(height: 20),

            // Botón de Evaluación
            if (_financialData != null && _results == null)
              ElevatedButton.icon(
                onPressed: _runEvaluation,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('GENERAR EVALUACIÓN FINANCIERA'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),

            // Resultados
            if (_results != null)
              _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.upload_file, size: 50, color: Colors.grey),
            const SizedBox(height: 10),
            const Text(
              'Carga tu Estado de Resultados y Balance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            const Text(
              'Formato Excel (.xlsx). El sistema buscará automáticamente filas como "Activo Total", "Ventas", etc.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _pickFile,
                  child: const Text('Subir Excel'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _loadDemoData,
                  child: const Text('Probar Demo'),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(),
              ),
            if (_fileName != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Archivo cargado: $_fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    // Agrupar por categoría
    Map<String, List<FinancialIndicator>> grouped = {};
    for (var ind in _results!) {
      if (!grouped.containsKey(ind.category)) {
        grouped[ind.category] = [];
      }
      grouped[ind.category]!.add(ind);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          'Resultados de la Evaluación',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Chip(
                  label: Text(entry.key.toUpperCase()),
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
              ...entry.value.map((indicator) => _buildIndicatorCard(indicator)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildIndicatorCard(FinancialIndicator indicator) {
    Color statusColor;
    IconData statusIcon;

    switch (indicator.score) {
      case ColorScore.good:
        statusColor = Colors.green;
        statusIcon = Icons.thumb_up;
        break;
      case ColorScore.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber;
        break;
      case ColorScore.bad:
        statusColor = Colors.red;
        statusIcon = Icons.thumb_down;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          indicator.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Valor: ${indicator.value.toStringAsFixed(2)}',
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Interpretación:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(indicator.interpretation),
                const SizedBox(height: 10),
                const Text('Recomendación:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(indicator.recommendation, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
