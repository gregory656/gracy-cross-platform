import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact_mapping_model.dart';

final contactServiceProvider = Provider<ContactService>((ref) => ContactService());

class ContactService {
  Future<bool> requestContactPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<bool> hasContactPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  Future<List<ContactMapping>> syncContacts() async {
    return [];
  }

  Future<List<ContactMapping>> getContactsOnGracy() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await Supabase.instance.client
          .from('contact_mappings')
          .select()
          .eq('owner_id', currentUserId)
          .eq('is_on_gracy', true);

      return response.map((data) => ContactMapping.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Failed to get Gracy contacts: $e');
    }
  }

  Future<void> showContactSyncDialog(BuildContext context) async {
    final hasPermission = await hasContactPermission();
    if (!context.mounted) {
      return;
    }
    
    if (!hasPermission) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact Sync'),
          content: const Text(
            'Gracy needs access to your contacts to help you find friends who are already using the app. Your contacts are stored securely and never shared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow Access'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await requestContactPermission();
        if (!context.mounted) {
          return;
        }
      }
    }

    final canSyncContacts = await hasContactPermission();
    if (!context.mounted) {
      return;
    }

    if (canSyncContacts) {
      try {
        await syncContacts();
      } catch (e) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync contacts: $e')),
        );
      }
    }
  }
}
