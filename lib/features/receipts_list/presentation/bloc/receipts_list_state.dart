import 'package:equatable/equatable.dart';

// La clase base abstracta para todos los estados.
// Usamos Equatable para poder comparar instancias de estados fácilmente.
abstract class ReceiptsListState extends Equatable {
  const ReceiptsListState();

  @override
  List<Object> get props => [];
}

// Estado inicial, cuando no ha ocurrido nada.
class ReceiptsListInitial extends ReceiptsListState {}

// Estado mientras se cargan los recibos desde la API.
class ReceiptsListLoading extends ReceiptsListState {}

// Estado cuando los recibos se han cargado con éxito.
class ReceiptsListLoaded extends ReceiptsListState {
  final List<dynamic> receipts;
  final bool hasMore;
  final bool loadingMore;
  final int page;
  final int pageSize;

  const ReceiptsListLoaded({
    required this.receipts,
    required this.hasMore,
    required this.loadingMore,
    required this.page,
    required this.pageSize,
  });

  ReceiptsListLoaded copyWith({
    List<dynamic>? receipts,
    bool? hasMore,
    bool? loadingMore,
    int? page,
    int? pageSize,
  }) => ReceiptsListLoaded(
        receipts: receipts ?? this.receipts,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  @override
  List<Object> get props => [receipts, hasMore, loadingMore, page, pageSize];
}

// Estado cuando ha ocurrido un error al cargar los recibos.
class ReceiptsListError extends ReceiptsListState {
  final String message;

  const ReceiptsListError(this.message);

  @override
  List<Object> get props => [message];
}
