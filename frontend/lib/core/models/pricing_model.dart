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
    final materialValue = json['material'];
    final materialMap =
        materialValue is Map ? materialValue : <String, dynamic>{};
    final stock = JsonData.firstMap(json, const ['stock', 'stock_envelope']);
    final finished = JsonData.firstMap(json, const [
      'finished_dimensions',
      'finished_dimensions_mm',
      'part_dimensions',
      'finished_bbox',
    ]);
    final rates = JsonData.firstMap(json, const ['rates', 'labour_rates']);
    final allowanceValue = json['allowance_per_side_mm'] ??
        json['allowance_mm'] ??
        (json['allowance'] is Map ? json['allowance']['per_side'] : null);
    final allowanceMap = JsonData.firstMap(json, const [
      'allowance',
      'allowances',
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
    final finishedSize = JsonData.firstMap(finished, const ['size']);

    return PricingDraft(
      raw: json,
      currency: JsonData.text(json['currency'], fallback: 'INR'),
      quantity: JsonData.integer(json['quantity'] ?? json['qty'], fallback: 1),
      materialName: JsonData.text(
        materialValue is String
            ? materialValue
            : materialMap['name'] ??
                materialMap['material'] ??
                json['material_name'],
        fallback: 'Aluminum 6061',
      ),
      density: JsonData.number(
        materialMap['density_kg_m3'] ??
            materialMap['density'] ??
            json['density_kg_m3'],
        fallback: 2700,
      ),
      materialPrice: JsonData.number(
        materialMap['price'] ??
            materialMap['price_per_kg'] ??
            materialMap['rate'] ??
            json['price'] ??
            json['material_price'],
      ),
      materialPriceBasis: _mapPriceBasisFromBackend(
        materialMap['price_basis'] ??
            materialMap['basis'] ??
            json['price_basis'] ??
            json['material_price_basis'],
      ),
      stockForm: JsonData.text(
        stock['form'] ?? stock['shape'] ?? json['stock_shape'],
        fallback: 'block',
      ),
      finishedX: JsonData.number(
        finishedSize['x'] ?? finishedSize['length'] ?? json['finished_x'],
      ),
      finishedY: JsonData.number(
        finishedSize['y'] ?? finishedSize['width'] ?? json['finished_y'],
      ),
      finishedZ: JsonData.number(
        finishedSize['z'] ?? finishedSize['height'] ?? json['finished_z'],
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
        'minimum_quantity': quantity,
        'material': materialName,
        'density_kg_m3': density,
        'price': materialPrice,
        'price_basis': _mapPriceBasis(materialPriceBasis),
        'stock_shape': _mapStockForm(stockForm),
        'stock_dimensions': {'x': stockX, 'y': stockY, 'z': stockZ},
        'allowances': {'x': allowanceX, 'y': allowanceY, 'z': allowanceZ},
        'finished_bbox': {
          'size': {'x': finishedX, 'y': finishedY, 'z': finishedZ},
          'bbox': {
            'min': {'x': 0.0, 'y': 0.0, 'z': 0.0},
            'max': {'x': finishedX, 'y': finishedY, 'z': finishedZ},
          },
        },
        'rates': {
          'machine': rates['machine'] ?? 0,
          'labor': rates['labour'] ?? 0,
          'setup': rates['setup'] ?? 0,
          'tool_change': rates['tool'] ?? 0,
          'programming': rates['program'] ?? 0,
          'inspection': rates['inspection'] ?? 0,
          'finishing': rates['finish'] ?? 0,
          'deburr': rates['deburr'] ?? 0,
        },
        'operation_rates': {
          for (final override in operationOverrides
              .where((o) => o.operationId.trim().isNotEmpty && o.rate != 0))
            override.operationId: override.rate,
        },
        'fixed_overrides': {
          for (final override in operationOverrides
              .where((o) => o.operationId.trim().isNotEmpty && o.amount != 0))
            override.operationId: override.amount,
        },
        'overhead_percent': overheadPercent,
        'margin_percent': marginPercent,
        'contingency_percent': contingencyPercent,
        'tax_percent': taxPercent,
        'notes': const [],
      };

  static String _mapPriceBasis(String basis) {
    switch (basis) {
      case 'per_kg':
        return 'kg';
      case 'per_piece':
        return 'piece';
      case 'per_volume':
        return 'volume_cm3';
      case 'per_area':
        return 'volume_m3';
      default:
        return 'sheet';
    }
  }

  static String _mapPriceBasisFromBackend(String? basis) {
    switch (basis) {
      case 'kg':
        return 'per_kg';
      case 'piece':
        return 'per_piece';
      case 'volume_cm3':
        return 'per_volume';
      case 'volume_m3':
        return 'per_area';
      case 'sheet':
        return 'per_area';
      default:
        return 'per_kg';
    }
  }

  static String _mapStockForm(String form) {
    switch (form.toLowerCase()) {
      case 'block':
      case 'rectangular':
        return 'rectangular';
      case 'round':
      case 'round bar':
        return 'round';
      default:
        return 'rectangular';
    }
  }

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
