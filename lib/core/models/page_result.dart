class PageResult {
  final List<dynamic> items;
  final bool hasMore;
  final int page;
  final int pageSize;
  final int? total;
  const PageResult({required this.items, required this.hasMore, required this.page, required this.pageSize, this.total});
}

