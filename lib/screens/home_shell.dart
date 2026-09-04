import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/piece.dart';
import '../models/withdrawal.dart';
import '../providers/app_store.dart';
import '../widgets/customer_form_sheet.dart';
import '../widgets/piece_form_sheet.dart';
import '../widgets/withdrawal_form_sheet.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'pieces_screen.dart';
import 'withdrawals_screen.dart';
import 'reports_screen.dart';
import 'more_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _screens = const [
    DashboardScreen(),
    CustomersScreen(),
    PiecesScreen(),
    WithdrawalsScreen(),
    ReportsScreen(),
    MoreScreen(),
  ];

  Future<void> _newPiece([Piece? piece]) async {
    final store = context.read<AppStore>();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .96,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: PieceFormSheet(
            piece: piece,
            customers: store.customers,
            onSave: (customerId, description, quantity, basePrice, mods) => store.savePiece(
              id: piece?.id,
              customerId: customerId,
              description: description,
              quantity: quantity,
              basePrice: basePrice,
              modifications: mods,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newCustomer([Customer? customer]) async {
    final store = context.read<AppStore>();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .96,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: CustomerFormSheet(
            customer: customer,
            onSave: (
              name,
              phone,
              notes,
              shoulder,
              chest,
              waist,
              hips,
              sleeveLength,
              garmentLength,
            ) =>
                store.saveCustomer(
              id: customer?.id,
              name: name,
              phone: phone,
              notes: notes,
              shoulder: shoulder,
              chest: chest,
              waist: waist,
              hips: hips,
              sleeveLength: sleeveLength,
              garmentLength: garmentLength,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newWithdrawal([Withdrawal? withdrawal]) async {
    final store = context.read<AppStore>();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WithdrawalFormSheet(
        withdrawal: withdrawal,
        onSave: (amount, note) => store.saveWithdrawal(id: withdrawal?.id, amount: amount, note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _index <= 3
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_index == 1) {
                  _newCustomer();
                } else if (_index == 3) {
                  _newWithdrawal();
                } else {
                  _newPiece();
                }
              },
              icon: Icon(
                _index == 1
                    ? Icons.person_add_alt_1_rounded
                    : _index == 3
                        ? Icons.payments_rounded
                        : Icons.add_rounded,
              ),
              label: Text(
                _index == 1
                    ? 'عميل جديد'
                    : _index == 3
                        ? 'سحب جديد'
                        : 'إضافة عمل',
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.content_cut_outlined), selectedIcon: Icon(Icons.content_cut_rounded), label: 'الأعمال'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'السحبيات'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment_rounded), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}
