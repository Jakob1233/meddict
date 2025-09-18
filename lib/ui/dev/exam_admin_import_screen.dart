import 'package:flutter/cupertino.dart';

import 'package:flutterquiz/data/repositories/exams_repository.dart';
import 'package:flutterquiz/data/seed/exams_seed_sfu.dart';
import 'package:flutterquiz/ui/dev/admin_portal_gate.dart';

class ExamAdminImportScreen extends StatefulWidget {
  const ExamAdminImportScreen({super.key});

  @override
  State<ExamAdminImportScreen> createState() => _ExamAdminImportScreenState();
}

class _ExamAdminImportScreenState extends State<ExamAdminImportScreen> {
  final ExamsRepository _repository = ExamsRepository();
  bool _loading = false;
  String _log = '';

  Future<void> _seed() async {
    setState(() => _loading = true);
    try {
      final inserted = await seedExamsSFU(_repository);
      setState(() => _log = inserted == 0
          ? 'Keine Datensätze vorbereitet. Bitte Seed-Listen füllen.'
          : 'Import abgeschlossen ✔ ($inserted Einträge)');
    } catch (err) {
      setState(() => _log = 'Fehler: $err');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Exameter – Admin Import'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('1) Trage die Prüfungen im Seeder ein (Bachelor/Master, Human/Zahn).'),
              const SizedBox(height: 8),
              const Text('2) Tippe auf "Seed SFU".'),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _loading ? null : _seed,
                child: _loading
                    ? const CupertinoActivityIndicator()
                    : const Text('Seed SFU'),
              ),
              const SizedBox(height: 16),
              Text(
                _log,
                style: const TextStyle(color: CupertinoColors.inactiveGray),
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: AdminPortalGate.close,
                child: const Text('Zur App wechseln'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
