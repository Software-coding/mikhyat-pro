import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('ar');
final _date = DateFormat('dd/MM/yyyy', 'en');
final _dateTime = DateFormat('dd/MM/yyyy – HH:mm', 'en');

String money(int value) => '${_money.format(value)} ريال';
String shortDate(DateTime value) => _date.format(value);
String shortDateTime(DateTime value) => _dateTime.format(value);
String isoDateTime(DateTime value) => value.toIso8601String();
DateTime parseDbDate(String value) => DateTime.parse(value);
