import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

final kasirListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/kasir');
  return response.data as List<dynamic>;
});

class ManageKasirScreen extends ConsumerStatefulWidget {
  const ManageKasirScreen({super.key});

  @override
  ConsumerState<ManageKasirScreen> createState() => _ManageKasirScreenState();
}

class _ManageKasirScreenState extends ConsumerState<ManageKasirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showAddKasirDialog(BuildContext context, WidgetRef ref, int currentCount) {
    if (currentCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batas maksimal 5 akun Kasir telah tercapai.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Tambah Akun Kasir', style: TextStyle(color: Colors.white)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nama Kasir', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                validator: (val) => val == null || val.isEmpty ? 'Isi nama kasir' : null,
              ),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email Kasir', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val == null || val.isEmpty ? 'Isi email kasir' : null,
              ),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Kata Sandi', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                obscureText: true,
                validator: (val) => val == null || val.length < 6 ? 'Minimal 6 karakter' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final dio = ref.read(dioProvider);
                try {
                  await dio.post('/owner/kasir', data: {
                    'name': _nameController.text,
                    'email': _emailController.text,
                    'password': _passwordController.text,
                  });
                  ref.invalidate(kasirListProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun Kasir berhasil dibuat!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                  }
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleKasirStatus(BuildContext context, WidgetRef ref, int kasirId) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post('/owner/kasir/$kasirId/toggle');
      ref.invalidate(kasirListProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _deleteKasir(BuildContext context, WidgetRef ref, int kasirId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Hapus Kasir', style: TextStyle(color: Colors.white)),
        content: const Text('Yakin mau menghapus akun kasir ini permanen?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dio = ref.read(dioProvider);
      try {
        await dio.delete('/owner/kasir/$kasirId');
        ref.invalidate(kasirListProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kasirAsync = ref.watch(kasirListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kasir'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: kasirAsync.when(
          data: (kasirList) {
            final count = kasirList.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar Kasir ($count/5 Akun)', 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddKasirDialog(context, ref, count),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Kasir'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (kasirList.isEmpty)
                  const Expanded(child: Center(child: Text('Belum ada akun Kasir.', style: TextStyle(color: AppTheme.textSecondary))))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: kasirList.length,
                      itemBuilder: (context, index) {
                        final k = kasirList[index];
                        final bool isActive = k['is_active'] == 1 || k['is_active'] == true;
                        final kasirId = int.parse(k['id'].toString());

                        return Card(
                          color: AppTheme.surfaceDark,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accentColor,
                              child: Text(k['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(k['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(k['email'], style: const TextStyle(color: AppTheme.textSecondary)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(isActive ? 'Aktif' : 'Nonaktif', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  backgroundColor: isActive ? Colors.green : Colors.red,
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  color: AppTheme.surfaceDark,
                                  onSelected: (value) {
                                    if (value == 'toggle') {
                                      _toggleKasirStatus(context, ref, kasirId);
                                    } else if (value == 'delete') {
                                      _deleteKasir(context, ref, kasirId);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(isActive ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(color: isActive ? Colors.orange : Colors.green)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
        ),
      ),
    );
  }
}
