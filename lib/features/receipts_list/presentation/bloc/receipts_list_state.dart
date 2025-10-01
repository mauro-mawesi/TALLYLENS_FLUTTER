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

  const ReceiptsListLoaded(this.receipts);

  @override
  List<Object> get props => [receipts];
}

// Estado cuando ha ocurrido un error al cargar los recibos.
class ReceiptsListError extends ReceiptsListState {
  final String message;

  const ReceiptsListError(this.message);

  @override
  List<Object> get props => [message];
}
