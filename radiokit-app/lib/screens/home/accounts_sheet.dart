import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_theme.dart';

class AccountsSheet extends StatelessWidget {
  const AccountsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const AccountsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<AccountProvider>(
          builder: (context, provider, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: provider.accounts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_off_rounded,
                                      size: 48, color: Colors.white.withValues(alpha: 0.15)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No accounts yet',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create an account to get started',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                              itemCount: provider.accounts.length,
                              itemBuilder: (context, index) {
                                final account = provider.accounts[index];
                                return _AccountCard(
                                  account: account,
                                  onEdit: () => _showAccountDialog(context, account: account),
                                  onShare: () => _sharePublicKey(context, account),
                                  onCopy: () => _copyPublicKey(context, account),
                                  onDelete: () => _confirmDelete(context, provider, account),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FloatingActionButton(
                    onPressed: () => _showAccountDialog(context),
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAccountDialog(BuildContext context, {Account? account}) {
    showDialog(
      context: context,
      builder: (_) => _AccountDialog(account: account),
    );
  }

  void _sharePublicKey(BuildContext context, Account account) {
    // Share functionality would use share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Public key copied for sharing'),
        backgroundColor: Colors.greenAccent,
      ),
    );
    Clipboard.setData(ClipboardData(text: account.publicKey));
  }

  void _copyPublicKey(BuildContext context, Account account) {
    Clipboard.setData(ClipboardData(text: account.publicKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Public key copied'),
        backgroundColor: AppColors.brandOrange,
      ),
    );
  }

  void _confirmDelete(BuildContext context, AccountProvider provider, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Account'),
        content: Text('Delete "${account.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            child: Text('DELETE',
                style: GoogleFonts.changa(
                    color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.publicKey.substring(0, 16) + '...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (account.relay.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Relay: ${account.relay}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.share_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
              onPressed: onShare,
              tooltip: 'Share',
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
              onPressed: onCopy,
              tooltip: 'Copy public key',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final Account? account;

  const _AccountDialog({this.account});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _relayCtrl;
  bool _isNew = false;
  bool _obscurePrivateKey = true;

  @override
  void initState() {
    super.initState();
    _isNew = widget.account == null;
    _nameCtrl = TextEditingController(text: widget.account?.name ?? '');
    _relayCtrl = TextEditingController(text: widget.account?.relay ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(_isNew ? 'Create Account' : 'Edit Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'NAME',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relayCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'RELAY (optional)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                hintText: 'wss://relay.example.com',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Text(
                'PUBLIC KEY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _KeyRow(
                text: widget.account!.publicKey,
                obscured: false,
                keyLabel: 'Public',
              ),
              const SizedBox(height: 12),
              Text(
                'PRIVATE KEY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _KeyRow(
                text: widget.account!.privateKey,
                obscured: _obscurePrivateKey,
                keyLabel: 'Private',
                onToggleObscured: () => setState(() => _obscurePrivateKey = !_obscurePrivateKey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandOrange,
            foregroundColor: Colors.black,
          ),
          onPressed: _save,
          child: Text(_isNew ? 'CREATE' : 'SAVE'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<AccountProvider>();
    final relay = _relayCtrl.text.trim();

    if (_isNew) {
      final account = Account.generate(name: name).copyWith(relay: relay);
      provider.addAccount(account);
    } else {
      provider.updateAccount(widget.account!.id, name: name, relay: relay);
    }

    Navigator.pop(context);
  }
}

class _KeyRow extends StatelessWidget {
  final String text;
  final bool obscured;
  final String keyLabel;
  final VoidCallback? onToggleObscured;

  const _KeyRow({
    required this.text,
    required this.obscured,
    required this.keyLabel,
    this.onToggleObscured,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              obscured ? '•' * text.length : text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (onToggleObscured != null) ...[
            IconButton(
              icon: Icon(
                obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              onPressed: onToggleObscured,
              tooltip: obscured ? 'Show' : 'Hide',
              visualDensity: VisualDensity.compact,
            ),
          ],
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$keyLabel key copied'),
                  backgroundColor: AppColors.brandOrange,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
