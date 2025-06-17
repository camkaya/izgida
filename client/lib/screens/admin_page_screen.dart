import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/complaint.dart';
import '../models/business.dart';
import '../services/api_service.dart';

class AdminPageScreen extends StatefulWidget {
  const AdminPageScreen({Key? key}) : super(key: key);

  @override
  State<AdminPageScreen> createState() => _AdminPageScreenState();
}

class _AdminPageScreenState extends State<AdminPageScreen> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];
  bool _isLoading = true;
  bool _isCreatingRoute = false;
  String _errorMessage = '';
  
  String? _selectedDistrictFilter;
  
  String? _selectedStatusFilter;
  
  Set<String> _selectedBusinessIds = {};
  
  bool _isSelectionMode = false;
  
  Set<String> _markedForRejection = {};
  
  Map<String, Map<String, dynamic>> _tempSavedComplaints = {};
  
  late TabController _tabController;
  
  final Map<String, ScrollController> _scrollControllers = {
    'pending': ScrollController(),
    'in-review': ScrollController(),
    'positive': ScrollController(),
    'negative': ScrollController(),
    'rejected': ScrollController(),
  };
  
  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _tabController = TabController(length: 5, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    
    _scrollControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final businesses = await ApiService.getBusinesses();
      
      if (!mounted) return;
      
      setState(() {
        _businesses = businesses;
        _filteredBusinesses = businesses;
        _isLoading = false;
      });
    } catch (e) {
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'İşletmeler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }
  
  void _filterBusinesses() {
    setState(() {
      _filteredBusinesses = _businesses.where((business) {
        
        final districtMatch = _selectedDistrictFilter == null || 
                           business.district == _selectedDistrictFilter;
                
        return districtMatch;
      }).toList();
    });
  }
  
  void _showInspectionReadyBusinesses() {
    setState(() {
      _isSelectionMode = true;
      _selectedBusinessIds.clear();
      _filteredBusinesses = _businesses.where((business) => 
        business.isReadyForInspection == true && 
        (_selectedDistrictFilter == null || business.district == _selectedDistrictFilter)
      ).toList();
    });
  }
  
  void _toggleBusinessSelection(String businessId) {
    setState(() {
      if (_selectedBusinessIds.contains(businessId)) {
        _selectedBusinessIds.remove(businessId);
      } else {
        _selectedBusinessIds.add(businessId);
      }
    });
  }
  
  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedBusinessIds.clear();
      _filterBusinesses(); 
    });
  }
  
  Future<void> _createRoute() async {
    if (_selectedBusinessIds.isEmpty) {
      
      return;
    }
    
    try {
      
      if (!mounted) return;
      
      setState(() {
        _isCreatingRoute = true;
      });
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          
          setState(() {
            _isCreatingRoute = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        
        setState(() {
          _isCreatingRoute = false;
        });
        return;
      }

      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final selectedBusinesses = _businesses.where(
        (business) => _selectedBusinessIds.contains(business.businessId)
      ).toList();
      
      final locations = selectedBusinesses
          .where((business) => business.location != null)
          .map((business) => {
            'name': business.businessName,
            'lat': business.location!.latitude,
            'lng': business.location!.longitude,
            
            'distance': Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              business.location!.latitude,
              business.location!.longitude,
            )
          })
          .toList();
      
      if (locations.isEmpty) {
        if (!mounted) return;
        
        setState(() {
          _isCreatingRoute = false;
        });
        return;
      }
      
      final currentLocationMap = {
        'name': 'Mevcut Konum',
        'lat': currentPosition.latitude,
        'lng': currentPosition.longitude,
        'distance': 0.0,
        'isCurrent': true,
      };
      
      await _openRouteOnMap(currentLocationMap, locations);
      
      if (!mounted) return;
      
      setState(() {
        _isCreatingRoute = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isCreatingRoute = false;
      });
    }
  }
  
  Future<void> _openRouteOnMap(
    Map<String, dynamic> currentLocation,
    List<Map<String, dynamic>> businessLocations
  ) async {
    if (businessLocations.isEmpty) return;
    
    try {
      
      List<Map<String, dynamic>> optimizedRoute = [];
      List<Map<String, dynamic>> unvisitedLocations = List.from(businessLocations);
      
      Map<String, dynamic> currentLoc = {
        'name': 'Mevcut Konum',
        'lat': currentLocation['lat'],
        'lng': currentLocation['lng'],
      };
      
      Map<String, dynamic> findNearestNeighbor(Map<String, dynamic> from, List<Map<String, dynamic>> locations) {
        if (locations.isEmpty) return {};
        
        Map<String, dynamic> nearest = locations.first;
        double minDistance = double.infinity;
        
        for (var loc in locations) {
          final distance = Geolocator.distanceBetween(
            from['lat'],
            from['lng'],
            loc['lat'],
            loc['lng']
          );
          
          if (distance < minDistance) {
            minDistance = distance;
            nearest = loc;
          }
        }
        
        return nearest;
      }
      
      while (unvisitedLocations.isNotEmpty) {
        final nearest = findNearestNeighbor(currentLoc, unvisitedLocations);
        if (nearest.isEmpty) break;
        
        optimizedRoute.add(nearest);
        unvisitedLocations.remove(nearest);
        currentLoc = nearest; 
      }
      
      String url = 'https:
      
      url += '&origin=${currentLocation['lat']},${currentLocation['lng']}';
      
      url += '&destination=${optimizedRoute.last['lat']},${optimizedRoute.last['lng']}';
      
      if (optimizedRoute.length > 1) {
        url += '&waypoints=';
        for (int i = 0; i < optimizedRoute.length - 1; i++) {
          if (i > 0) url += '%7C'; 
          url += '${optimizedRoute[i]['lat']},${optimizedRoute[i]['lng']}';
        }
      }
      
      url += '&travelmode=driving';
      
      url += '&optimize=true';
      
      final Uri uri = Uri.parse(url);
      await launchUrl(uri);
    } catch (e) {
      
    }
  }
  
  void _onDistrictFilterChanged(String? value) {
    setState(() {
      
      if (_selectedDistrictFilter == value) {
        _selectedDistrictFilter = null;
      } else {
        _selectedDistrictFilter = value;
      }
      _filterBusinesses();
    });
  }
  
  void _clearFilters() {
    setState(() {
      _selectedDistrictFilter = null;
      _filteredBusinesses = List<Business>.from(_businesses);
    });
  }

  Future<void> _resetPin() async {
    try {
      await _storage.delete(key: 'admin_pin');
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    } catch (e) {
      
    }
  }

  void _logout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showResetPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN Kodunu Sıfırla'),
        content: const Text(
          'PIN kodunu sıfırlamak istediğinize emin misiniz? Bir dahaki sefere varsayılan kod (1234) kullanılacaktır.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetPin();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBusinesses,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadBusinesses,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Yeniden Dene'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              
                              if (!_isLoading && _errorMessage.isEmpty && _businesses.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'İlçe:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (_selectedDistrictFilter != null)
                                              TextButton(
                                                onPressed: _clearFilters,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red.shade700,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  textStyle: const TextStyle(fontSize: 12),
                                                ),
                                                child: const Text('Filtreleri Temizle'),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                            color: Colors.white,
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              hint: const Text('Tüm ilçeler', style: TextStyle(fontSize: 14)),
                                              value: _selectedDistrictFilter,
                                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4CAF50)),
                                              elevation: 2,
                                              style: const TextStyle(color: Colors.black, fontSize: 14),
                                              onChanged: (String? newValue) {
                                                _onDistrictFilterChanged(newValue);
                                              },
                                              items: _getUniqueDistricts().map((district) {
                                                return DropdownMenuItem<String>(
                                                  value: district,
                                                  child: Text(
                                                    district,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _isSelectionMode 
                                                ? _cancelSelectionMode 
                                                : _showInspectionReadyBusinesses,
                                              icon: Icon(_isSelectionMode ? Icons.cancel : Icons.gavel, size: 16),
                                              label: Text(
                                                _isSelectionMode
                                                    ? 'Seçimi İptal Et'
                                                    : 'Denetle',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _isSelectionMode 
                                                    ? Colors.red.shade600 
                                                    : const Color(0xFF4CAF50),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                minimumSize: const Size(100, 32),
                                              ),
                                            ),
                                            
                                            if (_isSelectionMode && _selectedBusinessIds.isNotEmpty)
                                              ElevatedButton.icon(
                                                onPressed: _isCreatingRoute ? null : _createRoute,
                                                icon: _isCreatingRoute 
                                                    ? const SizedBox(
                                                        width: 16, 
                                                        height: 16, 
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        )
                                                      )
                                                    : const Icon(Icons.directions, size: 16),
                                                label: Text(
                                                  _isCreatingRoute
                                                      ? 'Konum Alınıyor...'
                                                      : 'Rota Oluştur (${_selectedBusinessIds.length})',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  minimumSize: const Size(100, 32),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                
                              Expanded(
                                child: _filteredBusinesses.isEmpty
                                    ? _buildEmptyState()
                                    : _buildBusinessList(),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getUniqueDistricts() {
    final districts = _businesses
        .where((b) => b.district != null && b.district!.isNotEmpty)
        .map((b) => b.district!)
        .toSet()
        .toList();
    districts.sort();
    return districts;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.store_outlined,
              color: Color(0xFF4CAF50),
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedDistrictFilter != null
                  ? 'Filtrelere uygun işletme bulunamadı'
                  : 'Henüz işletme bulunmuyor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDistrictFilter != null
                  ? 'Farklı filtreler seçerek veya filtreleri temizleyerek tüm işletmeleri görüntüleyebilirsiniz'
                  : 'Kullanıcılar şikayet gönderdiğinde işletmeler burada listelenecek',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessList() {
    
    final sortedBusinesses = List<Business>.from(_filteredBusinesses)
      ..sort((a, b) => _calculateCustomScore(b).compareTo(_calculateCustomScore(a)));
      
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedBusinesses.length,
      itemBuilder: (context, index) {
        final business = sortedBusinesses[index];
        
        final isSelected = _selectedBusinessIds.contains(business.businessId);
        
        return GestureDetector(
          
          onTap: _isSelectionMode 
              ? () => _toggleBusinessSelection(business.businessId) 
              : null,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isSelectionMode 
                  ? BorderSide(
                      color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    )
                  : BorderSide.none,
            ),
            child: _isSelectionMode 
                ? _buildSelectionModeBusinessItem(business, isSelected)
                : ExpansionTile(
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.businessName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (business.district != null || business.neighborhood != null)
                          Text(
                            [
                              if (business.district != null) business.district!,
                              if (business.neighborhood != null) business.neighborhood!,
                            ].join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                        Text(
                          'Aktif Şikayet: ${business.pendingComplaints + business.inReviewComplaints}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                            ),
                            const Spacer(),
                            _buildInspectionReadyIndicator(business),
                            const SizedBox(width: 8),
                            _buildScore(business),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      const Divider(),
                      const SizedBox(height: 20),
                      
                      Text(
                        'Şikayet Verileri:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildComplaintStats(business),
                      
                      FutureBuilder<List<Complaint>>(
                        future: ApiService.getBusinessComplaints(business.businessId),
                        builder: (context, snapshot) {
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Şikayet Kategorileri:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (_selectedStatusFilter != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedStatusFilter = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade400, width: 1),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                              
                              if (snapshot.connectionState == ConnectionState.waiting)
                                const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                )
                              else if (snapshot.hasError)
                                Text(
                                'Kategori verileri yüklenemedi',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                                )
                              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                                Text(
                                'Kategori verisi bulunamadı',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                                )
                              else Builder(
                                builder: (context) {
                              
                              List<Complaint> filteredComplaints;
                              
                              if (_selectedStatusFilter != null) {
                                
                                filteredComplaints = snapshot.data!
                                    .where((complaint) => complaint.status == _selectedStatusFilter)
                                    .toList();
                              } else {
                                
                                filteredComplaints = snapshot.data!
                                    .where((complaint) => 
                                        complaint.status == 'pending' || 
                                        complaint.status == 'in-review')
                                    .toList();
                              }
                              
                              final Map<String, int> categoryMap = {};
                              for (final complaint in filteredComplaints) {
                                final category = complaint.category;
                                categoryMap[category] = (categoryMap[category] ?? 0) + 1;
                              }
                              
                                  final categoryList = categoryMap.entries
                                      .map((entry) => CategoryInfo(
                                      name: entry.key, 
                                      count: entry.value))
                                  .toList();
                              
                                  categoryList.sort((a, b) => b.count.compareTo(a.count));
                              
                                  if (categoryList.isEmpty) {
                                String statusText = _selectedStatusFilter != null 
                                    ? _getStatusText(_selectedStatusFilter!)
                                    : "aktif";
                                
                                return Text(
                                  '$statusText şikayetlere ait kategori bulunamadı',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              
                                  return _buildCategoryDistribution(categoryList);
                            }
                        ),
                      ],
                          );
                        },
                      ),
                      
                      FutureBuilder<List<Complaint>>(
                        future: ApiService.getBusinessComplaints(business.businessId),
                        builder: (context, snapshot) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                'Şikayetler:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              if (snapshot.connectionState == ConnectionState.waiting)
                                const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                                )
                              else if (snapshot.hasError)
                                Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Şikayetler yüklenirken hata oluştu',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                                )
                              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                                const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Şikayet bulunamadı'),
                                )
                              else
                                _buildBusinessComplaints(snapshot.data!),
                            ],
                            );
                          }
                      ),
                      
                      if (business.location != null) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () => _openLocationOnMap(business),
                            icon: const Icon(Icons.map, size: 14),
                            label: const Text('Haritada Göster', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionModeBusinessItem(Business business, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.businessName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                if (business.district != null || business.neighborhood != null)
                  Text(
                    [
                      if (business.district != null) business.district!,
                      if (business.neighborhood != null) business.neighborhood!,
                    ].join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                Text(
                  'Aktif Şikayet: ${business.pendingComplaints + business.inReviewComplaints}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                    const Spacer(),
          _buildInspectionReadyIndicator(business),
          const SizedBox(width: 8),
                    _buildScore(business),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateCustomScore(Business business) {
    
    return business.pendingComplaints * 1.0 + business.inReviewComplaints * 2.0;
  }

  Widget _buildScore(Business business) {
    
    final customScore = _calculateCustomScore(business);
      
    final color = customScore >= 10
        ? Colors.red 
        : customScore >= 4
            ? Colors.amber
            : Colors.green;
                
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        customScore.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildComplaintStats(Business business) {
    return Row(
      children: [
        _buildStatItem(
          'Beklemede', 
          business.pendingComplaints, 
          Colors.orange,
          'pending',
          business
        ),
        _buildStatItem(
          'İşlemde', 
          business.inReviewComplaints, 
          Colors.blue,
          'in-review',
          business
        ),
        _buildStatItem(
          'Olumlu', 
          business.positiveComplaints, 
          Colors.green,
          'positive',
          business
        ),
        _buildStatItem(
          'Olumsuz', 
          business.negativeComplaints, 
          Colors.red,
          'negative',
          business
        ),
        _buildStatItem(
          'Reddedilen', 
          business.negativeComplaints + business.positiveComplaints + business.pendingComplaints + business.inReviewComplaints > 0 
          ? business.complaintIds.length - (business.pendingComplaints + business.inReviewComplaints + business.positiveComplaints + business.negativeComplaints)
          : 0, 
          Colors.purple,
          'rejected',
          business
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, Color color, String statusValue, Business business) {
    final isSelected = _selectedStatusFilter == statusValue;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            
            if (_selectedStatusFilter == statusValue) {
              _selectedStatusFilter = null;
            } else {
              _selectedStatusFilter = statusValue;
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withOpacity(0.2) 
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? color 
                  : color.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution(List<CategoryInfo> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((category) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            '${category.name}: ${category.count}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBusinessComplaints(List<Complaint> complaints) {
    return Container(
      height: 250, 
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DefaultTabController(
            length: 5, 
            child: Column(
              children: [
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                  isScrollable: true,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabAlignment: TabAlignment.center,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: const [
                  Tab(text: 'Bekleyen'),
                  Tab(text: 'İşlemde'),
                  Tab(text: 'Olumlu'),
                  Tab(text: 'Olumsuz'),
                  Tab(text: 'Reddedilen'),
                  ],
                ),
            ),
            
                Expanded(
                  child: TabBarView(
                controller: _tabController,
                    children: [
                      
                      Column(
                        children: [
                          
                          if (complaints.any((c) => c.status == 'pending'))
                            Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () => _processAllPendingComplaints(complaints),
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Tümünü İşleme Al', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 1,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                              ),
                            ),
                          
                          Expanded(
                            child: _buildFilteredComplaintsList(complaints, 'pending'),
                          ),
                        ],
                      ),
                      
                  Column(
                    children: [
                      
                      if (complaints.any((c) => c.status == 'in-review'))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmAllInReviewComplaints(complaints),
                                  icon: const Icon(Icons.check_circle, size: 16),
                                  label: const Text('Onayla', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 1,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      Expanded(
                        child: _buildFilteredComplaintsList(complaints, 'in-review'),
                      ),
                    ],
                  ),
                      
                      _buildFilteredComplaintsList(complaints, 'positive'),
                      
                      _buildFilteredComplaintsList(complaints, 'negative'),
                      
                      _buildFilteredComplaintsList(complaints, 'rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
  
  Widget _buildFilteredComplaintsList(List<Complaint> complaints, String? statusFilter) {
    
    final filteredComplaints = statusFilter == null 
        ? complaints 
        : complaints.where((c) => c.status == statusFilter).toList();
    
    if (filteredComplaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            statusFilter == null 
                ? 'Şikayet bulunamadı' 
                : '${_getStatusText(statusFilter)} durumunda şikayet bulunamadı',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    
    final scrollController = _scrollControllers[statusFilter] ?? ScrollController();
    
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: filteredComplaints.length,
      itemBuilder: (context, index) {
        final complaint = filteredComplaints[index];
        
        final isMarkedForRejection = complaint.id != null && _markedForRejection.contains(complaint.id!);
        
        final isTempSaved = complaint.id != null && _tempSavedComplaints.containsKey(complaint.id!);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _ComplaintCard(
            complaint: complaint,
            isMarkedForRejection: isMarkedForRejection,
            isTempSaved: isTempSaved,
            onMarkForRejection: (complaintId) {
              
              setState(() {
                _markedForRejection.add(complaintId);
              });
            },
            onUnmarkForRejection: (complaintId) {
              
              setState(() {
                _markedForRejection.remove(complaintId);
              });
            },
            onShowDetail: _showComplaintDetail,
            onShowUpdateDialog: _showComplaintUpdateDialog,
          ),
        );
      },
    );
  }

  Future<void> _quickUpdateStatus(String complaintId, String status) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.updateComplaintStatus(
        complaintId, 
        status
      );
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showComplaintDetail(Complaint complaint) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Şikayet Detayı'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Text(
                    'Kategori:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.category,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    'Açıklama:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      complaint.description,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (complaint.imageUrls != null && complaint.imageUrls!.isNotEmpty) ...[
                    Text(
                      'Fotoğraflar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: complaint.imageUrls!.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showFullScreenImage(context, complaint.imageUrls![index]),
                            child: Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _getImageUrl(complaint.imageUrls![index]),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / 
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: Colors.green,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(Icons.error_outline, color: Colors.red),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  Text(
                    'İletişim:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.contactEmail,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (complaint.adminMessage != null && complaint.adminMessage!.isNotEmpty) ...[
                    Text(
                      'Admin Yanıtı:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(complaint.status).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(complaint.status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        complaint.adminMessage!,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _setComplaintToInReview(String complaintId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.updateComplaintStatus(
        complaintId, 
        'in-review'
      );
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _rejectComplaint(String complaintId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.updateComplaintStatus(
        complaintId, 
        'rejected',
        adminMessage: 'Şikayetiniz incelendi ve sahte şikayet olduğu düşünülerek reddedildi.'
      );
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setComplaintToPositive(String complaintId, {String? adminMessage}) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.updateComplaintStatus(
        complaintId, 
        'positive',
        adminMessage: adminMessage
      );
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setComplaintToNegative(String complaintId, {String? adminMessage}) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.updateComplaintStatus(
        complaintId, 
        'negative',
        adminMessage: adminMessage
      );
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showComplaintUpdateDialog(Complaint complaint, Function() onComplaintUpdated) {
    
    String selectedStatus = 'positive'; 
    
    if (_tempSavedComplaints.containsKey(complaint.id)) {
      selectedStatus = _tempSavedComplaints[complaint.id]!['status'] ?? 'positive';
    }
    
    final TextEditingController messageController = TextEditingController();
    
    if (_tempSavedComplaints.containsKey(complaint.id) && 
        _tempSavedComplaints[complaint.id]!.containsKey('adminMessage')) {
      messageController.text = _tempSavedComplaints[complaint.id]!['adminMessage'] ?? '';
    } else {
      messageController.text = complaint.adminMessage ?? '';
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Şikayet Sonucunu Belirle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sonuç seçin:'),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Olumlu'),
                    value: 'positive',
                    groupValue: selectedStatus,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setModalState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Olumsuz'),
                    value: 'negative',
                    groupValue: selectedStatus,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      setModalState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kullanıcıya mesaj:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Şikayetle ilgili kullanıcıya iletilecek mesaj...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  
                  if (complaint.id != null) {
                  setState(() {
                      _tempSavedComplaints[complaint.id!] = {
                        'status': selectedStatus,
                        'adminMessage': messageController.text.trim().isNotEmpty 
                          ? messageController.text.trim() 
                          : null,
                      };
                    });
                    
                    onComplaintUpdated();
                  }
                  
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Güncelle'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _openLocationOnMap(Business business) async {
    if (business.location == null) {
      return;
    }
    
    final lat = business.location!.latitude;
    final lng = business.location!.longitude;
    final Uri url = Uri.parse('https:
    
    try {
      await launchUrl(url);
    } catch (e) {
      
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in-review':
        return Colors.blue;
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'rejected':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'in-review':
        return 'İşlemde';
      case 'positive':
        return 'Olumlu';
      case 'negative':
        return 'Olumsuz';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Bilinmiyor';
    }
  }

  Future<void> _processAllPendingComplaints(List<Complaint> complaints) async {
    
    final pendingComplaints = complaints.where((c) => c.status == 'pending').toList();
    
    if (pendingComplaints.isEmpty) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      
      final complaintsToReject = pendingComplaints
          .where((c) => c.id != null && _markedForRejection.contains(c.id!))
          .toList();
      
      final complaintsToProcess = pendingComplaints
          .where((c) => c.id != null && !_markedForRejection.contains(c.id!))
          .toList();
      
      for (var complaint in complaintsToReject) {
        if (complaint.id != null) {
      await ApiService.updateComplaintStatus(
        complaint.id!, 
        'rejected',
        adminMessage: "Şikayetiniz incelendi ve sahte şikayet olduğu düşünülerek reddedildi."
      );
        }
      }
      
      for (var complaint in complaintsToProcess) {
        if (complaint.id != null) {
          await ApiService.updateComplaintStatus(complaint.id!, 'in-review');
        }
      }
      
      setState(() {
        _markedForRejection.clear();
      });
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAllInReviewComplaints(List<Complaint> complaints) async {
    
    final inReviewComplaints = complaints.where((c) => c.status == 'in-review').toList();
    
    if (inReviewComplaints.isEmpty) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      
      for (var complaint in inReviewComplaints) {
        if (complaint.id != null) {
          
          if (_tempSavedComplaints.containsKey(complaint.id)) {
            final tempData = _tempSavedComplaints[complaint.id]!;
            final status = tempData['status'] as String? ?? 'positive';
            final adminMessage = tempData['adminMessage'] as String? ?? 'Şikayetiniz incelendi ve sonuçlandırıldı.';
            
            await ApiService.updateComplaintStatus(
              complaint.id!,
              status,
              adminMessage: adminMessage,
            );
          } else {
            
            await ApiService.updateComplaintStatus(
              complaint.id!, 
              'positive',
              adminMessage: complaint.adminMessage ?? 'Şikayetiniz incelendi ve olumlu sonuçlandırıldı.',
            );
          }
        }
      }
      
      setState(() {
        _tempSavedComplaints.clear();
      });
      
      await _loadBusinesses();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInspectionReadyIndicator(Business business) {
    
    if (business.pendingComplaints == 0 && business.inReviewComplaints > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.teal),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_turned_in,
              size: 12,
              color: Colors.teal,
            ),
            const SizedBox(width: 3),
            const Text(
              "Hazır",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      );
    
    } else if (business.pendingComplaints > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pending_actions,
              size: 12,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 3),
            Text(
              "İşlem Gerekli",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blueGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_circle_outline,
              size: 12,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 3),
            const Text(
              "Şikayet Yok",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final fullImageUrl = _getImageUrl(imageUrl);
        
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  fullImageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(Icons.error_outline, color: Colors.red, size: 50),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getImageUrl(String imageUrl) {
    
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    
    final apiUrl = ApiService.baseUrl;
    final baseUrlEndIndex = apiUrl.indexOf('/api');
    final baseUrl = apiUrl.substring(0, baseUrlEndIndex);
    
    String finalPath = imageUrl;
    if (imageUrl.startsWith('/uploads')) {
      
      finalPath = imageUrl;
    } else if (imageUrl.startsWith('uploads/')) {
      
      finalPath = '/$imageUrl';
    } else if (!imageUrl.startsWith('/')) {
      
      finalPath = '/uploads/$imageUrl';
    }
    
    return '$baseUrl$finalPath';
  }
}

class _ComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final bool isMarkedForRejection;
  final bool isTempSaved;
  final Function(String) onMarkForRejection;
  final Function(String) onUnmarkForRejection;
  final Function(Complaint) onShowDetail;
  final Function(Complaint, Function() onComplaintUpdated) onShowUpdateDialog;

  const _ComplaintCard({
    Key? key,
    required this.complaint,
    required this.isMarkedForRejection,
    required this.isTempSaved,
    required this.onMarkForRejection,
    required this.onUnmarkForRejection,
    required this.onShowDetail,
    required this.onShowUpdateDialog,
  }) : super(key: key);

  @override
  _ComplaintCardState createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard> {
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
  
  bool _isComplaintSaved = false;

  void markAsSaved() {
    if (mounted) {
      setState(() {
        _isComplaintSaved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => widget.onShowDetail(widget.complaint),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.complaint.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(widget.complaint.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              Text(
                widget.complaint.description,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              if (widget.complaint.id != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    
                    if (widget.complaint.status == 'pending')
                      widget.isMarkedForRejection 
                        ? GestureDetector(
                            onTap: () {
                              if (widget.complaint.id != null) {
                                widget.onUnmarkForRejection(widget.complaint.id!);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.block,
                                    size: 12,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reddedildi',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 26,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (widget.complaint.id != null) {
                                  widget.onMarkForRejection(widget.complaint.id!);
                                }
                              },
                              icon: const Icon(Icons.block, size: 12),
                              label: const Text('Reddet', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                    
                    const SizedBox(width: 8),
                    
                    if (widget.complaint.status == 'in-review')
                      widget.isTempSaved || _isComplaintSaved
                        ? GestureDetector(
                            onTap: () {
                              widget.onShowUpdateDialog(widget.complaint, markAsSaved);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Kaydedildi',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 10, color: Colors.green.shade700),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 26,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                widget.onShowUpdateDialog(widget.complaint, markAsSaved);
                              },
                              icon: const Icon(Icons.check_circle, size: 12),
                              label: const Text('Sonuçlandır', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade500,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryInfo {
  final String name;
  final int count;

  CategoryInfo({
    required this.name,
    required this.count,
  });
} 