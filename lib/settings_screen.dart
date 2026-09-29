import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_service.dart';
import 'models.dart';
import 'storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final StorageService _storageService = StorageService.instance;

  List<EmergencyContact> _contacts = [];
  PriorityNumber? _priorityNumber;

  bool _isLoading = true;
  bool _usingLocalData = false;
  bool _isSaving = false;
  bool _usingLocalPriority = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Loads contacts and priority number from local storage and Firebase.
  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _contacts = [];
        _priorityNumber = null;
        _usingLocalData = false;
        _usingLocalPriority = false;
        _isLoading = false;
      });

      return;
    }

    try {
      final localContacts = await _storageService.getContacts(
        userId: user.uid,
      );

      final localPriorityNumber =
          await _storageService.getPriorityNumber(
        userId: user.uid,
      );

      if (!mounted) return;

      setState(() {
        _contacts = localContacts;
        _priorityNumber = localPriorityNumber;
        _usingLocalData = localContacts.isNotEmpty;
        _usingLocalPriority = localPriorityNumber != null;
        _isLoading = false;
      });

      try {
        final cloudContacts = await _firebaseService.getContacts(
          userId: user.uid,
        );

        final cloudPriorityNumber =
            await _firebaseService.getPriorityNumber(
          userId: user.uid,
        );

        final mergedContacts = _mergeContacts(
          localContacts,
          cloudContacts,
        );

        for (final contact in mergedContacts) {
          await _storageService.saveContact(
            userId: user.uid,
            contact: contact,
          );
        }

        PriorityNumber? mergedPriorityNumber =
            cloudPriorityNumber;

        if (localPriorityNumber != null) {
          mergedPriorityNumber = localPriorityNumber;
        }

        if (mergedPriorityNumber != null) {
          await _storageService.savePriorityNumber(
            mergedPriorityNumber,
          );
        }

        if (!mounted) return;

        setState(() {
          _contacts = mergedContacts;
          _priorityNumber = mergedPriorityNumber;

          _usingLocalData =
              localContacts.isNotEmpty && cloudContacts.isEmpty;

          _usingLocalPriority =
              localPriorityNumber != null &&
              cloudPriorityNumber == null;
        });

        final localOnlyContacts = localContacts.where(
          (localContact) {
            return !cloudContacts.any(
              (cloudContact) => cloudContact.id == localContact.id,
            );
          },
        );

        for (final contact in localOnlyContacts) {
          try {
            await _firebaseService.saveContact(
              userId: user.uid,
              contact: contact,
            );
          } catch (_) {}
        }

        if (localPriorityNumber != null &&
            cloudPriorityNumber == null) {
          try {
            await _firebaseService.savePriorityNumber(
              priorityNumber: localPriorityNumber,
            );

            if (!mounted) return;

            setState(() {
              _usingLocalPriority = false;
            });
          } catch (_) {}
        }
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _contacts = localContacts;
          _priorityNumber = localPriorityNumber;
          _usingLocalData = localContacts.isNotEmpty;
          _usingLocalPriority = localPriorityNumber != null;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _contacts = [];
        _priorityNumber = null;
        _usingLocalData = false;
        _usingLocalPriority = false;
        _isLoading = false;
      });

      _showMessage(
        'Unable to load your settings.',
        isWarning: true,
      );
    }
  }

  // Combines local and cloud contacts without losing local contacts.
  List<EmergencyContact> _mergeContacts(
    List<EmergencyContact> localContacts,
    List<EmergencyContact> cloudContacts,
  ) {
    final contactsById = <String, EmergencyContact>{};

    for (final contact in cloudContacts) {
      contactsById[contact.id] = contact;
    }

    for (final contact in localContacts) {
      contactsById[contact.id] = contact;
    }

    final mergedContacts = contactsById.values.toList();

    mergedContacts.sort(
      (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );

    return mergedContacts;
  }

  // Opens the contact form for creating a new emergency contact.
  Future<void> _addContact() async {
    if (_isSaving) return;

    final contact = await _showContactDialog();

    if (contact == null || !mounted) {
      return;
    }

    await _saveContact(contact);
  }

  // Opens the contact form for editing an existing emergency contact.
  Future<void> _editContact(EmergencyContact contact) async {
    if (_isSaving) return;

    final updatedContact = await _showContactDialog(
      existingContact: contact,
    );

    if (updatedContact == null || !mounted) {
      return;
    }

    await _updateContact(updatedContact);
  }

  // Saves a new contact locally and synchronises it with Firebase.
  Future<void> _saveContact(EmergencyContact contact) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in before adding a contact.',
        isWarning: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.saveContact(
        userId: user.uid,
        contact: contact,
      );

      if (!mounted) return;

      setState(() {
        _contacts = [
          ..._contacts,
          contact,
        ];

        _contacts.sort(
          (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
        );
      });

      try {
        await _firebaseService.saveContact(
          userId: user.uid,
          contact: contact,
        );

        if (!mounted) return;

        _showMessage(
          'Emergency contact saved successfully.',
        );
      } catch (_) {
        if (!mounted) return;

        _showMessage(
          'Contact saved locally. Cloud sync will be retried later.',
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to save the emergency contact.',
        isWarning: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Updates an existing contact locally and in Firebase.
  Future<void> _updateContact(
    EmergencyContact contact,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in before updating a contact.',
        isWarning: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.updateContact(
        userId: user.uid,
        contact: contact,
      );

      if (!mounted) return;

      setState(() {
        _contacts = _contacts.map((item) {
          return item.id == contact.id ? contact : item;
        }).toList();

        _contacts.sort(
          (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
        );
      });

      try {
        await _firebaseService.updateContact(
          userId: user.uid,
          contact: contact,
        );

        if (!mounted) return;

        _showMessage(
          'Emergency contact updated successfully.',
        );
      } catch (_) {
        if (!mounted) return;

        _showMessage(
          'Contact updated locally. Cloud sync will be retried later.',
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to update the emergency contact.',
        isWarning: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Deletes a contact after confirmation.
  Future<void> _deleteContact(
    EmergencyContact contact,
  ) async {
    if (_isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete contact?'),
          content: Text(
            '${contact.name} will be removed from your emergency contacts.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RapidAidColors.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in before deleting a contact.',
        isWarning: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.deleteContact(
        userId: user.uid,
        contactId: contact.id,
      );

      if (!mounted) return;

      setState(() {
        _contacts.removeWhere(
          (item) => item.id == contact.id,
        );
      });

      try {
        await _firebaseService.deleteContact(
          userId: user.uid,
          contactId: contact.id,
        );

        if (!mounted) return;

        _showMessage(
          'Emergency contact deleted successfully.',
        );
      } catch (_) {
        if (!mounted) return;

        _showMessage(
          'Contact deleted locally. Cloud deletion will need to be retried.',
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete the emergency contact.',
        isWarning: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Opens the add or edit contact dialog.
  Future<EmergencyContact?> _showContactDialog({
    EmergencyContact? existingContact,
  }) {
    return showDialog<EmergencyContact>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ContactDialog(
          existingContact: existingContact,
        );
      },
    );
  }

  // Opens the priority number form.
  Future<void> _addOrEditPriorityNumber() async {
    if (_isSaving) return;

    final phone = await _showPriorityNumberDialog(
      existingNumber: _priorityNumber?.phone,
    );

    if (phone == null || !mounted) {
      return;
    }

    await _savePriorityNumber(phone);
  }

  // Saves the priority number locally and synchronises it with Firebase.
  Future<void> _savePriorityNumber(String phone) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in before setting a priority number.',
        isWarning: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final priorityNumber = PriorityNumber(
      userId: user.uid,
      phone: phone,
    );

    try {
      await _storageService.savePriorityNumber(
        priorityNumber,
      );

      if (!mounted) return;

      setState(() {
        _priorityNumber = priorityNumber;
        _usingLocalPriority = true;
      });

      try {
        await _firebaseService.savePriorityNumber(
          priorityNumber: priorityNumber,
        );

        if (!mounted) return;

        setState(() {
          _usingLocalPriority = false;
        });

        _showMessage(
          'Priority number saved successfully.',
        );
      } catch (_) {
        if (!mounted) return;

        _showMessage(
          'Priority number saved locally. Cloud sync will be retried later.',
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to save the priority number.',
        isWarning: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Removes the priority number after confirmation.
  Future<void> _removePriorityNumber() async {
    if (_isSaving || _priorityNumber == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: RapidAidColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_disabled_rounded,
              color: RapidAidColors.primary,
              size: 28,
            ),
          ),
          title: const Text(
            'Remove priority number?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'The priority number will no longer be used when you trigger an SOS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RapidAidColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RapidAidColors.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in before removing the priority number.',
        isWarning: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.deletePriorityNumber(
        userId: user.uid,
      );

      if (!mounted) return;

      setState(() {
        _priorityNumber = null;
        _usingLocalPriority = false;
      });

      try {
        await _firebaseService.deletePriorityNumber(
          userId: user.uid,
        );

        if (!mounted) return;

        _showMessage(
          'Priority number removed successfully.',
        );
      } catch (_) {
        if (!mounted) return;

        _showMessage(
          'Priority number removed locally. Cloud deletion will need to be retried.',
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to remove the priority number.',
        isWarning: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Opens the priority number dialog.
  Future<String?> _showPriorityNumberDialog({
    String? existingNumber,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PriorityNumberDialog(
          existingNumber: existingNumber,
        );
      },
    );
  }

  // Shows a short status message.
  void _showMessage(
    String message, {
    bool isWarning = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning
            ? RapidAidColors.warning
            : RapidAidColors.success,
      ),
    );
  }

  // Builds the settings screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _isSaving ? null : widget.onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text('Settings'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _addContact,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text('Add Contact'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              color: RapidAidColors.primary,
              onRefresh: _loadSettings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  100,
                ),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 18),
                  _buildPriorityNumberCard(),
                  const SizedBox(height: 22),
                  _buildContactsHeader(),
                  const SizedBox(height: 10),
                  if (_contacts.isEmpty)
                    _buildEmptyState()
                  else
                    ..._contacts.map(_buildContactCard),
                ],
              ),
            ),
    );
  }

  // Builds the settings introduction card.
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            RapidAidColors.primary,
            RapidAidColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage your priority emergency number and the people included in your alerts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the priority emergency number card.
  Widget _buildPriorityNumberCard() {
    final bool hasPriorityNumber = _priorityNumber != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: RapidAidColors.primary.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: RapidAidColors.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priority emergency number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: RapidAidColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'The number RapidAid will try to call when you trigger SOS.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: RapidAidColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasPriorityNumber)
              _buildPriorityNumberContent()
            else
              _buildPriorityNumberEmpty(),
          ],
        ),
      ),
    );
  }

  // Builds the configured priority number content.
  Widget _buildPriorityNumberContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RapidAidColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: RapidAidColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_rounded,
                color: RapidAidColors.success,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _priorityNumber!.phone,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: RapidAidColors.textPrimary,
                  ),
                ),
              ),
              if (_usingLocalPriority)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RapidAidColors.warning.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 13,
                        color: RapidAidColors.warning,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: RapidAidColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSaving ? null : _addOrEditPriorityNumber,
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                  ),
                  label: const Text('Change'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSaving ? null : _removePriorityNumber,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                  ),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RapidAidColors.error,
                    side: const BorderSide(
                      color: RapidAidColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds the empty priority number state.
  Widget _buildPriorityNumberEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RapidAidColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: RapidAidColors.border,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'No priority number configured',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: RapidAidColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add one so the SOS screen knows which number to call first.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: RapidAidColors.textSecondary,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isSaving ? null : _addOrEditPriorityNumber,
              icon: const Icon(
                Icons.add_call,
                size: 19,
              ),
              label: const Text(
                'Add Priority Number',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the emergency contacts section heading.
  Widget _buildContactsHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Emergency contacts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: RapidAidColors.textPrimary,
            ),
          ),
        ),
        if (_usingLocalData)
          const Chip(
            avatar: Icon(
              Icons.cloud_off_rounded,
              size: 15,
            ),
            label: Text('Offline'),
          ),
      ],
    );
  }

  // Builds an individual emergency contact card.
  Widget _buildContactCard(
    EmergencyContact contact,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: RapidAidColors.surfaceSoft,
          child: Text(
            contact.name.isNotEmpty
                ? contact.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: RapidAidColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${contact.relationship} • ${contact.phone}',
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_isSaving,
          onSelected: (value) {
            if (value == 'edit') {
              _editContact(contact);
            } else if (value == 'delete') {
              _deleteContact(contact);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the empty emergency contacts state.
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: RapidAidColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RapidAidColors.border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: RapidAidColors.primary,
          ),
          SizedBox(height: 12),
          Text(
            'No emergency contacts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use the button below to add your first trusted contact.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RapidAidColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  final EmergencyContact? existingContact;

  const _ContactDialog({
    this.existingContact,
  });

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _phoneController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.existingContact?.name ?? '',
    );

    _relationshipController = TextEditingController(
      text: widget.existingContact?.relationship ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.existingContact?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Validates the form and returns the contact to the parent screen.
  void _submit() {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final contact = EmergencyContact(
      id: widget.existingContact?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    Navigator.of(context).pop(contact);
  }

  // Builds the contact form dialog.
  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingContact != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Edit emergency contact'
            : 'Add emergency contact',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relationshipController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(
                    Icons.people_outline,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a relationship.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                  ),
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';

                  final digits = phone.replaceAll(
                    RegExp(r'[^0-9]'),
                    '',
                  );

                  if (digits.length < 7 ||
                      digits.length > 15) {
                    return 'Enter a valid phone number.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            isEditing ? 'Save' : 'Add',
          ),
        ),
      ],
    );
  }
}

class _PriorityNumberDialog extends StatefulWidget {
  final String? existingNumber;

  const _PriorityNumberDialog({
    this.existingNumber,
  });

  @override
  State<_PriorityNumberDialog> createState() =>
      _PriorityNumberDialogState();
}

class _PriorityNumberDialogState
    extends State<_PriorityNumberDialog> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _phoneController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _phoneController = TextEditingController(
      text: widget.existingNumber ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Validates and returns the priority phone number.
  void _submit() {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Navigator.of(context).pop(
      _phoneController.text.trim(),
    );
  }

  // Builds the priority number form dialog.
  @override
  Widget build(BuildContext context) {
    final bool isEditing =
        widget.existingNumber != null &&
        widget.existingNumber!.trim().isNotEmpty;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Change priority number'
            : 'Add priority number',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This number will be used as the first emergency call target when you trigger SOS.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: RapidAidColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Priority phone number',
                hintText: '+91 9876543210',
                prefixIcon: Icon(
                  Icons.phone_in_talk_rounded,
                ),
              ),
              validator: (value) {
                final phone = value?.trim() ?? '';

                if (phone.isEmpty) {
                  return 'Enter a priority number.';
                }

                final digits = phone.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );

                if (digits.length < 7 ||
                    digits.length > 15) {
                  return 'Enter a valid phone number.';
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            isEditing ? 'Save' : 'Add',
          ),
        ),
      ],
    );
  }
}