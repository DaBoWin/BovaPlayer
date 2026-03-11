import 'package:flutter/material.dart';

import '../../../../core/theme/design_system.dart';

const Color authWorkspaceAccent = Color(0xFFE11D48);
const Color authWorkspaceAccentSoft = Color(0xFFFCE7F3);
const Color authWorkspaceCanvas = Color(0xFFF1F3F6);
const Color authWorkspacePanel = Colors.white;
const Color authWorkspacePanelBorder = Color(0xFFE7EAF0);

class AuthWorkspaceScaffold extends StatelessWidget {
  const AuthWorkspaceScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.heroGraphic,
    this.facts = const [],
    this.showBackButton = true,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? heroGraphic;
  final List<AuthWorkspaceFact> facts;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isMobile = DesignSystem.isMobile(context);

    return Scaffold(
      backgroundColor: authWorkspaceCanvas,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: DesignSystem.neutral900,
                  size: 20,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            )
          : null,
      body: SafeArea(
        top: !showBackButton,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? DesignSystem.space4 : DesignSystem.space6,
              showBackButton ? DesignSystem.space2 : DesignSystem.space6,
              isMobile ? DesignSystem.space4 : DesignSystem.space6,
              DesignSystem.space8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroPanel(
                          eyebrow: eyebrow,
                          title: title,
                          subtitle: subtitle,
                          icon: icon,
                          heroGraphic: heroGraphic,
                          facts: facts,
                        ),
                        const SizedBox(height: DesignSystem.space5),
                        child,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _HeroPanel(
                            eyebrow: eyebrow,
                            title: title,
                            subtitle: subtitle,
                            icon: icon,
                            heroGraphic: heroGraphic,
                            facts: facts,
                          ),
                        ),
                        const SizedBox(width: DesignSystem.space5),
                        Expanded(flex: 9, child: child),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthWorkspacePanel extends StatelessWidget {
  const AuthWorkspacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DesignSystem.space6),
    this.backgroundColor = authWorkspacePanel,
    this.borderColor = authWorkspacePanelBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: borderColor),
        boxShadow: DesignSystem.shadowSm,
      ),
      child: child,
    );
  }
}

class AuthWorkspaceFact {
  const AuthWorkspaceFact({required this.label, required this.value});

  final String label;
  final String value;
}

class AuthWorkspaceFooterLink extends StatelessWidget {
  const AuthWorkspaceFooterLink({
    super.key,
    required this.label,
    required this.action,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String action;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            color: DesignSystem.neutral600,
          ),
        ),
        TextButton(
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignSystem.space2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: authWorkspaceAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.heroGraphic,
    required this.facts,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? heroGraphic;
  final List<AuthWorkspaceFact> facts;

  @override
  Widget build(BuildContext context) {
    final compactHero = eyebrow.isEmpty &&
        subtitle.isEmpty &&
        facts.isEmpty &&
        heroGraphic != null;

    return AuthWorkspacePanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              authWorkspaceAccentSoft.withValues(alpha: 0.58),
              const Color(0xFFFFFBEB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSystem.space3,
                    vertical: DesignSystem.space1,
                  ),
                  decoration: BoxDecoration(
                    color: authWorkspaceAccentSoft,
                    borderRadius:
                        BorderRadius.circular(DesignSystem.radiusFull),
                  ),
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      fontSize: DesignSystem.textXs,
                      fontWeight: DesignSystem.weightSemibold,
                      color: authWorkspaceAccent,
                    ),
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
              ],
              if (compactHero)
                Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius:
                            BorderRadius.circular(DesignSystem.radiusXl),
                        border: Border.all(color: authWorkspacePanelBorder),
                      ),
                      child: heroGraphic,
                    ),
                    const SizedBox(width: DesignSystem.space4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: DesignSystem.weightBold,
                          color: DesignSystem.neutral900,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                    border: Border.all(color: authWorkspacePanelBorder),
                  ),
                  child: heroGraphic ??
                      Icon(icon, size: 30, color: authWorkspaceAccent),
                ),
                const SizedBox(height: DesignSystem.space5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: DesignSystem.weightBold,
                    color: DesignSystem.neutral900,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: DesignSystem.space3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: DesignSystem.neutral600,
                    height: 1.7,
                  ),
                ),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: DesignSystem.space5),
                Wrap(
                  spacing: DesignSystem.space3,
                  runSpacing: DesignSystem.space3,
                  children: facts
                      .map(
                        (fact) => _FactPill(
                          label: fact.label,
                          value: fact.value,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: authWorkspacePanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignSystem.textXs,
              color: DesignSystem.neutral500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
            ),
          ),
        ],
      ),
    );
  }
}
