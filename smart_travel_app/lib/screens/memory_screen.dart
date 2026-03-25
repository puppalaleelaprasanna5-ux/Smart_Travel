import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/travel_memory.dart';
import '../services/travel_data_service.dart';

class MemoryScreen extends StatefulWidget {
  final bool embedded;

  const MemoryScreen({super.key, this.embedded = false});

  @override
  _MemoryScreenState createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final ImagePicker picker = ImagePicker();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController tripIdController = TextEditingController();
  final TravelDataService travelData = TravelDataService.instance;

  List<TravelMemory> memoryList = [];
  bool loading = false;
  bool uploading = false;
  XFile? selectedMedia;
  String? selectedMediaType;
  String? draftMemoryId;

  @override
  void initState() {
    super.initState();
    loadMemories();
    travelData.addListener(_handleTravelDataChanged);
  }

  @override
  void dispose() {
    travelData.removeListener(_handleTravelDataChanged);
    descriptionController.dispose();
    tripIdController.dispose();
    super.dispose();
  }

  void _handleTravelDataChanged() {
    if (!mounted) return;
    setState(() {
      memoryList = travelData.memories;
    });
  }

  Future<void> loadMemories() async {
    try {
      setState(() => loading = true);
      await travelData.initialize();
      if (!mounted) return;
      setState(() => memoryList = travelData.memories);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final memoryId = await travelData.addMemory(
      description: 'Trip Memory',
      file: file,
      mediaType: 'image',
    );
    setState(() {
      draftMemoryId = memoryId;
      selectedMedia = null;
      selectedMediaType = null;
    });
  }

  Future<void> captureImage() async {
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null || !mounted) return;
    final memoryId = await travelData.addMemory(
      description: 'Trip Memory',
      file: file,
      mediaType: 'image',
    );
    setState(() {
      draftMemoryId = memoryId;
      selectedMedia = null;
      selectedMediaType = null;
    });
  }

  Future<void> pickTripPhotos() async {
    final files = await picker.pickMultiImage();
    if (files.isEmpty || !mounted) return;

    try {
      setState(() => uploading = true);
      final selectedFiles = files.take(5).toList();
      await travelData.addTripMemories(selectedFiles);
      await loadMemories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${selectedFiles.length} trip memories for ${travelData.cityName.isEmpty ? 'your trip' : travelData.cityName}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> pickVideo() async {
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() {
      selectedMedia = file;
      selectedMediaType = 'video';
    });
  }

  Future<void> uploadMemory() async {
    final description = descriptionController.text.trim();
    final mediaType =
        selectedMedia?.path.endsWith('.mp4') == true ? 'video' : 'image';

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required')),
      );
      return;
    }

    try {
      setState(() => uploading = true);
      if (draftMemoryId != null) {
        await travelData.updateMemory(
          memoryId: draftMemoryId!,
          description: description,
        );
      } else {
        await travelData.addMemory(
          description: description,
          file: selectedMedia,
          mediaType: mediaType,
        );
      }

      if (!mounted) return;

      descriptionController.clear();
      tripIdController.clear();
      setState(() {
        draftMemoryId = null;
        selectedMedia = null;
        selectedMediaType = null;
      });

      await loadMemories();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory uploaded successfully')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Widget _selectedMediaPreview() {
    if (selectedMedia == null) {
      return const SizedBox.shrink();
    }

    if (selectedMediaType == 'image') {
      return FutureBuilder<Uint8List>(
        future: selectedMedia!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            );
          }

          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EBF1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo, color: Color(0xFF48626E)),
          );
        },
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF48626E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.videocam,
        color: Colors.white,
      ),
    );
  }

  Map<String, List<TravelMemory>> get groupedMemories {
    final grouped = <String, List<TravelMemory>>{};
    for (final memory in memoryList) {
      final timestamp = memory.timestamp;
      final dateKey =
          timestamp.isEmpty ? 'Recent Memories' : timestamp.split('T').first;
      grouped.putIfAbsent(dateKey, () => []).add(memory);
    }
    return grouped;
  }

  List<_MemorySection> get displaySections {
    final source = groupedMemories.entries.toList();
    if (source.isEmpty) {
      return const [];
    }

    final labels = [
      'RECENT TRIP MEMORIES',
      'SAVED TRIP MOMENTS',
      'TRAVELPILOT MEMORY REEL',
    ];

    return source.asMap().entries.map((entry) {
      final items = entry.value.value;
      final visuals = items.asMap().entries.map((memoryEntry) {
        final memory = memoryEntry.value;
        final mediaType = memory.mediaType;
        final description = memory.description;
        final words = description.split(' ');
        final title = words.take(2).join(' ');
        final palettes = <List<Color>>[
          const [Color(0xFF2E8CC8), Color(0xFFEEC46C)],
          const [Color(0xFFC2A78E), Color(0xFF7A6351)],
          const [Color(0xFF1F5358), Color(0xFF6FA7A8)],
          const [Color(0xFF2F2A32), Color(0xFFCC7B22)],
        ];

        return _MemoryVisual(
          id: memory.id,
          title: title.isEmpty ? 'Travel Memory' : title,
          description: description,
          palette: palettes[memoryEntry.key % palettes.length],
          mediaPath: memory.mediaPath,
          mediaBytes: memory.mediaBytes,
          mediaType: mediaType,
          tag: memoryEntry.key == 0 ? 'DREAMY' : null,
        );
      }).toList();

      return _MemorySection(
        label: labels[entry.key % labels.length],
        items: visuals,
      );
    }).toList();
  }

  Widget _buildMemoryTile(_MemoryVisual item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: item.mediaPath != null &&
                            item.mediaPath!.isNotEmpty &&
                            item.mediaType == 'image' &&
                            item.mediaBytes == null
                        ? _memoryVisualFallback(item)
                        : _memoryVisualFallback(item),
                  ),
                ),
                if (item.tag != null)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF99FFF1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.tag!,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A5A62),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Row(
                    children: [
                      _overlayIconButton(
                        icon: Icons.edit_outlined,
                        onTap: () => _editMemory(item),
                      ),
                      const SizedBox(width: 6),
                      _overlayIconButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => _deleteMemory(item),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F252D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoryVisualFallback(_MemoryVisual item) {
    if (item.mediaBytes != null && item.mediaBytes!.isNotEmpty) {
      return Image.memory(
        base64Decode(item.mediaBytes!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.palette,
        ),
      ),
      child: Center(
        child: Icon(
          item.mediaType == 'video' ? Icons.videocam : Icons.photo_camera_back,
          color: Colors.white.withOpacity(0.9),
          size: 34,
        ),
      ),
    );
  }

  Widget _overlayIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF173D56)),
      ),
    );
  }

  Future<void> _editMemory(_MemoryVisual item) async {
    final controller = TextEditingController(text: item.description);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Memory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await travelData.updateMemory(
                        memoryId: item.id,
                        description: controller.text.trim().isEmpty
                            ? item.description
                            : controller.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMemory(_MemoryVisual item) async {
    await travelData.deleteMemory(item.id);
  }

  Widget _buildBody() {
    final sections = displaySections;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: loadMemories,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFF3B09E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'TravelPilot AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF355264),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: loadMemories,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF0F567F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Memories',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0B5F8E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your journey, curated by AI.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sections.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    travelData.hasSelectedCity
                        ? 'No memories yet. Add memory or import trip photos.'
                        : 'Plan a trip first, then add memories.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF33414F),
                    ),
                  ),
                )
              else
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              section.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.45),
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          itemCount: section.items.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                          itemBuilder: (context, index) {
                            return _buildMemoryTile(section.items[index], index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showUploadSheet(context),
            backgroundColor: const Color(0xFF0B5F8E),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_a_photo_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Memories')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Future<void> _showUploadSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Upload Memory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tripIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trip ID (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                if (selectedMedia != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _selectedMediaPreview(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedMedia!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              selectedMedia = null;
                              selectedMediaType = null;
                            });
                            Navigator.of(context).pop();
                            _showUploadSheet(this.context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await captureImage();
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          _showUploadSheet(this.context);
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await pickTripPhotos();
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.photo),
                        label: const Text('Pick Trip Photos'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await pickVideo();
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          _showUploadSheet(this.context);
                        },
                        icon: const Icon(Icons.videocam),
                        label: const Text('Pick Video'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: uploading
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await uploadMemory();
                          },
                    child: Text(uploading ? 'Uploading...' : 'Upload Memory'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemorySection {
  final String label;
  final List<_MemoryVisual> items;

  const _MemorySection({required this.label, required this.items});
}

class _MemoryVisual {
  final String id;
  final String title;
  final String description;
  final List<Color> palette;
  final String? mediaPath;
  final String? mediaBytes;
  final String? mediaType;
  final String? tag;

  const _MemoryVisual({
    required this.id,
    required this.title,
    required this.description,
    required this.palette,
    this.mediaPath,
    this.mediaBytes,
    this.mediaType,
    this.tag,
  });
}
