import 'package:equatable/equatable.dart';

class TimeEvent extends Equatable {
  const TimeEvent({required this.tag, required this.dateTime});

  final DateTime dateTime;
  final String tag;

  @override
  List<Object?> get props => [tag, dateTime];
}
