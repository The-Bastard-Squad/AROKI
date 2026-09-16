import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/aroki_app_state.dart';
import '../theme/aroki_theme.dart';

class ProfileSourcesScreen extends StatefulWidget {
  const ProfileSourcesScreen({super.key});

  @override
  State<ProfileSourcesScreen> createState() => _ProfileSourcesScreenState();
}

class _ProfileSourcesScreenState extends State<ProfileSourcesScreen> {
  late TextEditingController _repoController;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<ArokiAppState>(context, listen: false);
    _repoController = TextEditingController(text: state.currentRepository);
  }

  @override
  void dispose() {
    _repoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ArokiAppState>(context);
    final index = state.repoIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Sources'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ArokiTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ArokiTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: ArokiTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.person_fill,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AROKI User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ArokiTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Aroki 2.0.38 (51) • Android',
                          style: TextStyle(
                            fontSize: 13,
                            color: ArokiTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Verified Repository',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ArokiTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repoController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'kas021/AROKI-Connectors',
                      hintStyle: const TextStyle(color: ArokiTheme.textMuted),
                      filled: true,
                      fillColor: ArokiTheme.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ArokiTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ArokiTheme.cardBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: state.isLoadingRepo
                      ? null
                      : () {
                          state.loadRepository(_repoController.text.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArokiTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: state.isLoadingRepo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (index != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sources in ${index.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ArokiTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ArokiTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, color: ArokiTheme.success, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(color: ArokiTheme.success, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: index.connectors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final connector = index.connectors[i];
                  final isSelected = state.activeConnectorEntry?.id == connector.id;
                  final isRetired = connector.status == 'retired';

                  return GestureDetector(
                    onTap: isRetired ? null : () => state.selectConnector(connector),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? ArokiTheme.accent.withValues(alpha: 0.12) : ArokiTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? ArokiTheme.accent : ArokiTheme.cardBorder,
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  connector.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isRetired ? ArokiTheme.textMuted : ArokiTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isRetired
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : (connector.releaseTrack == 'stable'
                                          ? ArokiTheme.success.withValues(alpha: 0.2)
                                          : ArokiTheme.warning.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  connector.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isRetired
                                        ? Colors.red
                                        : (connector.releaseTrack == 'stable'
                                            ? ArokiTheme.success
                                            : ArokiTheme.warning),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'v${connector.version}',
                                style: const TextStyle(fontSize: 12, color: ArokiTheme.textSecondary),
                              ),
                            ],
                          ),
                          if (connector.releaseNotes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              connector.releaseNotes,
                              style: const TextStyle(fontSize: 12, color: ArokiTheme.textSecondary),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ] else if (state.repoError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Error loading repository: ${state.repoError}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
