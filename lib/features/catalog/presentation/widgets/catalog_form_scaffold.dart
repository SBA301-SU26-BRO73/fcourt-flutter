import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/wp3b_widgets.dart';

/// Shell of the catalog forms in the WP3b look (same rhythm as the login
/// form): round back button, 26/700 heading with a grey subtitle, content in
/// soft groups, and a floating bar with the pill submit button.
class CatalogFormScaffold extends StatelessWidget {
  const CatalogFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
    required this.child,
  });
  final String title;
  final String subtitle;
  final String submitLabel;
  final bool submitting;
  final VoidCallback onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CircleIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(submitLabel),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: text.headlineSmall?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft rounded group for switches ("Đang hoạt động", "Gói phổ biến").
class CatalogSwitchGroup extends StatelessWidget {
  const CatalogSwitchGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(children: children),
      ),
    ),
  );
}
