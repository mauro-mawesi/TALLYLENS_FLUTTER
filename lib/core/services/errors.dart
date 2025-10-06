class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);
  @override
  String toString() => 'UnauthorizedException: $message';
}

class DuplicateReceiptException implements Exception {
  final String message;
  final String? duplicateType;
  final Map<String, dynamic>? existingReceipt;
  DuplicateReceiptException({
    this.message = 'Duplicate receipt detected',
    this.duplicateType,
    this.existingReceipt,
  });
  @override
  String toString() => 'DuplicateReceiptException: $message';
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Not found']);
  @override
  String toString() => 'NotFoundException: $message';
}
