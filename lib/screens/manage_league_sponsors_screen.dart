import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/sports_models.dart';
import '../services/photo_upload_service.dart';
import '../services/sports_service.dart';

class ManageLeagueSponsorsScreen extends StatefulWidget {
  final String sportType;

  const ManageLeagueSponsorsScreen({
    super.key,
    this.sportType = 'football',
  });

  @override
  State<ManageLeagueSponsorsScreen> createState() =>
      _ManageLeagueSponsorsScreenState();
}

class _ManageLeagueSponsorsScreenState
    extends State<ManageLeagueSponsorsScreen> {

  // ========================================================================
  // OPEN EDITOR
  // ========================================================================

  Future<void> _openEditor({
    LeagueSponsor? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    final orderController = TextEditingController(
      text: '${existing?.sortOrder ?? 0}',
    );

    File? pickedLogo;

    bool active = existing?.active ?? true;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
              context,
              setSheetState,
              ) {

            // ==============================================================
            // PICK LOGO
            // ==============================================================

            Future<void> pickLogo() async {
              try {
                final picked =
                await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                );

                if (picked != null) {
                  setSheetState(() {
                    pickedLogo = File(picked.path);
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not choose image: $e',
                      ),
                    ),
                  );
                }
              }
            }

            // ==============================================================
            // SAVE
            // ==============================================================

            Future<void> save() async {
              final name =
              nameController.text.trim();

              final order =
                  int.tryParse(
                    orderController.text.trim(),
                  ) ??
                      0;

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sponsor name is required.',
                    ),
                  ),
                );
                return;
              }

              if (existing == null &&
                  pickedLogo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please choose the sponsor logo.',
                    ),
                  ),
                );
                return;
              }

              setSheetState(() {
                saving = true;
              });

              try {
                // ==========================================================
                // NEW SPONSOR
                // ==========================================================

                if (existing == null) {
                  final sponsorId =
                  SportsService.instance.newSponsorId();

                  bool firestoreCreated = false;

                  try {
                    // ------------------------------------------------------
                    // STEP 1:
                    // Create Firestore record FIRST.
                    //
                    // The new service automatically sets:
                    // active: true
                    // ------------------------------------------------------

                    await SportsService.instance
                        .createSponsorWithId(
                      id: sponsorId,
                      sportType: widget.sportType,
                      name: name,
                      logoUrl: '',
                      sortOrder: order,
                    );

                    firestoreCreated = true;

                    // ------------------------------------------------------
                    // STEP 2:
                    // Upload logo.
                    // ------------------------------------------------------

                    final logoUrl =
                    await PhotoUploadService
                        .uploadLeagueSponsorLogo(
                      uid: sponsorId,
                      photo: pickedLogo!,
                    );

                    // ------------------------------------------------------
                    // STEP 3:
                    // Put logo URL into Firestore.
                    // ------------------------------------------------------

                    await SportsService.instance
                        .updateSponsor(
                      sponsorId,
                      logoUrl: logoUrl,
                    );
                  } catch (e) {
                    // ------------------------------------------------------
                    // CLEANUP
                    //
                    // If Firestore was successfully created but a later
                    // operation failed, remove the incomplete sponsor.
                    // ------------------------------------------------------

                    if (firestoreCreated) {
                      try {
                        await SportsService.instance
                            .deleteSponsor(
                          sponsorId,
                        );
                      } catch (_) {
                        // Keep the original exception.
                      }
                    }

                    rethrow;
                  }
                }

                // ==========================================================
                // EXISTING SPONSOR
                // ==========================================================

                else {
                  String? logoUrl;

                  // Upload a new logo only when Admin selected one.
                  if (pickedLogo != null) {
                    logoUrl =
                    await PhotoUploadService
                        .uploadLeagueSponsorLogo(
                      uid: existing.id,
                      photo: pickedLogo!,
                    );
                  }

                  await SportsService.instance
                      .updateSponsor(
                    existing.id,
                    name: name,
                    logoUrl: logoUrl,
                    sortOrder: order,
                    active: active,
                  );
                }

                // ==========================================================
                // SUCCESS
                // ==========================================================

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existing == null
                            ? 'Sponsor added successfully.'
                            : 'Sponsor updated successfully.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() {
                  saving = false;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save sponsor: $e',
                      ),
                    ),
                  );
                }
              }
            }

            // ==============================================================
            // EDITOR UI
            // ==============================================================

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                    20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    Text(
                      existing == null
                          ? 'Add League Sponsor'
                          : 'Edit League Sponsor',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ======================================================
                    // LOGO PREVIEW
                    // ======================================================

                    Center(
                      child: GestureDetector(
                        onTap:
                        saving ? null : pickLogo,
                        child: Container(
                          width: 120,
                          height: 90,
                          padding:
                          const EdgeInsets.all(10),
                          decoration:
                          BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                            border: Border.all(
                              color:
                              Colors.grey.shade300,
                            ),
                          ),
                          child: pickedLogo != null
                              ? Image.file(
                            pickedLogo!,
                            fit: BoxFit.contain,
                          )
                              : (existing
                              ?.logoUrl
                              .isNotEmpty ??
                              false)
                              ? Image.network(
                            existing!.logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (
                                _,
                                __,
                                ___,
                                ) {
                              return const Icon(
                                Icons.business,
                              );
                            },
                          )
                              : const Icon(
                            Icons
                                .add_photo_alternate_outlined,
                            size: 34,
                          ),
                        ),
                      ),
                    ),

                    Center(
                      child: TextButton.icon(
                        onPressed:
                        saving ? null : pickLogo,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                        ),
                        label: Text(
                          existing == null
                              ? 'Choose logo'
                              : 'Change logo',
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ======================================================
                    // NAME
                    // ======================================================

                    TextField(
                      controller: nameController,
                      enabled: !saving,
                      decoration:
                      const InputDecoration(
                        labelText: 'Sponsor name',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ======================================================
                    // ORDER
                    // ======================================================

                    TextField(
                      controller:
                      orderController,
                      enabled: !saving,
                      keyboardType:
                      TextInputType.number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Display order',
                        helperText:
                        'Lower numbers enter first.',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    // ======================================================
                    // ACTIVE
                    // ======================================================

                    if (existing != null)
                      SwitchListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Show sponsor publicly',
                        ),
                        subtitle: Text(
                          active
                              ? 'Sponsor is visible.'
                              : 'Sponsor is hidden.',
                        ),
                        value: active,
                        onChanged: saving
                            ? null
                            : (value) {
                          setSheetState(() {
                            active = value;
                          });
                        },
                      ),

                    const SizedBox(height: 16),

                    // ======================================================
                    // SAVE BUTTON
                    // ======================================================

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                        saving ? null : save,
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.save_outlined,
                        ),
                        label: Text(
                          saving
                              ? 'Saving...'
                              : 'Save Sponsor',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    orderController.dispose();
  }

  // ========================================================================
  // DELETE
  // ========================================================================

  Future<void> _delete(
      LeagueSponsor sponsor,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:
          const Text('Delete sponsor?'),
          content: Text(
            'Remove ${sponsor.name} from the league sponsor footer?',
          ),
          actions: [

            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    ctx,
                    false,
                  ),
              child:
              const Text('Cancel'),
            ),

            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.red[700],
              ),
              onPressed: () =>
                  Navigator.pop(
                    ctx,
                    true,
                  ),
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await SportsService.instance
          .deleteSponsor(
        sponsor.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Sponsor deleted.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete sponsor: $e',
            ),
          ),
        );
      }
    }
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'League Sponsors',
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () =>
            _openEditor(),
        icon: const Icon(
          Icons.add_business_outlined,
        ),
        label:
        const Text('Add Sponsor'),
      ),

      body: StreamBuilder<
          List<LeagueSponsor>>(
        stream: SportsService.instance
            .allSponsorsStream(
          widget.sportType,
        ),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'Could not load sponsors.',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      '${snapshot.error}',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final sponsors =
              snapshot.data ??
                  <LeagueSponsor>[];

          if (sponsors.isEmpty) {
            return const Center(
              child: Padding(
                padding:
                EdgeInsets.all(24),
                child: Text(
                  'No league sponsors yet.\n\n'
                      'Tap "Add Sponsor" to add the first one.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount:
            sponsors.length,
            separatorBuilder:
                (_, __) =>
            const SizedBox(
              height: 10,
            ),
            itemBuilder:
                (context, index) {
              final sponsor =
              sponsors[index];

              return Card(
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.all(
                    10,
                  ),

                  leading: Container(
                    width: 64,
                    height: 56,
                    padding:
                    const EdgeInsets.all(
                      6,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey.shade100,
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: sponsor
                        .logoUrl
                        .isNotEmpty
                        ? Image.network(
                      sponsor.logoUrl,
                      fit:
                      BoxFit.contain,
                      errorBuilder:
                          (
                          _,
                          __,
                          ___,
                          ) {
                        return const Icon(
                          Icons
                              .business,
                        );
                      },
                    )
                        : const Icon(
                      Icons.business,
                    ),
                  ),

                  title: Text(
                    sponsor.name,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  subtitle: Text(
                    'Order: ${sponsor.sortOrder} • '
                        '${sponsor.active ? 'Visible' : 'Hidden'}',
                  ),

                  trailing: PopupMenuButton<
                      String>(
                    onSelected:
                        (value) {
                      if (value ==
                          'edit') {
                        _openEditor(
                          existing:
                          sponsor,
                        );
                      } else if (value ==
                          'delete') {
                        _delete(
                          sponsor,
                        );
                      }
                    },
                    itemBuilder:
                        (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(
                            Icons.edit_outlined,
                          ),
                          title:
                          Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons
                                .delete_outline,
                          ),
                          title:
                          Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}