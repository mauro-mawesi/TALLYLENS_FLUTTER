import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// La clase base abstracta para todos los eventos.
abstract class ReceiptsListEvent extends Equatable {
  const ReceiptsListEvent();

  @override
  List<Object> get props => [];
}

// Evento que se dispara para solicitar la carga de los recibos.
// Puede incluir filtros opcionales.
class FetchReceipts extends ReceiptsListEvent {
  final String? category;
  final String? merchant;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;
  const FetchReceipts({this.category, this.merchant, this.dateRange, this.amountRange});

  @override
  List<Object> get props => [
    category ?? '',
    merchant ?? '',
    dateRange?.start.millisecondsSinceEpoch ?? 0,
    dateRange?.end.millisecondsSinceEpoch ?? 0,
    amountRange?.start ?? 0,
    amountRange?.end ?? 0,
  ];
}

class LoadMoreReceipts extends ReceiptsListEvent {}
