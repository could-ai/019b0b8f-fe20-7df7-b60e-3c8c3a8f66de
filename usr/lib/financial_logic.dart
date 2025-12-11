import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Modelo para almacenar los datos crudos extraídos del Excel
class FinancialData {
  double totalAssets = 0; // Activo Total
  double currentAssets = 0; // Activo Corriente
  double inventory = 0; // Inventarios
  double totalLiabilities = 0; // Pasivo Total
  double currentLiabilities = 0; // Pasivo Corriente
  double totalEquity = 0; // Patrimonio Total
  double netSales = 0; // Ventas Netas
  double costOfGoodsSold = 0; // Costo de Ventas
  double netIncome = 0; // Utilidad Neta
  double operatingIncome = 0; // Utilidad Operativa
  double interestExpense = 0; // Gastos Financieros

  bool get isValid => totalAssets > 0 && netSales > 0;
}

/// Modelo para un indicador financiero calculado
class FinancialIndicator {
  final String category; // Liquidez, Rentabilidad, etc.
  final String name; // Nombre del indicador (ej. Razón Corriente)
  final double value; // Valor calculado
  final String interpretation; // Texto explicativo
  final String recommendation; // Recomendación de acción
  final ColorScore score; // Puntuación (Verde, Amarillo, Rojo)

  FinancialIndicator({
    required this.category,
    required this.name,
    required this.value,
    required this.interpretation,
    required this.recommendation,
    required this.score,
  });
}

enum ColorScore { good, warning, bad, neutral }

class FinancialAnalyzer {
  /// Parsea los bytes del archivo Excel y extrae los datos financieros
  /// Nota: Este es un parser "inteligente" que busca palabras clave en la primera columna
  /// para encontrar los valores, ya que no conocemos la estructura exacta de la celda.
  static Future<FinancialData> parseExcel(Uint8List bytes) async {
    var excel = Excel.decodeBytes(bytes);
    final data = FinancialData();

    // Asumimos que los datos están en la primera hoja
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null) return data;

    for (var row in sheet.rows) {
      if (row.length < 2) continue;
      
      // Normalizamos el texto de la primera columna para buscar coincidencias
      final labelCell = row[0]?.value?.toString().toLowerCase() ?? '';
      final valueCell = row[1]?.value;

      if (valueCell == null) continue;

      // Intentamos convertir el valor a double
      double value = 0;
      if (valueCell is double) {
        value = valueCell;
      } else if (valueCell is int) {
        value = valueCell.toDouble();
      } else {
        final valStr = valueCell.toString().replaceAll(',', '').replaceAll('\$', '');
        value = double.tryParse(valStr) ?? 0;
      }

      // Mapeo de palabras clave a campos del modelo
      if (labelCell.contains('activo total')) data.totalAssets = value;
      else if (labelCell.contains('activo corriente') || labelCell.contains('activos circulantes')) data.currentAssets = value;
      else if (labelCell.contains('inventario')) data.inventory = value;
      else if (labelCell.contains('pasivo total')) data.totalLiabilities = value;
      else if (labelCell.contains('pasivo corriente') || labelCell.contains('pasivos circulantes')) data.currentLiabilities = value;
      else if (labelCell.contains('patrimonio') || labelCell.contains('capital contable')) data.totalEquity = value;
      else if (labelCell.contains('ventas') || labelCell.contains('ingresos operacionales')) data.netSales = value;
      else if (labelCell.contains('costo de venta')) data.costOfGoodsSold = value;
      else if (labelCell.contains('utilidad neta') || labelCell.contains('resultado neto')) data.netIncome = value;
      else if (labelCell.contains('utilidad operativa')) data.operatingIncome = value;
      else if (labelCell.contains('gastos financieros') || labelCell.contains('intereses')) data.interestExpense = value;
    }

    return data;
  }

  /// Genera la lista de indicadores evaluados
  static List<FinancialIndicator> evaluate(FinancialData data) {
    List<FinancialIndicator> indicators = [];

    // --- 1. LIQUIDEZ ---
    
    // Razón Corriente
    double currentRatio = data.currentLiabilities != 0 ? data.currentAssets / data.currentLiabilities : 0;
    indicators.add(FinancialIndicator(
      category: 'Liquidez',
      name: 'Razón Corriente',
      value: currentRatio,
      interpretation: currentRatio > 1 
          ? 'La empresa puede cubrir sus deudas a corto plazo con sus activos corrientes.' 
          : 'La empresa podría tener dificultades para pagar sus obligaciones a corto plazo.',
      recommendation: currentRatio < 1 
          ? 'Renegociar deudas a corto plazo o aumentar el capital de trabajo.' 
          : 'Mantener el nivel actual, pero evitar exceso de liquidez ociosa.',
      score: currentRatio >= 1.5 ? ColorScore.good : (currentRatio >= 1 ? ColorScore.warning : ColorScore.bad),
    ));

    // Prueba Ácida (asumiendo inventarios)
    double quickRatio = data.currentLiabilities != 0 ? (data.currentAssets - data.inventory) / data.currentLiabilities : 0;
    indicators.add(FinancialIndicator(
      category: 'Liquidez',
      name: 'Prueba Ácida',
      value: quickRatio,
      interpretation: quickRatio > 1 
          ? 'La empresa tiene buena capacidad de pago inmediato sin depender de la venta de inventarios.' 
          : 'Alta dependencia del inventario para cubrir obligaciones inmediatas.',
      recommendation: quickRatio < 1 
          ? 'Mejorar la gestión de cobro de cartera o reducir niveles de inventario.' 
          : 'Excelente salud de liquidez inmediata.',
      score: quickRatio >= 1 ? ColorScore.good : (quickRatio >= 0.8 ? ColorScore.warning : ColorScore.bad),
    ));

    // --- 2. ENDEUDAMIENTO ---

    // Nivel de Endeudamiento
    double debtRatio = data.totalAssets != 0 ? data.totalLiabilities / data.totalAssets : 0;
    indicators.add(FinancialIndicator(
      category: 'Endeudamiento',
      name: 'Nivel de Endeudamiento',
      value: debtRatio * 100, // Porcentaje
      interpretation: 'El ${(debtRatio * 100).toStringAsFixed(1)}% de los activos está financiado por terceros.',
      recommendation: debtRatio > 0.7 
          ? 'Riesgo alto. Buscar capitalización o reducir pasivos.' 
          : 'Nivel de deuda manejable.',
      score: debtRatio <= 0.5 ? ColorScore.good : (debtRatio <= 0.7 ? ColorScore.warning : ColorScore.bad),
    ));

    // --- 3. RENTABILIDAD ---

    // Margen Neto
    double netMargin = data.netSales != 0 ? data.netIncome / data.netSales : 0;
    indicators.add(FinancialIndicator(
      category: 'Rentabilidad',
      name: 'Margen Neto',
      value: netMargin * 100,
      interpretation: 'Por cada unidad monetaria vendida, la empresa gana ${(netMargin * 100).toStringAsFixed(1)}%.',
      recommendation: netMargin < 0.05 
          ? 'Revisar estructura de costos y gastos. Evaluar precios de venta.' 
          : 'Buen control de costos y gastos.',
      score: netMargin > 0.10 ? ColorScore.good : (netMargin > 0 ? ColorScore.warning : ColorScore.bad),
    ));

    // ROA (Retorno sobre Activos)
    double roa = data.totalAssets != 0 ? data.netIncome / data.totalAssets : 0;
    indicators.add(FinancialIndicator(
      category: 'Rentabilidad',
      name: 'ROA (Retorno sobre Activos)',
      value: roa * 100,
      interpretation: 'Los activos generan una rentabilidad del ${(roa * 100).toStringAsFixed(1)}%.',
      recommendation: roa < 0.05 
          ? 'Optimizar el uso de activos para generar más ventas.' 
          : 'Los activos están siendo utilizados eficientemente.',
      score: roa > 0.05 ? ColorScore.good : ColorScore.warning,
    ));

    // ROE (Retorno sobre Patrimonio)
    double roe = data.totalEquity != 0 ? data.netIncome / data.totalEquity : 0;
    indicators.add(FinancialIndicator(
      category: 'Rentabilidad',
      name: 'ROE (Retorno sobre Patrimonio)',
      value: roe * 100,
      interpretation: 'Los accionistas obtienen un retorno del ${(roe * 100).toStringAsFixed(1)}% sobre su inversión.',
      recommendation: roe < netMargin 
          ? 'El apalancamiento no está jugando a favor. Revisar deuda.' 
          : 'Buen retorno para los inversionistas.',
      score: roe > 0.10 ? ColorScore.good : ColorScore.warning,
    ));

    // --- 4. ACTIVIDAD (Eficiencia) ---
    
    // Rotación de Activos
    double assetTurnover = data.totalAssets != 0 ? data.netSales / data.totalAssets : 0;
    indicators.add(FinancialIndicator(
      category: 'Actividad',
      name: 'Rotación de Activos',
      value: assetTurnover,
      interpretation: 'La empresa genera ${assetTurnover.toStringAsFixed(2)} veces sus activos en ventas al año.',
      recommendation: assetTurnover < 1 
          ? 'Ventas bajas en relación al tamaño de la empresa. Impulsar ventas.' 
          : 'Buena eficiencia en el uso de activos.',
      score: assetTurnover > 1 ? ColorScore.good : ColorScore.warning,
    ));

    return indicators;
  }
}
