import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/clipboard_service.dart';
import '../bloc/clipboard/clipboard_bloc.dart';
import '../bloc/clipboard/clipboard_event.dart';
import '../bloc/settings/settings_bloc.dart';
import '../bloc/settings/settings_event.dart';
import '../bloc/settings/settings_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              const SizedBox(height: 16),
              _buildSectionHeader('Capture'),
              _buildSwitchTile(
                title: AppStrings.backgroundCapture,
                subtitle: AppStrings.backgroundCaptureDesc,
                value: state.backgroundCaptureEnabled,
                onChanged: (value) async {
                  context.read<SettingsBloc>().add(ToggleBackgroundCapture(value));
                  if (value) {
                    await ClipboardService.startService();
                  } else {
                    await ClipboardService.stopService();
                  }
                },
              ),
              const Divider(),
              _buildSectionHeader('Storage'),
              _buildSliderTile(
                title: AppStrings.storageLimit,
                value: state.storageLimit.toDouble(),
                min: 10,
                max: 100,
                divisions: 9,
                onChanged: (value) {
                  final limit = value.round();
                  context.read<SettingsBloc>().add(UpdateStorageLimitSetting(limit));
                  context.read<ClipboardBloc>().add(UpdateStorageLimit(limit));
                },
                valueLabel: '${state.storageLimit} ${AppStrings.items}',
              ),
              const Divider(),
              _buildSectionHeader('Data'),
              _buildActionTile(
                title: AppStrings.export,
                icon: Icons.upload_file,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (!mounted) return;
                  try {
                    final jsonData = await _exportData();
                    
                    final directory = await getApplicationDocumentsDirectory();
                    final file = File('${directory.path}/snipt_backup.json');
                    await file.writeAsString(jsonData);
                    
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      subject: 'Snipt Backup',
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(AppStrings.exported)),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              _buildActionTile(
                title: AppStrings.clearData,
                icon: Icons.delete_forever,
                iconColor: AppColors.error,
                onTap: () => _showClearDataConfirmation(context),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('About'),
              _buildInfoTile(
                title: 'Version',
                value: '1.0.0',
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accent;
        }
        return AppColors.textSecondary;
      }),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              Text(
                valueLabel,
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: iconColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      trailing: Text(
        value,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Future<String> _exportData() async {
    final bloc = context.read<ClipboardBloc>();
    final items = bloc.state.recentItems;
    final bookmarked = bloc.state.bookmarkedItems;
    
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'recentItems': items.map((item) => {
        'id': item.id,
        'content': item.content,
        'category': item.category.name,
        'isBookmarked': item.isBookmarked,
        'createdAt': item.createdAt,
      }).toList(),
      'bookmarkedItems': bookmarked.map((item) => {
        'id': item.id,
        'content': item.content,
        'category': item.category.name,
        'createdAt': item.createdAt,
      }).toList(),
    };
    
    return jsonEncode(exportData);
  }

  void _showClearDataConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.clearData,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          AppStrings.clearAllConfirm,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ClipboardBloc>().add(ClearAllItems());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.dataCleared)),
              );
            },
            child: Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
