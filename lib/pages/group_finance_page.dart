import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/group_drawer.dart';

class GroupFinancePage extends StatefulWidget {
  final String groupId;
  const GroupFinancePage({super.key, required this.groupId});

  @override
  State<GroupFinancePage> createState() => _GroupFinancePageState();
}

class _GroupFinancePageState extends State<GroupFinancePage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isAdmin(Map<String, dynamic> data, String uid) {
    final admins = List<String>.from(data['admins'] ?? []);
    return admins.contains(uid);
  }

  Future<void> _showAddTxDialog(bool isAdmin) async {
    if (!isAdmin) return;

    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String type = 'income';
    DateTime selectedDate = DateTime.now();
    bool saving = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              final amt = double.tryParse(amountC.text.trim());
              if (amt == null || amt <= 0) {
                setLocal(() => err = 'Nominal tidak valid.');
                return;
              }

              setLocal(() {
                saving = true;
                err = null;
              });

              try {
                await _db
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('finance')
                    .add({
                  'type': type,
                  'amount': amt,
                  'note': noteC.text.trim(),
                  'date': Timestamp.fromDate(selectedDate),
                  'createdBy': _auth.currentUser?.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // ✅ FIX use_build_context_synchronously
                if (!mounted || !dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
              } catch (e) {
                setLocal(() {
                  err = 'Gagal menambah catatan: $e';
                  saving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Tambah Catatan Keuangan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    // ✅ FIX deprecated value -> initialValue
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                          value: 'income', child: Text('Pemasukan')),
                      DropdownMenuItem(
                          value: 'expense', child: Text('Pengeluaran')),
                    ],
                    onChanged: (v) => setLocal(() => type = v ?? 'income'),
                    decoration: const InputDecoration(
                      labelText: 'Jenis',
                      prefixIcon: Icon(Icons.swap_vert_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: selectedDate,
                      );
                      if (d != null) {
                        setLocal(() => selectedDate = d);
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: SiKawanTheme.error)),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTx(String txId, bool isAdmin) async {
    if (!isAdmin) return;

    await _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('finance')
        .doc(txId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      drawer: GroupDrawer(groupId: widget.groupId, current: 'keuangan'),
      appBar: AppBar(
        title: const Text('Keuangan'),
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('groups').doc(widget.groupId).snapshots(),
          builder: (context, groupSnap) {
            if (!groupSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final gdata = groupSnap.data!.data() ?? {};
            final isAdmin =
                myUid != null ? _isAdmin(gdata, myUid) : false;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Catatan Keuangan',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      if (isAdmin)
                        ElevatedButton.icon(
                          onPressed: () => _showAddTxDialog(isAdmin),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah'),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('finance')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            'Belum ada catatan keuangan.',
                            style: t.bodyMedium?.copyWith(
                              color: SiKawanTheme.textSecondary,
                            ),
                          ),
                        );
                      }

                      double totalIncome = 0;
                      double totalExpense = 0;

                      for (final d in docs) {
                        final m = d.data();
                        final amt = (m['amount'] ?? 0).toDouble();
                        if (m['type'] == 'income') {
                          totalIncome += amt;
                        } else {
                          totalExpense += amt;
                        }
                      }

                      final saldo = totalIncome - totalExpense;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: SiKawanTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: SiKawanTheme.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _SummaryTile(
                                    label: 'Pemasukan',
                                    value: totalIncome,
                                    // ✅ FIX success -> secondary
                                    color: SiKawanTheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryTile(
                                    label: 'Pengeluaran',
                                    value: totalExpense,
                                    color: SiKawanTheme.error,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryTile(
                                    label: 'Saldo',
                                    value: saldo,
                                    color: SiKawanTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          ...docs.map((d) {
                            final m = d.data();
                            final type = (m['type'] ?? 'income') as String;
                            final amt = (m['amount'] ?? 0).toDouble();
                            final note = (m['note'] ?? '') as String;
                            final date =
                                (m['date'] as Timestamp?)?.toDate();

                            final isIncome = type == 'income';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: SiKawanTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: SiKawanTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIncome
                                        ? SiKawanTheme.secondary
                                        : SiKawanTheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isIncome
                                              ? 'Pemasukan'
                                              : 'Pengeluaran',
                                          style: t.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (note.isNotEmpty)
                                          Text(
                                            note,
                                            style: t.bodySmall?.copyWith(
                                              color: SiKawanTheme
                                                  .textSecondary,
                                            ),
                                          ),
                                        if (date != null)
                                          Text(
                                            '${date.day}/${date.month}/${date.year}',
                                            style: t.bodySmall?.copyWith(
                                              color: SiKawanTheme
                                                  .textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    (isIncome ? '+ ' : '- ') +
                                        amt.toStringAsFixed(0),
                                    style: t.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isIncome
                                          ? SiKawanTheme.secondary
                                          : SiKawanTheme.error,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      onPressed: () =>
                                          _deleteTx(d.id, isAdmin),
                                      icon: const Icon(Icons.delete_outline),
                                      color: SiKawanTheme.error,
                                    )
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: t.bodySmall?.copyWith(
                color: SiKawanTheme.textSecondary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(0),
            style: t.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
