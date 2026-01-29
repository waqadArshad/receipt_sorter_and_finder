class FilterCriteria {
  final List<String>? documentTypes; // e.g., 'pos_receipt', 'digital_receipt', 'invoice'
  final List<String>? merchants;     // e.g., 'Starbucks', 'Uber'
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;

  FilterCriteria({
    this.documentTypes,
    this.merchants,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
  });

  bool get isEmpty => 
    (documentTypes == null || documentTypes!.isEmpty) &&
    (merchants == null || merchants!.isEmpty) &&
    startDate == null &&
    endDate == null &&
    minAmount == null &&
    maxAmount == null;
}
