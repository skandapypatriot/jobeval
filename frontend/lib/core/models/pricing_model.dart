import 'package:jobeval/core/models/json_data.dart';

class OperationRateOverride {
  OperationRateOverride({
    required this.operationId,
    required this.rate,
    required this.amount,
    required this.unit,
  });

  factory OperationRateOverride.fromJson(JsonMap json) {
    return OperationRateOverride(
      operationId: JsonData.text(
        json['operation_id'] ?? json['id'] ?? json['name'],
      ),
      rate: JsonData.number(json['rate'] ?? json['rate_per_hour']),
      amount: JsonData.number(json['amount'] ?? json['override_amount']),
      unit: JsonData.text(json['unit'], fallback: 'hour'),
    );
  }

  String operationId;
  double rate;
  double amount;
  String unit;

  Map<String, dynamic> toJson() => {
        'operation_id': operationId,
        if (rate != 0) 'rate': rate,
        if (amount != 0) 'amount': amount,
        'unit': unit,
      };
}

class PricingDraft {
  PricingDraft({
    required this.raw,
    required this.currency,
    required this.quantity,
    required this.materialName,
    required this.density,
    required this.materialPrice,
    required this.materialPriceBasis,
    required this.stockForm,
    required this.finishedX,
    required this.finishedY,
    required this.finishedZ,
    required this.stockX,
    required this.stockY,
    required this.stockZ,
    required this.allowanceX,
    required this.allowanceY,
    required this.allowanceZ,
    required this.rates,
    required this.operationOverrides,
    required this.overheadPercent,
    required this.marginPercent,
    required this.contingencyPercent,
    required this.taxPercent,
  });

  factory PricingDraft.fromJson(JsonMap json) {
    final material = JsonData.firstMap(json, const ['material']);
    final stock = JsonData.firstMap(json, const ['stock', 'stock_envelope']);
    final finished = JsonData.firstMap(json, const [
      'finished_dimensions',
      'finished_dimensions_mm',
      'part_dimensions',
    ]);
    final rates = JsonData.firstMap(json, const ['rates', 'labour_rates']);
    final allowanceValue = json['allowance_per_side_mm'] ??
        json['allowance_mm'] ??
        (json['allowance'] is Map ? json['allowance']['per_side'] : null);
    final allowanceMap = JsonData.firstMap(json, const [
      'allowance',
      'allowance_mm',
    ]);
    final scalarAllowance = JsonData.number(allowanceValue, fallback: 2);
    final x = JsonData.number(allowanceMap['x'], fallback: scalarAllowance);
    final y = JsonData.number(allowanceMap['y'], fallback: scalarAllowance);
    final z = JsonData.number(allowanceMap['z'], fallback: scalarAllowance);
    final overrides = JsonData.firstMaps(json, const [
      'operation_overrides',
      'operation_rate_overrides',
    ]);

    return PricingDraft(
      raw: json,
      currency: JsonData.text(json['currency'], fallback: 'INR'),
      quantity: JsonData.integer(json['quantity'] ?? json['qty'], fallback: 1),
      materialName: JsonData.text(
        material['name'] ?? material['material'] ?? json['material_name'],
        fallback: 'Aluminum 6061',
      ),
      density: JsonData.number(
        material['density_kg_m3'] ??
            material['density'] ??
            json['density_kg_m3'],
        fallback: 2700,
      ),
      materialPrice: JsonData.number(
        material['price'] ??
            material['price_per_kg'] ??
            material['rate'] ??
            json['material_price'],
      ),
      materialPriceBasis: JsonData.text(
        material['price_basis'] ??
            material['basis'] ??
            json['material_price_basis'],
        fallback: 'per_kg',
      ),
      stockForm: JsonData.text(
        stock['form'] ?? stock['shape'] ?? json['stock_form'],
        fallback: 'block',
      ),
      finishedX: JsonData.number(
        finished['x'] ?? finished['length'] ?? json['finished_x'],
      ),
      finishedY: JsonData.number(
        finished['y'] ?? finished['width'] ?? json['finished_y'],
      ),
      finishedZ: JsonData.number(
        finished['z'] ?? finished['height'] ?? json['finished_z'],
      ),
      stockX: JsonData.number(
        stock['x'] ?? stock['length'] ?? json['stock_x'],
      ),
      stockY: JsonData.number(
        stock['y'] ?? stock['width'] ?? json['stock_y'],
      ),
      stockZ: JsonData.number(
        stock['z'] ?? stock['height'] ?? json['stock_z'],
      ),
      allowanceX: x,
      allowanceY: y,
      allowanceZ: z,
      rates: {
        'machine': JsonData.number(
          rates['machine'] ??
              rates['machine_rate'] ??
              rates['machine_rate_per_hour'],
        ),
        'labour': JsonData.number(
          rates['labour'] ??
              rates['labour_rate'] ??
              rates['labour_rate_per_hour'],
        ),
        'setup': JsonData.number(
          rates['setup'] ?? rates['setup_rate'] ?? rates['setup_rate_per_hour'],
        ),
        'tool': JsonData.number(
          rates['tool'] ?? rates['tool_rate'] ?? rates['tooling_rate'],
        ),
        'program': JsonData.number(
          rates['program'] ??
              rates['programming'] ??
              rates['program_rate'] ??
              rates['programming_rate'],
        ),
        'inspection': JsonData.number(
          rates['inspection'] ?? rates['inspection_rate'],
        ),
        'finish': JsonData.number(rates['finish'] ?? rates['finish_rate']),
        'deburr': JsonData.number(rates['deburr'] ?? rates['deburr_rate']),
      },
      operationOverrides:
          overrides.map(OperationRateOverride.fromJson).toList(),
      overheadPercent: JsonData.number(
        json['overhead_percent'] ?? json['overhead_pct'],
      ),
      marginPercent: JsonData.number(
        json['margin_percent'] ?? json['margin_pct'],
      ),
      contingencyPercent: JsonData.number(
        json['contingency_percent'] ?? json['contingency_pct'],
      ),
      taxPercent: JsonData.number(json['tax_percent'] ?? json['tax_pct']),
    );
  }

  final JsonMap raw;
  String currency;
  int quantity;
  String materialName;
  double density;
  double materialPrice;
  String materialPriceBasis;
  String stockForm;
  double finishedX;
  double finishedY;
  double finishedZ;
  double stockX;
  double stockY;
  double stockZ;
  double allowanceX;
  double allowanceY;
  double allowanceZ;
  Map<String, double> rates;
  List<OperationRateOverride> operationOverrides;
  double overheadPercent;
  double marginPercent;
  double contingencyPercent;
  double taxPercent;

  JsonMap toJson() => {
        ...raw,
        'currency': currency,
        'quantity': quantity,
        'material': {
          'name': materialName,
          'density_kg_m3': density,
          'price': materialPrice,
          'price_basis': materialPriceBasis,
        },
        'stock': {
          'form': stockForm,
          'x': stockX,
          'y': stockY,
          'z': stockZ,
        },
        'finished_dimensions_mm': {
          'x': finishedX,
          'y': finishedY,
          'z': finishedZ,
        },
        'allowance_mm': {
          'x': allowanceX,
          'y': allowanceY,
          'z': allowanceZ,
        },
        'rates': {
          'machine_per_hour': rates['machine'] ?? 0,
          'labour_per_hour': rates['labour'] ?? 0,
          'setup_per_hour': rates['setup'] ?? 0,
          'tool_per_hour': rates['tool'] ?? 0,
          'program_per_hour': rates['program'] ?? 0,
          'inspection_per_hour': rates['inspection'] ?? 0,
          'finish_per_hour': rates['finish'] ?? 0,
          'deburr_per_hour': rates['deburr'] ?? 0,
        },
        'operation_overrides':
            operationOverrides.map((override) => override.toJson()).toList(),
        'overhead_percent': overheadPercent,
        'margin_percent': marginPercent,
        'contingency_percent': contingencyPercent,
        'tax_percent': taxPercent,
      };

  static PricingDraft defaults() {
    return PricingDraft.fromJson(const {
      'currency': 'INR',
      'quantity': 1,
      'material': {
        'name': 'Aluminum 6061',
        'density_kg_m3': 2700,
        'price': 420,
        'price_basis': 'per_kg',
      },
      'stock': {'form': 'block'},
      'rates': <String, dynamic>{},
    });
  }
}
