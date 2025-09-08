import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore.dart';
import '../../../services/data_sharing_service.dart';

class CareProviderScreen extends StatefulWidget {
  const CareProviderScreen({super.key});

  @override
  State<CareProviderScreen> createState() => _CareProviderScreenState();
}

class _CareProviderScreenState extends State<CareProviderScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DataSharingService _dataSharingService = DataSharingService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProviders = [];
  List<Map<String, dynamic>> _sharedProviders = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSharedProviders();
  }

  void _loadSharedProviders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final sharedWith =
            await _dataSharingService.getAuthorizedHealthcareProviders();
        if (mounted) {
          setState(() {
            _sharedProviders = sharedWith;
          });
        }
      } catch (e) {
        print('Error loading shared providers: $e');
      }
    }
  }

  void _onSearchChanged(String searchText) async {
    if (searchText.isEmpty) {
      setState(() {
        _filteredProviders = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results =
          await _firestoreService.searchHealthcareProviders(searchText);
      if (mounted) {
        setState(() {
          _filteredProviders = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _filteredProviders = [];
          _isSearching = false;
        });
      }
      print('Search error: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Healthcare Providers',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text(
                    'Healthcare Providers',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  content: const Text(
                    'Search for healthcare professionals by name to connect with them for your hemophilia care.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search healthcare providers by name...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _searchController.text.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredProviders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No healthcare providers found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try searching with a different name',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredProviders.length,
                                itemBuilder: (context, index) {
                                  final provider = _filteredProviders[index];
                                  return ProviderListTile(provider: provider);
                                },
                              ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared Providers Section
                  const Text(
                    'Providers with Access to Your Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_sharedProviders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.share,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Shared Providers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You haven\'t shared your data with any healthcare providers yet.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      flex: 1,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _sharedProviders.length,
                        itemBuilder: (context, index) {
                          final provider = _sharedProviders[index];
                          return SharedProviderTile(provider: provider);
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Search Instructions Section
                  const Text(
                    'Find New Providers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Search for Healthcare Providers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use the search bar above to find healthcare professionals by their name and connect with them for your hemophilia care.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ProviderListTile extends StatelessWidget {
  final Map<String, dynamic> provider;

  const ProviderListTile({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          provider['name'] ?? 'Unknown Provider',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          provider['email'] ?? 'No email provided',
          style: TextStyle(color: Colors.grey[600]),
        ),
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.local_hospital, color: Colors.white),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.redAccent),
        tileColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/care_user_information',
            arguments: provider,
          );
        },
      ),
    );
  }
}

class SharedProviderTile extends StatelessWidget {
  final Map<String, dynamic> provider;

  const SharedProviderTile({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          provider['name'] ?? 'Unknown Provider',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider['email'] ?? 'No email provided',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Data Shared',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.verified_user, color: Colors.white),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.green),
        tileColor: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/care_user_information',
            arguments: provider,
          );
        },
      ),
    );
  }
}
