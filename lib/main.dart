// flutter.dart  (use as lib/main.dart, with backend.dart in the same folder)
//
// pubspec.yaml needs:
//   shared_preferences: ^2.5.6
//   google_fonts: (run `flutter pub add google_fonts`)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'backend.dart';

void main() => runApp(const SpendApp());

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

class Pal {
  static const ground = Color(0xFFE8EDF3); // cool grey-blue page
  static const surface = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0E1B4D); // all text and primary actions
  static const muted = Color(0xFF5B6684);
  static const line = Color(0xFFD3DBE6);
  static const mint = Color(0xFF7FD8A9); // plenty left
  static const amber = Color(0xFFF6C453); // running low
  static const coral = Color(0xFFFF7A66); // over budget
  static const coralText = Color(0xFFC93C28);
}

/// Headlines and big numbers.
TextStyle display(double size,
        {FontWeight weight = FontWeight.w700, Color color = Pal.navy}) =>
    GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -size * 0.03,
      height: 1.05,
    );

/// Everything else. `figures: true` keeps digits the same width.
TextStyle body(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = Pal.navy,
        bool figures = false}) =>
    GoogleFonts.instrumentSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
    );

Color catColor(ExpenseCategory c) => switch (c) {
      ExpenseCategory.food => const Color(0xFFE8943A),
      ExpenseCategory.transport => const Color(0xFF3D8BFD),
      ExpenseCategory.shopping => const Color(0xFFE0568C),
      ExpenseCategory.bills => const Color(0xFF3BB08F),
      ExpenseCategory.health => const Color(0xFF8E6CEF),
      ExpenseCategory.fun => const Color(0xFFD9A81E),
      ExpenseCategory.other => const Color(0xFF8B97A8),
    };

IconData catIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.food => Icons.restaurant_rounded,
      ExpenseCategory.transport => Icons.directions_bus_rounded,
      ExpenseCategory.shopping => Icons.shopping_bag_outlined,
      ExpenseCategory.bills => Icons.receipt_long_outlined,
      ExpenseCategory.health => Icons.favorite_border_rounded,
      ExpenseCategory.fun => Icons.local_activity_outlined,
      ExpenseCategory.other => Icons.more_horiz_rounded,
    };

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
  'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = (today.difference(d).inHours / 24).round();
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}';
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class SpendApp extends StatelessWidget {
  const SpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Pal.ground,
        colorScheme: ColorScheme.fromSeed(seedColor: Pal.navy).copyWith(
          primary: Pal.navy,
          surface: Pal.ground,
        ),
        textTheme: GoogleFonts.instrumentSansTextTheme(),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Pal.navy,
          contentTextStyle: body(14, color: Colors.white),
          behavior: SnackBarBehavior.floating,
          actionTextColor: Pal.mint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final b = ExpenseBackend();

  @override
  void initState() {
    super.initState();
    b.load();
  }

  @override
  void dispose() {
    b.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pal.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AddExpenseSheet(
        onSave: (title, amount, category, date) => b.addExpense(
          title: title,
          amount: amount,
          category: category,
          date: date,
        ),
      ),
    );
  }

  void _editBudget() {
    final ctrl = TextEditingController(text: b.budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Monthly budget', style: display(22)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: body(18, weight: FontWeight.w600),
          decoration: InputDecoration(prefixText: currencySymbol),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: body(15, color: Pal.muted)),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(ctrl.text);
              if (value != null) b.setBudget(value);
              Navigator.pop(ctx);
            },
            child: const Text('Save budget'),
          ),
        ],
      ),
    );
  }

  void _onDismissed(Expense e) {
    b.deleteExpense(e.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted ${e.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => b.restoreExpense(e),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddSheet,
            backgroundColor: Pal.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            highlightElevation: 0,
            shape: const StadiumBorder(),
            icon: const Icon(Icons.add_rounded),
            label: Text('Add expense',
                style: body(15, weight: FontWeight.w600, color: Colors.white)),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    _monthHeader(),
                    const SizedBox(height: 16),
                    _BudgetPanel(b: b, onEdit: _editBudget),
                    if (b.monthExpenses.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _Breakdown(b: b),
                    ],
                    const SizedBox(height: 40),
                    _WeekChart(b: b),
                    const SizedBox(height: 40),
                    ..._transactions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        Expanded(
          child: Text('${_months[b.month.month - 1]} ${b.month.year}',
              style: display(26)),
        ),
        IconButton(
          onPressed: b.previousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
          color: Pal.navy,
          tooltip: 'Previous month',
        ),
        IconButton(
          onPressed: b.canGoNext ? b.nextMonth : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: Pal.navy,
          disabledColor: Pal.line,
          tooltip: 'Next month',
        ),
      ],
    );
  }

  List<Widget> _transactions() {
    final monthName = _months[b.month.month - 1];
    if (b.monthExpenses.isEmpty) {
      return [
        _SectionTitle('Transactions'),
        Text('No expenses in $monthName yet.', style: display(20)),
        const SizedBox(height: 6),
        Text('Tap Add expense to log the first one.',
            style: body(15, color: Pal.muted)),
      ];
    }

    final widgets = <Widget>[_SectionTitle('Transactions')];
    b.groupedByDay.forEach((day, items) {
      final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(dayLabel(day),
                  style: body(13, weight: FontWeight.w600, color: Pal.muted)),
            ),
            Text(formatMoney(dayTotal),
                style: body(13,
                    weight: FontWeight.w600, color: Pal.muted, figures: true)),
          ],
        ),
      ));
      for (var i = 0; i < items.length; i++) {
        final e = items[i];
        widgets.add(Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _onDismissed(e),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Pal.coral,
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          child: _ExpenseRow(expense: e, showLine: i != items.length - 1),
        ));
      }
    });
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Hero: the panel drains as you spend
// ---------------------------------------------------------------------------

class _BudgetPanel extends StatelessWidget {
  final ExpenseBackend b;
  final VoidCallback onEdit;
  const _BudgetPanel({required this.b, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final over = b.isOverBudget;
    final fraction = over ? 1.0 : b.remainingFraction;
    final fill = over
        ? Pal.coral
        : (b.remainingFraction < 0.25 ? Pal.amber : Pal.mint);

    final label = over ? 'Over budget by' : 'Left this month';
    final bigNumber = over ? -b.remaining : b.remaining;
    final days = b.daysLeft;
    final String note;
    if (over) {
      note = days > 0
          ? 'Nothing left for the next $days ${days == 1 ? 'day' : 'days'}.'
          : 'This month ended over budget.';
    } else {
      note = days > 0
          ? '${formatMoney(b.dailyAllowance, cents: false)} a day for the next '
              '$days ${days == 1 ? 'day' : 'days'}'
          : 'This month ended under budget.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Pal.surface)),
            Positioned.fill(
              child: AnimatedFractionallySizedBox(
                alignment: Alignment.bottomCenter,
                widthFactor: 1,
                heightFactor: fraction,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  color: fill,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: body(15, weight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatMoney(bigNumber, cents: false),
                        style: display(76)),
                  ),
                  const SizedBox(height: 10),
                  Text(note, style: body(15)),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Spent ${formatMoney(b.monthTotal)} of '
                          '${formatMoney(b.budget, cents: false)}',
                          style: body(14, weight: FontWeight.w600, figures: true),
                        ),
                      ),
                      GestureDetector(
                        onTap: onEdit,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Change budget',
                            style: body(14, weight: FontWeight.w600).copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(text, style: display(21))),
          if (trailing != null)
            Text(trailing!, style: body(13, color: Pal.muted, figures: true)),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final ExpenseBackend b;
  const _Breakdown({required this.b});

  @override
  Widget build(BuildContext context) {
    final totals = b.categoryTotals;
    final top = totals.first.value;
    final all = b.monthTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Where it went'),
        for (final entry in totals)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.key.label,
                          style: body(15, weight: FontWeight.w500)),
                    ),
                    Text('${(entry.value / all * 100).round()}%',
                        style: body(13, color: Pal.muted, figures: true)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 84,
                      child: Text(
                        formatMoney(entry.value),
                        textAlign: TextAlign.right,
                        style: body(15, weight: FontWeight.w600, figures: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: ColoredBox(color: Pal.line)),
                        Positioned.fill(
                          child: AnimatedFractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: entry.value / top,
                            heightFactor: 1,
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            child: ColoredBox(color: catColor(entry.key)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  final ExpenseBackend b;
  const _WeekChart({required this.b});

  @override
  Widget build(BuildContext context) {
    final days = b.last7Days;
    double maxValue = 0;
    double sum = 0;
    for (final d in days) {
      sum += d.value;
      if (d.value > maxValue) maxValue = d.value;
    }
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Last 7 days',
          trailing: 'Avg ${formatMoney(sum / 7, cents: false)} a day',
        ),
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: maxValue == 0
                            ? 4
                            : (days[i].value / maxValue * 76).clamp(4.0, 76.0),
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: i == days.length - 1
                              ? Pal.navy
                              : const Color(0xFFC3CEDD),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        letters[days[i].key.weekday - 1],
                        style: body(
                          13,
                          weight: i == days.length - 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == days.length - 1 ? Pal.navy : Pal.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final bool showLine;
  const _ExpenseRow({required this.expense, required this.showLine});

  @override
  Widget build(BuildContext context) {
    final color = catColor(expense.category);
    return Container(
      color: Pal.ground, // keeps the swipe background hidden until dragging
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: showLine
              ? const Border(bottom: BorderSide(color: Pal.line))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(catIcon(expense.category), size: 21, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(16, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(expense.category.label,
                      style: body(13, color: Pal.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(formatMoney(expense.amount),
                style: body(16, weight: FontWeight.w600, figures: true)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add expense sheet
// ---------------------------------------------------------------------------

class AddExpenseSheet extends StatefulWidget {
  final void Function(
          String title, double amount, ExpenseCategory category, DateTime date)
      onSave;
  const AddExpenseSheet({super.key, required this.onSave});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    final title = _titleCtrl.text.trim().isEmpty
        ? _category.label
        : _titleCtrl.text.trim();

    // Today keeps the current time so same-day entries stay in order.
    final now = DateTime.now();
    final date = _isToday
        ? now
        : DateTime(_date.year, _date.month, _date.day, 12);

    widget.onSave(title, amount, _category, date);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Pal.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('New expense', style: display(21)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(currencySymbol, style: display(48, color: Pal.muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    cursorColor: Pal.navy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: display(48),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                      hintStyle: display(48, color: Pal.line),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: body(13, color: Pal.coralText)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              cursorColor: Pal.navy,
              textCapitalization: TextCapitalization.sentences,
              style: body(17),
              decoration: InputDecoration(
                hintText: 'What was it for?',
                hintStyle: body(17, color: Pal.muted),
                enabledBorder:
                    const UnderlineInputBorder(borderSide: BorderSide(color: Pal.line)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Pal.navy, width: 2)),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.values) _chip(c),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickDate,
              style: TextButton.styleFrom(
                foregroundColor: Pal.navy,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                _isToday ? 'Today' : dayLabel(_date),
                style: body(15, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: Pal.navy,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Add expense',
                  style: body(16, weight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(ExpenseCategory c) {
    final selected = c == _category;
    return GestureDetector(
      onTap: () => setState(() => _category = c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Pal.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Pal.navy : Pal.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(catIcon(c),
                size: 16, color: selected ? Colors.white : catColor(c)),
            const SizedBox(width: 6),
            Text(
              c.label,
              style: body(14,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : Pal.navy),
            ),
          ],
        ),
      ),
    );
  }
}